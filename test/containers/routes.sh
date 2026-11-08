#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# One update route of test/update-routes.sh. It runs inside a fresh container
# as the user "tester", where sudo and every install stay inside the
# container, and prints a "CHECK PASS|FAIL <route> <what>" line for each thing
# it asserts; update-routes.sh collects those lines.
#
#   routes.sh <route>
#
# /work (read-only) holds repo.bundle with the branches "old" (the previous
# release) and "new" (the version under test), the .plasmoid built the way
# doc/releasing.md says, and routes.env with the commits and versions.
#
# Routes, each starting from a system with neither half installed:
#   r1-git          old install.sh, git pull, ./update.sh
#   r2-store-first  old install.sh, the store updates the widget package,
#                   then git pull, ./update.sh
#   r3-store-only   the widget package from the store and no engine, then a
#                   clone and ./update.sh
#   r3-install      the same, but ./install.sh instead of ./update.sh
#   r4-newer        a newer package, then a newer engine, is installed already:
#                   update.sh and install.sh refuse and change nothing
#   r5-repeat       ./update.sh on a clean system, then again from another
#                   directory
#   r6-uninstall    ./install.sh from a copy without .git (a downloaded ZIP),
#                   then ./uninstall.sh removes both halves, and a second run
#                   finds nothing to remove
set -uo pipefail

# It runs sudo and installs both halves, so only where update-routes.sh puts
# it: a podman container (which has /run/.containerenv) with /work mounted.
if [ ! -f /run/.containerenv ] || [ ! -r /work/routes.env ]; then
    echo "routes.sh runs only inside the containers of test/update-routes.sh" >&2
    exit 2
fi

route=${1:?usage: routes.sh <route>}
# shellcheck source=/dev/null
. /work/routes.env

APPLET=io.github.cir0cuit.plasmaterminal
PKGDIR=$HOME/.local/share/plasma/plasmoids/$APPLET
QMLDIR=$(qtpaths6 -query QT_INSTALL_QML 2>/dev/null || qmake6 -query QT_INSTALL_QML)
ENGINE=$QMLDIR/io/github/cir0cuit/plasmaterminal/core
UPSTREAM=$HOME/upstream.git
CLONE=$HOME/plasma-terminal-widget
LOGS=$HOME/steps
EXPECTED=$HOME/expected
mkdir -p "$LOGS" "$EXPECTED"

failures=0
pass() { echo "CHECK PASS $route $*"; }
fail() {
    echo "CHECK FAIL $route $*"
    failures=$((failures + 1))
}
banner() { printf '\n========== %s ==========\n' "$*"; }

# step <name> <command...>: run a command, show its output and keep it in
# $LOGS/<name> for the checks; its exit code is left in $rc.
rc=0
step() {
    local name=$1
    shift
    banner "$name: $*"
    "$@" > "$LOGS/$name" 2>&1
    rc=$?
    cat "$LOGS/$name"
    echo "[$name exit $rc]"
}

expect_exit() { # <step> <0|nonzero>
    if [ "$2" = 0 ] && [ "$rc" -eq 0 ]; then
        pass "$1 exits 0"
    elif [ "$2" = nonzero ] && [ "$rc" -ne 0 ]; then
        pass "$1 exits non-zero ($rc)"
    else
        fail "$1 exits $rc, expected $2"
    fi
}

expect_line() { # <step> <exact line>
    if grep -qxF -- "$2" "$LOGS/$1"; then
        pass "$1 prints \"$2\""
    else
        fail "$1 does not print \"$2\""
    fi
}

expect_last_line() { # <step> <exact line>
    local last
    last=$(tail -n 1 "$LOGS/$1")
    if [ "$last" = "$2" ]; then
        pass "$1 ends with \"$2\""
    else
        fail "$1 ends with \"$last\", expected \"$2\""
    fi
}

expect_no_match() { # <step> <extended regex> <what>
    if grep -qE -- "$2" "$LOGS/$1"; then
        fail "$1 prints $3: $(grep -E -- "$2" "$LOGS/$1" | head -n 1)"
    else
        pass "$1 does not print $3"
    fi
}

# The CHANGELOG entries update.sh prints: the new heading must be there and
# the heading of the version being replaced must not.
expect_changelog() { # <step> <version being replaced>
    if grep -q "^## $NEW_VERSION " "$LOGS/$1"; then
        pass "$1 prints the CHANGELOG entry for $NEW_VERSION"
    else
        fail "$1 does not print the CHANGELOG entry for $NEW_VERSION"
    fi
    # By fields, as update.sh reads them: the 1.0.0 heading has no date after
    # the version.
    if awk -v v="$2" '$1 == "##" && $2 == v { found = 1 } END { exit !found }' "$LOGS/$1"; then
        fail "$1 also prints the CHANGELOG entry for $2, which is installed already"
    else
        pass "$1 does not print the CHANGELOG entry for $2"
    fi
}

expect_single_blank_lines() { # <step>
    if awk 'prev == "" && $0 == "" && NR > 1 { found = 1 } { prev = $0 } END { exit !found }' "$LOGS/$1"; then
        fail "$1 prints two blank lines in a row"
    else
        pass "$1 never prints two blank lines in a row"
    fi
}

# Versions as installed, read the way a user would check them, not with the
# project's own scripts.
installed_package() {
    local v
    v=$(sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' "$PKGDIR/metadata.json" 2>/dev/null | sed -n 1p)
    case "$v" in
        "") v=none ;;
        *.*.*) ;;
        *.*) v=$v.0 ;;
    esac
    echo "$v"
}

installed_engine() {
    if [ ! -d "$ENGINE" ]; then
        echo none
    elif [ -f "$ENGINE/version" ]; then
        tr -d '[:space:]' < "$ENGINE/version"
        echo
    else
        echo 1.0.0 # engines before 1.1.0 have no version file
    fi
}

# TerminalInfo.engineVersion is a QStringLiteral, stored as UTF-16 in the .so.
so_reports() {
    strings -a -el "$ENGINE/libplasmaterminalcoreplugin.so" 2>/dev/null | grep -qxF "$1"
}

expect_package() { # <when> <version|none>
    local got
    got=$(installed_package)
    if [ "$got" = "$2" ]; then
        pass "$1: widget package is $2"
    else
        fail "$1: widget package is $got, expected $2"
    fi
}

expect_engine() { # <when> <version|none>
    local got
    got=$(installed_engine)
    if [ "$got" = "$2" ]; then
        pass "$1: engine is $2"
    else
        fail "$1: engine is $got, expected $2"
    fi
}

# Every file below a directory with its checksum, relative to it.
tree_sums() {
    (cd "$1" 2> /dev/null && find . -type f -exec sha256sum {} + | sort -k 2)
}

# Both halves are exactly the version under test: the package files, the
# engine's version file and the version compiled into the engine.
expect_new_installed() { # <when>
    expect_package "$1" "$NEW_VERSION"
    local expected installed
    expected=$(tree_sums "$EXPECTED/package")
    installed=$(tree_sums "$PKGDIR")
    if [ -n "$expected" ] && [ "$installed" = "$expected" ]; then
        pass "$1: installed package files are the new package/"
    else
        fail "$1: installed package files differ from the new package/"
        # Not every image has diff.
        printf 'expected:\n%s\ninstalled:\n%s\n' "$expected" "$installed"
    fi
    expect_engine "$1" "$NEW_VERSION"
    if so_reports "$NEW_VERSION"; then
        pass "$1: the engine .so reports $NEW_VERSION"
    else
        fail "$1: the engine .so does not contain the version $NEW_VERSION"
    fi
}

# Everything the scripts could change, to show that a refusal changed nothing.
state() {
    {
        find "$HOME/.local/share/plasma" "$ENGINE" -type f -exec sha256sum {} + 2>/dev/null
        find "$HOME/.local/share/plasma" "$ENGINE" -type d 2>/dev/null
        [ -e "$CLONE/build" ] && echo "build/ exists"
    } | sort
}

setup_upstream() { # <commit main starts at>
    banner "upstream: a bare repository whose main is ${1:0:12}"
    git -c init.defaultBranch=main clone -q --bare /work/repo.bundle "$UPSTREAM" &&
        git -C "$UPSTREAM" update-ref refs/heads/main "$1" &&
        git -C "$UPSTREAM" symbolic-ref HEAD refs/heads/main &&
        git -C "$UPSTREAM" branch -q -D old new &&
        git --git-dir="$UPSTREAM" archive "$NEW_COMMIT" package | tar -x -C "$EXPECTED"
}

# The maintainer merges the release into main, as doc/releasing.md step 5 says.
release() {
    banner "release: upstream main moves to ${NEW_COMMIT:0:12}"
    git -C "$UPSTREAM" update-ref refs/heads/main "$NEW_COMMIT"
}

clone() {
    step clone git clone -q "$UPSTREAM" "$CLONE"
    expect_exit clone 0
}

# The previous release, installed the way its README said. Releases before
# 1.1.0 read $USER, which a login session always has; the container does not.
old_install() {
    step old-install env USER=tester "$CLONE/install.sh"
    expect_exit old-install 0
    expect_package "after the old install.sh" "$OLD_PKG_VERSION"
    if [ -d "$ENGINE" ]; then
        pass "after the old install.sh: an engine is installed"
    else
        fail "after the old install.sh: no engine in $ENGINE"
    fi
    old_engine=$(installed_engine)
}

# Get New Widgets hands the store's file to KPackage::PackageJob::update, which
# replaces the installed package only when the file's metadata Version is
# strictly newer, compared like QVersionNumber (1.0 < 1.0.0 < 1.1.0). The test
# checks that condition and then replaces the files with kpackagetool6, which
# leaves the same files on disk.
store_update() {
    local file_version installed
    file_version=$(python3 -c 'import json, sys, zipfile; print(json.loads(zipfile.ZipFile(sys.argv[1]).read("metadata.json"))["KPlugin"]["Version"])' "/work/$PLASMOID")
    installed=$(sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' "$PKGDIR/metadata.json" 2>/dev/null | sed -n 1p)
    if python3 -c 'import sys; k = lambda v: [int(x) for x in v.split(".")]; sys.exit(0 if k(sys.argv[1]) > k(sys.argv[2]) else 1)' "$file_version" "$installed"; then
        pass "the store file's Version $file_version is newer than the installed $installed, so KPackage replaces it"
    else
        fail "the store file's Version $file_version is not newer than the installed $installed: KPackage would keep the old files"
        return
    fi
    step store-update kpackagetool6 --type Plasma/Applet --upgrade "/work/$PLASMOID"
    expect_exit store-update 0
}

store_install() {
    step store-install kpackagetool6 --type Plasma/Applet --install "/work/$PLASMOID"
    expect_exit store-install 0
}

# plasmashell is not a systemd user service in a container, so update.sh would
# take its "log out" path. Routes that check the restart advice instead get a
# systemctl that reports the service as running and records every call.
stub_systemctl() {
    mkdir -p "$HOME/stubbin"
    cat > "$HOME/stubbin/systemctl" <<'STUB'
#!/bin/sh
echo "systemctl $*" >> "$HOME/systemctl-calls"
exit 0
STUB
    chmod +x "$HOME/stubbin/systemctl"
    : > "$HOME/systemctl-calls"
}

expect_restart_advice() { # <step>
    expect_line "$1" "Restart plasmashell when it suits you to load $NEW_VERSION:"
    if grep -q restart "$HOME/systemctl-calls"; then
        fail "$1 restarted plasmashell despite --no-restart"
    fi
}

cd "$HOME" || exit 1
# shellcheck source=/dev/null
echo "route $route on $(. /etc/os-release && echo "$PRETTY_NAME"), Qt QML dir $QMLDIR"
echo "old ${OLD_COMMIT:0:12} (package $OLD_PKG_VERSION), new ${NEW_COMMIT:0:12} ($NEW_VERSION)"

case "$route" in
    r1-git)
        setup_upstream "$OLD_COMMIT" || exit 1
        clone
        old_install
        release
        step pull git -C "$CLONE" pull
        expect_exit pull 0
        stub_systemctl
        step update env PATH="$HOME/stubbin:$PATH" "$CLONE/update.sh" --no-restart
        expect_exit update 0
        older=$OLD_PKG_VERSION
        if [ "$(printf '%s\n' "$old_engine" "$older" | sort -V | head -n 1)" = "$old_engine" ]; then
            older=$old_engine
        fi
        expect_line update "Updating $older -> $NEW_VERSION."
        expect_changelog update "$older"
        expect_restart_advice update
        expect_single_blank_lines update
        expect_new_installed "after git pull and ./update.sh"
        ;;

    r2-store-first)
        setup_upstream "$OLD_COMMIT" || exit 1
        clone
        old_install
        so_before=$(sha256sum "$ENGINE/libplasmaterminalcoreplugin.so" 2>/dev/null)
        store_update
        expect_package "after the store update" "$NEW_VERSION"
        if [ "$(installed_engine)" = "$old_engine" ] &&
            [ "$(sha256sum "$ENGINE/libplasmaterminalcoreplugin.so" 2>/dev/null)" = "$so_before" ]; then
            pass "after the store update: the engine is still the old one ($old_engine)"
        else
            fail "after the store update: the engine changed, which the store cannot do"
        fi
        release
        step pull git -C "$CLONE" pull
        expect_exit pull 0
        stub_systemctl
        step update env PATH="$HOME/stubbin:$PATH" "$CLONE/update.sh" --no-restart
        expect_exit update 0
        expect_line update "The widget package is $NEW_VERSION already (updated from the KDE Store); the engine is $old_engine. Updating the engine to $NEW_VERSION."
        expect_changelog update "$old_engine"
        expect_restart_advice update
        expect_single_blank_lines update
        expect_new_installed "after git pull and ./update.sh"
        ;;

    r3-store-only | r3-install)
        setup_upstream "$NEW_COMMIT" || exit 1
        store_install
        expect_package "after the store install" "$NEW_VERSION"
        expect_engine "after the store install" none
        clone
        if [ "$route" = r3-store-only ]; then
            step update "$CLONE/update.sh" --no-restart
            expect_exit update 0
            expect_line update "The widget package $NEW_VERSION is installed, but no engine. Installing both halves of $NEW_VERSION."
            expect_line update "plasmashell is not running as a systemd user service, so it was not"
            expect_single_blank_lines update
            expect_new_installed "after ./update.sh"
        else
            step install "$CLONE/install.sh"
            expect_exit install 0
            expect_no_match install '^error:' "an error"
            expect_line install "Done. Restart plasmashell to load the new version:"
            expect_new_installed "after ./install.sh"
        fi
        ;;

    r4-newer)
        setup_upstream "$NEW_COMMIT" || exit 1
        clone
        banner "a widget package with Version 9.9.9 is installed"
        mkdir -p "$HOME/fake" && cp -r "$CLONE/package" "$HOME/fake/package" &&
            sed -i 's/"Version": *"[^"]*"/"Version": "9.9.9"/' "$HOME/fake/package/metadata.json" &&
            kpackagetool6 --type Plasma/Applet --install "$HOME/fake/package"
        expect_package "fake newer package" 9.9.9
        for script in update install; do
            before=$(state)
            if [ "$script" = update ]; then
                step newer-package-update "$CLONE/update.sh" --no-restart
            else
                step newer-package-install "$CLONE/install.sh"
            fi
            expect_exit "newer-package-$script" nonzero
            expect_line "newer-package-$script" "error: the installed widget package is 9.9.9, newer than this copy ($NEW_VERSION)."
            if [ "$(state)" = "$before" ]; then
                pass "newer-package-$script changes nothing"
            else
                fail "newer-package-$script changed installed files or started a build"
                echo "before:" && echo "$before" && echo "after:" && state
            fi
        done

        banner "an engine whose version file says 9.9.9 is installed, and no package"
        kpackagetool6 --type Plasma/Applet --remove "$APPLET"
        sudo install -d "$ENGINE" && echo 9.9.9 | sudo tee "$ENGINE/version" > /dev/null
        expect_package "fake newer engine" none
        expect_engine "fake newer engine" 9.9.9
        for script in update install; do
            before=$(state)
            if [ "$script" = update ]; then
                step newer-engine-update "$CLONE/update.sh" --no-restart
            else
                step newer-engine-install "$CLONE/install.sh"
            fi
            expect_exit "newer-engine-$script" nonzero
            expect_line "newer-engine-$script" "error: the installed engine is 9.9.9, newer than this copy ($NEW_VERSION)."
            if [ "$(state)" = "$before" ]; then
                pass "newer-engine-$script changes nothing"
            else
                fail "newer-engine-$script changed installed files or started a build"
                echo "before:" && echo "$before" && echo "after:" && state
            fi
        done
        ;;

    r5-repeat)
        setup_upstream "$NEW_COMMIT" || exit 1
        clone
        stub_systemctl
        step update-first env PATH="$HOME/stubbin:$PATH" "$CLONE/update.sh" --no-restart
        expect_exit update-first 0
        expect_line update-first "Installing $NEW_VERSION."
        # A first install: the restart advice comes once, from update.sh, and
        # the hint to add the widget comes after it.
        expect_restart_advice update-first
        expect_no_match update-first '^Done\.' "install.sh's own restart advice"
        expect_last_line update-first "Then add the widget from the desktop context menu: Add Widgets... -> Terminal"
        expect_single_blank_lines update-first
        expect_new_installed "after the first ./update.sh"
        # Run from another directory: the scripts must find their own folder.
        cd / || exit 1
        step update-again "$CLONE/update.sh" --no-restart
        cd "$HOME" || exit 1
        expect_exit update-again 0
        expect_line update-again "$NEW_VERSION is installed already. Rebuilding and reinstalling both halves anyway."
        expect_no_match update-again 'Add Widgets' "the hint to add the widget, which is installed already"
        expect_single_blank_lines update-again
        expect_new_installed "after the second ./update.sh"
        ;;

    r6-uninstall)
        setup_upstream "$NEW_COMMIT" || exit 1
        # A downloaded ZIP: the same files, no .git.
        zipcopy=$HOME/plasma-terminal-widget-main
        git --git-dir="$UPSTREAM" archive --prefix=plasma-terminal-widget-main/ main | tar -x -C "$HOME"
        io_existed=no
        [ -d "$QMLDIR/io" ] && io_existed=yes
        cd / || exit 1
        step install "$zipcopy/install.sh"
        expect_exit install 0
        expect_line install "Done. Restart plasmashell so it finds the new widget:"
        expect_last_line install "Then add it from the desktop context menu: Add Widgets... -> Terminal"
        expect_new_installed "after ./install.sh from a copy without .git"
        step uninstall "$zipcopy/uninstall.sh"
        cd "$HOME" || exit 1
        expect_exit uninstall 0
        expect_package "after ./uninstall.sh" none
        if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$APPLET"; then
            fail "after ./uninstall.sh: kpackagetool6 still lists $APPLET"
        else
            pass "after ./uninstall.sh: kpackagetool6 no longer lists $APPLET"
        fi
        if [ -e "$ENGINE/version" ]; then
            fail "after ./uninstall.sh: the engine's version file is still there"
        else
            pass "after ./uninstall.sh: the engine's version file is gone"
        fi
        if [ -e "$ENGINE" ]; then
            fail "after ./uninstall.sh: $ENGINE is still there ($(find "$ENGINE" -mindepth 1 -printf '%f '))"
        else
            pass "after ./uninstall.sh: the engine directory is gone"
        fi
        if [ "$io_existed" = no ]; then
            if [ -e "$QMLDIR/io" ]; then
                fail "after ./uninstall.sh: empty parent directories are left in $QMLDIR/io"
            else
                pass "after ./uninstall.sh: the empty parent directories are gone"
            fi
        fi
        # Nothing left to remove: both parts say so, without an error.
        step uninstall-again "$zipcopy/uninstall.sh"
        expect_exit uninstall-again 0
        expect_line uninstall-again "  not installed."
        expect_line uninstall-again "  no installed module found - nothing to remove."
        expect_no_match uninstall-again '^Error' "an error from kpackagetool6"
        ;;

    *)
        echo "unknown route $route" >&2
        exit 2
        ;;
esac

echo
echo "ROUTE DONE $route failures=$failures"
[ "$failures" -eq 0 ]
