#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Tests every way a user can get from the previous release to this one, using
# the working tree as it is now, uncommitted changes included.
#
# Containers (rootless podman; Fedora, Debian, Ubuntu and Arch), each route
# in a fresh container (test/containers/routes.sh has the details):
#   r1-git          the old install.sh, then git pull and ./update.sh
#   r2-store-first  the old install.sh, a store update of the widget package,
#                   then git pull and ./update.sh
#   r3-store-only   the store package without an engine, then ./update.sh
#   r3-install      the same with ./install.sh
#   r4-newer        a newer package or engine is installed: both scripts
#                   refuse and change nothing
#   r5-repeat       ./update.sh twice
#   r6-uninstall    ./install.sh from a copy without .git, then ./uninstall.sh
#                   twice
#
# Desktop (a hidden nested Plasma session on this machine: KWin's virtual
# backend, a private D-Bus, private XDG directories, plasmashell, and both
# engines built from source into a temporary directory):
#   D1  the store updates the widget package while Plasma runs, with a widget
#       in a panel whose popup was never opened; a widget added afterwards
#       must show a terminal
#   D2  the new widget package on the old engine, after a restart
#   D3  the new widget package on the new engine
#   D4  the new widget package without an engine
#   Each checks plasmashell's log for warnings from the widget package's
#   files, reads the widget through the accessibility interface, and saves
#   screenshots; D2 to D4 also read its Appearance, Shell and Behavior
#   settings pages.
#
# It never touches the real desktop or the installed system. Nothing is
# installed on the host and sudo runs only inside the containers. The nested
# session has its own Wayland socket, D-Bus and settings, so it shows no
# window and takes no input, and the engine installed on this machine is
# hidden from it in a private mount namespace. It stops only its own
# containers and the processes that carry its own XDG_RUNTIME_DIR.
#
# Needs git and zip. The containers need podman. The desktop part needs what
# building the engine needs (cmake, a C++ compiler, the Qt 6 and KF6
# development packages), kwin_wayland, plasmashell, spectacle, kpackagetool6,
# Qt 6's qdbus (qdbus-qt6 or qdbus6), dbus-run-session, unshare (util-linux)
# and python3 with PyGObject and the AT-SPI library (at-spi2-core), which
# reads the text on screen. When an engine is installed on this machine, the
# desktop part also needs unprivileged user namespaces and unshare from
# util-linux 2.38 or later, to hide that engine; Ubuntu restricts those
# namespaces by default.
#
# A full run takes 4 to 6 minutes once the container images exist. The first
# run builds them, which downloads several gigabytes of packages. Images and
# compiled objects are kept between runs, as the podman images
# localhost/ptw-update-routes-<distro>:<hash of its Containerfile> and the
# podman volumes ptw-update-routes-ccache-<distro>; podman rmi and podman
# volume rm remove them. The distribution images they are built from stay as
# well, and so does an image built from a Containerfile that has since
# changed. Ctrl-C stops a run and cleans up after it.
#
# Usage: test/update-routes.sh [options]
#   --from <git ref>        the previous release (default: main)
#   --containers <list>     distributions to test, from: fedora debian
#                           ubuntu arch (default: all four), or none
#   --routes <list>         container routes to run (default: all of them)
#   --desktop, --no-desktop run the nested desktop part, or not (default: run)
#   --keep                  keep the temporary work directory
#   --out <dir>             where logs, screenshots and results go
#                           (default: a new temporary directory)
#
# Exit status: 0 if every check passed, 1 if any failed, 2 if the test
# could not run.
set -uo pipefail

from=main
containers="fedora debian ubuntu arch"
desktop=1
keep=0
out=
all_distros="fedora debian ubuntu arch"
routes="r1-git r2-store-first r3-store-only r3-install r4-newer r5-repeat r6-uninstall"
only_routes=

usage() {
    sed -n '/^# Usage:/,/^# Exit status/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
}

die() {
    echo "update-routes: $*" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --from) from=${2:?--from needs a git ref}; shift ;;
        --containers) containers=$(printf '%s' "${2:?--containers needs a list}" | tr ',' ' '); shift ;;
        --routes) only_routes=$(printf '%s' "${2:?--routes needs a list}" | tr ',' ' '); shift ;;
        --desktop) desktop=1 ;;
        --no-desktop) desktop=0 ;;
        --keep) keep=1 ;;
        --out) out=${2:?--out needs a directory}; shift ;;
        -h | --help) usage; exit 0 ;;
        *) echo "update-routes: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
[ "$containers" = none ] && containers=
for d in $containers; do
    case " $all_distros " in *" $d "*) ;; *) die "unknown distribution '$d' (known: $all_distros)" ;; esac
done
for r in $only_routes; do
    case " $routes " in *" $r "*) ;; *) die "unknown route '$r' (known: $routes)" ;; esac
done
[ -n "$only_routes" ] && routes=$only_routes

REPO=$(cd "$(dirname "$0")/.." && pwd)
git -C "$REPO" rev-parse --git-dir > /dev/null 2>&1 || die "$REPO is not a git checkout"
OLD_COMMIT=$(git -C "$REPO" rev-parse --verify --quiet "$from^{commit}") || die "unknown git ref '$from'"

missing=()
for tool in git zip sha256sum; do
    command -v "$tool" > /dev/null 2>&1 || missing+=("$tool")
done
if [ -n "$containers" ]; then
    command -v podman > /dev/null 2>&1 || missing+=(podman)
fi
QDBUS=
SYSTEM_ENGINE=
if [ "$desktop" = 1 ]; then
    for tool in cmake kwin_wayland plasmashell spectacle kpackagetool6 dbus-run-session \
        dbus-update-activation-environment unshare python3 pgrep; do
        command -v "$tool" > /dev/null 2>&1 || missing+=("$tool")
    done
    # Its name differs between distributions, and the nested session's PATH
    # has only /usr/bin and /bin, so it is kept as an absolute path.
    for q in qdbus-qt6 qdbus6 "$(qtpaths6 -query QT_INSTALL_BINS 2> /dev/null)/qdbus" \
        "$(qmake6 -query QT_INSTALL_BINS 2> /dev/null)/qdbus"; do
        QDBUS=$(command -v "$q" 2> /dev/null) && break
    done
    [ -n "$QDBUS" ] || missing+=("Qt 6's qdbus (qdbus-qt6 on Fedora, qdbus6 on Debian, Ubuntu and Arch)")
    python3 -I -c 'import gi; gi.require_version("Atspi", "2.0"); from gi.repository import Atspi' 2> /dev/null ||
        missing+=("python3 with PyGObject and AT-SPI")
    [ -f /usr/share/dbus-1/services/org.a11y.Bus.service ] || missing+=(at-spi2-core)
fi
[ ${#missing[@]} -eq 0 ] || die "missing ${missing[*]}"
if [ "$desktop" = 1 ]; then
    # An engine installed on this machine is hidden from the nested session in
    # a private mount namespace (see shell_start). Checked here, before
    # anything slow runs, with the same chain of namespaces.
    qmldir=$(qtpaths6 -query QT_INSTALL_QML 2> /dev/null || qmake6 -query QT_INSTALL_QML 2> /dev/null)
    if [ -n "$qmldir" ] && [ -d "$qmldir/io/github/cir0cuit/plasmaterminal/core" ]; then
        SYSTEM_ENGINE=$qmldir/io/github/cir0cuit/plasmaterminal/core
        # shellcheck disable=SC2016 # expanded by sh -c
        unshare -r -m sh -c 'exec unshare --user --map-user="$1" --map-group="$2" true' \
            _ "$(id -u)" "$(id -g)" > /dev/null 2>&1 ||
            die "an engine is installed in $SYSTEM_ENGINE, and hiding it from the nested session needs unprivileged user namespaces and unshare from util-linux 2.38 or later, which this system does not offer (on Ubuntu, see kernel.apparmor_restrict_unprivileged_userns); run with --no-desktop, or remove the installed engine first"
    fi
fi

WORK=$(mktemp -d -t ptw-update-routes.XXXXXX) || die "cannot create a temporary directory"
if [ -z "$out" ]; then
    out=$(mktemp -d -t ptw-update-routes-out.XXXXXX) || die "cannot create a temporary directory"
fi
mkdir -p "$out" || die "cannot create $out"
out=$(cd "$out" && pwd)
RESULTS=$out/results.tsv
: > "$RESULTS"
RUN_ID=ptw-update-routes-$$
started=$(date +%s)
timings=()
# Nothing here runs from the project folder, so that no tool leaves files in it.
cd "$WORK" || exit 2

# --- bookkeeping ------------------------------------------------------------

# record <part> <route> <PASS|FAIL> <what>
record() {
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$RESULTS"
    printf '  %-4s %s %s: %s\n' "$3" "$1" "$2" "$4"
}

say() { printf '\n== %s\n' "$*"; }

elapsed() { # <since epoch seconds>
    local s=$(($(date +%s) - $1))
    printf '%d:%02d' $((s / 60)) $((s % 60))
}

# --- cleanup ----------------------------------------------------------------

RT=
cleanup() {
    # Stopping the nested session can take a while; a second Ctrl-C must not
    # cut it short.
    trap '' INT TERM HUP
    trap - EXIT
    if [ -n "$containers" ] && command -v podman > /dev/null 2>&1; then
        podman ps -a --filter "name=^$RUN_ID-" --format '{{.Names}}' 2> /dev/null |
            xargs -r podman rm -f -t 0 > /dev/null 2>&1
    fi
    # The nested session before the remaining jobs: killing dbus-run-session
    # would leave kwin running without the bus that desk_kill_all then stops.
    if [ -n "$RT" ]; then
        desk_kill_all
        rm -rf "$RT"
    fi
    jobs -p | xargs -r kill 2> /dev/null
    if [ "$keep" = 1 ]; then
        echo "Work directory kept: $WORK"
    else
        rm -rf "$WORK"
    fi
}
trap cleanup EXIT
trap 'echo; echo "update-routes: interrupted" >&2; exit 130' INT TERM HUP

# --- the two versions -------------------------------------------------------

# The working tree goes into a commit of a private clone, so the real
# repository is only read: no stash, no commit, no index refresh.
say "Snapshot of the working tree and $from"
git clone -q --no-local --no-checkout "$REPO" "$WORK/repo" || die "cannot clone $REPO"
head=$(git -C "$REPO" rev-parse HEAD) || die "no HEAD in $REPO"
# A clone brings branches and tags only; a detached HEAD or a remote-tracking
# ref has to be fetched by its commit.
for commit in "$head" "$OLD_COMMIT"; do
    git -C "$WORK/repo" cat-file -e "$commit^{commit}" 2> /dev/null ||
        git -C "$WORK/repo" fetch -q --no-tags "$REPO" "$commit" ||
        die "cannot fetch $commit from $REPO"
done
git -C "$WORK/repo" checkout -q --detach "$head" || die "cannot check out HEAD"
git -C "$WORK/repo" ls-files -z | (cd "$WORK/repo" && xargs -0 rm -f)
git -C "$REPO" ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' f; do
        if [ -e "$REPO/$f" ] || [ -L "$REPO/$f" ]; then printf '%s\0' "$f"; fi
    done |
    tar -C "$REPO" --null -T - -cf - | tar -C "$WORK/repo" -xf - || die "cannot copy the working tree"
git -C "$WORK/repo" add -A
if git -C "$WORK/repo" diff --cached --quiet; then
    NEW_COMMIT=$head
    echo "new: HEAD ${head:0:12}, no uncommitted changes"
else
    git -C "$WORK/repo" -c user.name=update-routes -c user.email=update-routes@localhost \
        commit -q -m "Working tree under test" || die "cannot commit the working tree snapshot"
    NEW_COMMIT=$(git -C "$WORK/repo" rev-parse HEAD)
    echo "new: HEAD ${head:0:12} plus the uncommitted changes, as ${NEW_COMMIT:0:12} in a private clone"
fi
echo "old: $from = ${OLD_COMMIT:0:12}"

# The release merge: a fast-forward when the old release is an ancestor,
# otherwise a merge commit that carries the new tree.
if git -C "$WORK/repo" merge-base --is-ancestor "$OLD_COMMIT" "$NEW_COMMIT"; then
    RELEASE_COMMIT=$NEW_COMMIT
else
    RELEASE_COMMIT=$(git -C "$WORK/repo" -c user.name=update-routes -c user.email=update-routes@localhost \
        commit-tree "$NEW_COMMIT^{tree}" -p "$OLD_COMMIT" -p "$NEW_COMMIT" -m "Release merge") ||
        die "cannot make the release merge"
    echo "$from is not an ancestor of the new version; testing a merge commit"
fi

version_of_project() { sed -n 's/^project(plasma-terminal-widget VERSION \([0-9.]*\).*/\1/p'; }
version_of_metadata() { sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' | sed -n 1p; }
normalised() { case "$1" in *.*.*) echo "$1" ;; *.*) echo "$1.0" ;; *) echo "$1" ;; esac; }

NEW_VERSION=$(version_of_project < "$WORK/repo/CMakeLists.txt")
new_package_version=$(version_of_metadata < "$WORK/repo/package/metadata.json")
OLD_PKG_VERSION=$(normalised "$(git -C "$WORK/repo" show "$OLD_COMMIT:package/metadata.json" | version_of_metadata)")
OLD_VERSION=$(git -C "$WORK/repo" show "$OLD_COMMIT:CMakeLists.txt" | version_of_project)
[ -n "$NEW_VERSION" ] || die "no project version in CMakeLists.txt"
echo "versions: old package $OLD_PKG_VERSION, old project $OLD_VERSION, new $NEW_VERSION"
if [ "$new_package_version" = "$NEW_VERSION" ]; then
    record setup versions PASS "package/metadata.json and CMakeLists.txt both say $NEW_VERSION"
else
    record setup versions FAIL "package/metadata.json says $new_package_version, CMakeLists.txt $NEW_VERSION"
fi
# doc/releasing.md step 2: an engine change users notice raises requiredEngine
# to the new version. Any change to src/ or lib/ since the previous release
# counts here; one users cannot notice, such as a build fix, has to be judged
# by hand.
REQUIRED_ENGINE=$(sed -n 's/^var requiredEngine = "\([0-9.]*\)".*/\1/p' "$WORK/repo/package/contents/ui/version.js")
if git -C "$WORK/repo" diff --quiet "$OLD_COMMIT" "$NEW_COMMIT" -- src lib; then
    record setup versions PASS "the engine (src/, lib/) is unchanged since $from, so requiredEngine ($REQUIRED_ENGINE) may stay"
elif [ "$REQUIRED_ENGINE" = "$NEW_VERSION" ]; then
    record setup versions PASS "the engine (src/, lib/) changed since $from, and requiredEngine in version.js is $NEW_VERSION"
else
    record setup versions FAIL "the engine (src/, lib/) changed since $from, but requiredEngine in version.js is ${REQUIRED_ENGINE:-missing}, not $NEW_VERSION"
fi

# True if version $1 is older than version $2.
version_older() { [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]; }

# The store's file, built exactly as doc/releasing.md step 6 says.
PLASMOID=io.github.cir0cuit.plasmaterminal-$NEW_VERSION.plasmoid
(cd "$WORK/repo/package" && zip -qr "../$PLASMOID" .) || die "cannot build $PLASMOID"

# --- containers -------------------------------------------------------------

ensure_image() { # <distro>: prints the image tag, building it if needed
    local file=$WORK/repo/test/containers/$1.Containerfile tag
    [ -f "$file" ] || return 1
    tag=localhost/ptw-update-routes-$1:$(sha256sum "$file" | cut -c1-12)
    if ! podman image exists "$tag"; then
        echo "building $tag (log: $out/containers/image-$1.log)" >&2
        nice -n 10 podman build -f "$file" -t "$tag" "$WORK/repo/test/containers" \
            > "$out/containers/image-$1.log" 2>&1 || return 1
    fi
    echo "$tag"
}

run_route() { # <distro> <image> <route>
    local distro=$1 image=$2 route=$3 log=$out/containers/$1-$3.log t0 rc
    t0=$(date +%s)
    # In the background with wait, so that Ctrl-C is handled at once.
    # --log-driver=none: the output goes to the log file only, not also to the
    # journal, where podman sends it by default on some systems.
    timeout 1800 nice -n 10 podman run --rm --pull=never --network=none --log-driver=none \
        --name "$RUN_ID-$distro-$route" \
        -v "$WORK/share:/work:ro,z" \
        -v "ptw-update-routes-ccache-$distro:/ccache:U" \
        -e LANG=C.UTF-8 -e CCACHE_DIR=/ccache -e CMAKE_CXX_COMPILER_LAUNCHER=ccache \
        "$image" bash /work/routes.sh "$route" > "$log" 2>&1 < /dev/null &
    wait $!
    rc=$?
    sed -n 's/^CHECK \(PASS\|FAIL\) [^ ]* \(.*\)$/\1\t\2/p' "$log" |
        while IFS=$'\t' read -r result what; do
            record "$distro" "$route" "$result" "$what"
        done
    if ! grep -q "^ROUTE DONE $route " "$log"; then
        record "$distro" "$route" FAIL "the route did not finish (exit $rc), see $log"
    fi
    echo "  ($distro $route took $(elapsed "$t0"), log: $log)"
}

containers_part() {
    local distro image t0
    mkdir -p "$out/containers" "$WORK/share"
    cp "$WORK/repo/$PLASMOID" "$WORK/repo/test/containers/routes.sh" "$WORK/share/"
    git -C "$WORK/repo" branch -q -f old "$OLD_COMMIT"
    git -C "$WORK/repo" branch -q -f new "$RELEASE_COMMIT"
    git -C "$WORK/repo" bundle create -q "$WORK/share/repo.bundle" old new || die "cannot bundle the repository"
    cat > "$WORK/share/routes.env" <<EOF
OLD_COMMIT=$OLD_COMMIT
NEW_COMMIT=$RELEASE_COMMIT
NEW_VERSION=$NEW_VERSION
OLD_PKG_VERSION=$OLD_PKG_VERSION
PLASMOID=$PLASMOID
EOF
    chmod -R a+rX "$WORK/share"
    for distro in $containers; do
        say "Containers: $distro"
        t0=$(date +%s)
        if ! image=$(ensure_image "$distro"); then
            record "$distro" image FAIL "building the image failed, see $out/containers/image-$distro.log"
            continue
        fi
        echo "image $image, built or found in $(elapsed "$t0")"
        podman volume exists "ptw-update-routes-ccache-$distro" ||
            podman volume create "ptw-update-routes-ccache-$distro" > /dev/null
        for route in $routes; do
            run_route "$distro" "$image" "$route"
        done
        timings+=("$distro: $(elapsed "$t0")")
    done
}

# --- the nested desktop -----------------------------------------------------

D=$WORK/desktop
APPLET=io.github.cir0cuit.plasmaterminal
ACTIVITY=6f1e0c2a-5d43-4b8e-9a17-2c3b4d5e6f70
SHELL_PID=
NESTED_PID=
a11y=0

# Every process of this test's nested session carries its private runtime
# directory in its environment; nothing else on the machine does.
desk_pids() {
    local p
    case "$RT" in "" | /run/user/*) return ;; esac
    for p in $(pgrep -u "$(id -u)"); do
        [ "$p" = "$$" ] && continue
        if tr '\0' '\n' 2> /dev/null < "/proc/$p/environ" | grep -qxF "XDG_RUNTIME_DIR=$RT"; then
            echo "$p"
        fi
    done
}

# The nested kwin_wayland. It has file capabilities, so its environment
# cannot be read and desk_pids never lists it; its command line can be, and
# names this run's session script, which no other kwin does.
desk_kwin() {
    local p
    for p in $(pgrep -u "$(id -u)" -x kwin_wayland); do
        tr '\0' '\n' 2> /dev/null < "/proc/$p/cmdline" | grep -qxF "$D/session.sh" && echo "$p"
    done
}

# The session's processes apart from those it needs until kwin has quit:
# dbus-run-session, its bus, and the session script with its sleep.
desk_clients() {
    local p parent
    for p in $(desk_pids); do
        parent=$(ps -o ppid= -p "$p" 2> /dev/null | tr -d ' ')
        if [ "$p" = "$NESTED_PID" ] || [ "$parent" = "$NESTED_PID" ] ||
            [ "$(ps -o comm= -p "$p" 2> /dev/null)" = session.sh ] ||
            [ "$(ps -o comm= -p "$parent" 2> /dev/null)" = session.sh ]; then
            continue
        fi
        echo "$p"
    done
}

# Stop the nested session in its own order: plasmashell and the other
# clients, then the session script, so that kwin quits by itself while its
# bus is still there, then the bus, which dbus-run-session stops once kwin has
# gone. A kwin that loses its bus in the middle of a call aborts, and the
# crash is reported on the real desktop.
desk_kill_all() {
    local pids kwin _
    if [ -n "$SHELL_PID" ] && desk_pids | grep -qx "$SHELL_PID"; then
        kill "$SHELL_PID" 2> /dev/null
        for _ in $(seq 10); do
            kill -0 "$SHELL_PID" 2> /dev/null || break
            sleep 0.5
        done
    fi
    SHELL_PID=
    if [ -n "$NESTED_PID" ]; then
        pids=$(desk_clients)
        if [ -n "$pids" ]; then
            # shellcheck disable=SC2086
            kill $pids 2> /dev/null
            for _ in $(seq 10); do
                [ -n "$(desk_clients)" ] || break
                sleep 0.5
            done
        fi
    fi
    touch "$D/session.stop" 2> /dev/null
    if [ -n "$NESTED_PID" ]; then
        for _ in $(seq 30); do
            kill -0 "$NESTED_PID" 2> /dev/null || break
            sleep 0.5
        done
    fi
    NESTED_PID=
    # Still there, for example stuck while starting: SIGKILL, which leaves no
    # core dump. kwin only catches SIGTERM, which does nothing while it starts.
    kwin=$(desk_kwin)
    # shellcheck disable=SC2086
    [ -n "$kwin" ] && kill -KILL $kwin 2> /dev/null
    pids=$(desk_pids)
    [ -n "$pids" ] || return 0
    # shellcheck disable=SC2086
    kill $pids 2> /dev/null
    for _ in 1 2 3 4 5 6; do
        sleep 0.5
        pids=$(desk_pids)
        [ -n "$pids" ] || return 0
    done
    # shellcheck disable=SC2086
    kill -9 $pids 2> /dev/null
}

# Run a command inside the nested session's environment. bash --norc: a
# non-interactive bash whose stdin is a socket would otherwise read ~/.bashrc.
nrun() {
    # shellcheck disable=SC2016 # expanded by the inner bash
    (cd "$D" && env -i bash --norc --noprofile -c 'set -a; . "$1"; set +a; shift; exec "$@"' _ "$D/session.env" "$@")
}

build_engine() { # <old|new> <commit>
    local src=$WORK/src-$1 build=$WORK/build-$1
    mkdir -p "$src"
    git -C "$WORK/repo" archive "$2" | tar -x -C "$src" || return 1
    {
        nice -n 10 cmake -Wno-dev -S "$src" -B "$build" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DPT_BUILD_HARNESS=OFF &&
            nice -n 10 cmake --build "$build" -j"$(nproc)"
    } > "$out/desktop/build-$1.log" 2>&1
}

desk_seed_static() {
    local plasma_version
    mkdir -p "$D/config" "$D/data/dbus-1/services" "$D/cache" "$D/state" "$D/bin" "$D/empty" "$D/probe/rt"
    chmod 700 "$D/probe/rt"
    # plasmashell builds its shell, and with it a Wayland connection, before it
    # reads --version, whatever QT_QPA_PLATFORM says. So it is asked with a
    # runtime directory, bus and settings of its own, where it finds no
    # display, and with its warnings on stderr, which Qt would otherwise send
    # to the journal.
    plasma_version=$(env -i HOME="$HOME" PATH=/usr/bin:/bin LANG=C.UTF-8 XDG_RUNTIME_DIR="$D/probe/rt" \
        XDG_CONFIG_HOME="$D/probe" XDG_DATA_HOME="$D/probe" XDG_CACHE_HOME="$D/probe" XDG_STATE_HOME="$D/probe" \
        QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 plasmashell --version 2> /dev/null |
        awk '{ print $2 }')
    cat > "$D/config/kactivitymanagerdrc" <<EOF
[activities]
$ACTIVITY=Default

[main]
currentActivity=$ACTIVITY
EOF
    cat > "$D/config/plasma-welcomerc" <<EOF
[General]
LastSeenVersion=$plasma_version
ShouldShow=false
EOF
    # No kded6 at all: it would run with the real home directory and this
    # machine's system bus, where its modules rewrite ~/.gtkrc-2.0, register
    # Bluetooth profiles and mount disks. In this session only D-Bus can start
    # it.
    cat > "$D/data/dbus-1/services/org.kde.kded6.service" <<'EOF'
[D-BUS Service]
Name=org.kde.kded6
Exec=/bin/false
EOF
    # Keystrokes on a nested desktop would start KRunner, which crashes there.
    cat > "$D/data/dbus-1/services/org.kde.krunner.service" <<'EOF'
[D-BUS Service]
Name=org.kde.krunner
Exec=/bin/false
EOF
    printf '#!/bin/sh\nexit 0\n' > "$D/bin/krunner"
    # The shell of every terminal in the session: it notes that a terminal came
    # up, and never reads or writes the real user's rc or history files.
    cat > "$D/bin/test-shell" <<EOF
#!/bin/bash
echo "\$\$" >> "$D/shells-started"
export HISTFILE=/dev/null
exec /bin/bash --norc --noprofile "\$@"
EOF
    chmod +x "$D/bin/krunner" "$D/bin/test-shell"
    cat > "$D/session.sh" <<EOF
#!/bin/bash
dbus-update-activation-environment WAYLAND_DISPLAY QT_QPA_PLATFORM GDK_BACKEND PATH SHELL
export -p > "$D/session.env"
touch "$D/session.ready"
while [ ! -e "$D/session.stop" ]; do sleep 1; done
EOF
    chmod +x "$D/session.sh"
}

desk_start() {
    local _
    # A Wayland socket path has to fit in 107 bytes, so the runtime directory
    # gets a short name of its own.
    RT=$(mktemp -d /tmp/ptwr.XXXXXX) || return 1
    desk_seed_static
    env -i HOME="$HOME" USER="$(id -un)" LANG="${LANG:-C.UTF-8}" PATH="$D/bin:/usr/bin:/bin" \
        SHELL="$D/bin/test-shell" XDG_RUNTIME_DIR="$RT" \
        XDG_CONFIG_HOME="$D/config" XDG_DATA_HOME="$D/data" XDG_CACHE_HOME="$D/cache" XDG_STATE_HOME="$D/state" \
        QT_QPA_PLATFORM=wayland GDK_BACKEND=wayland WAYLAND_DISPLAY=wl \
        dbus-run-session -- kwin_wayland --virtual --no-lockscreen --socket wl --width 1280 --height 800 \
        --exit-with-session "$D/session.sh" > "$out/desktop/kwin.log" 2>&1 < /dev/null &
    NESTED_PID=$!
    for _ in $(seq 60); do
        [ -e "$D/session.ready" ] && break
        sleep 0.5
    done
    [ -e "$D/session.ready" ] || return 1
    # The accessibility bus and its registry, through which the test reads the
    # text on screen and switches settings pages. D-Bus activation does not
    # work for either in this private session (it goes through systemd), so
    # both are started directly.
    a11y=0
    local launcher registry address=''
    launcher=$(sed -n 's/^Exec=//p' /usr/share/dbus-1/services/org.a11y.Bus.service 2> /dev/null | awk '{ print $1 }')
    registry=$(sed -n 's/^Exec=//p' /usr/share/dbus-1/accessibility-services/org.a11y.atspi.Registry.service 2> /dev/null | awk '{ print $1 }')
    if [ -x "$launcher" ] && [ -x "$registry" ] &&
        python3 -I -c 'import gi; gi.require_version("Atspi", "2.0"); from gi.repository import Atspi' 2> /dev/null; then
        # --launch-immediately is the only option it takes; any other aborts it.
        nrun "$launcher" --launch-immediately > "$out/desktop/a11y-bus.log" 2>&1 < /dev/null &
        for _ in $(seq 20); do
            address=$(nrun "$QDBUS" org.a11y.Bus /org/a11y/bus org.a11y.Bus.GetAddress 2> /dev/null) && break
            sleep 0.5
        done
        if [ -n "$address" ]; then
            # Without options: it finds the accessibility bus through org.a11y.Bus.
            nrun "$registry" >> "$out/desktop/a11y-bus.log" 2>&1 < /dev/null &
            for _ in $(seq 20); do
                nrun "$QDBUS" --bus "$address" org.a11y.atspi.Registry > /dev/null 2>&1 && { a11y=1; break; }
                sleep 0.5
            done
        fi
    fi
    if [ "$a11y" = 0 ]; then
        record desktop setup FAIL "the accessibility bus did not start, so the text on screen cannot be read; see $out/desktop/a11y-bus.log"
    fi
    write_helpers
}

desk_stop() {
    shell_quit
    desk_kill_all
    rm -rf "$RT"
    RT=
}

# Python helpers, written at run time so that the test stays one file.
write_helpers() {
    # a11y.py dump <file> | press <window> <name> | windows
    cat > "$WORK/a11y.py" <<'PY'
import sys, time, warnings
import gi
gi.require_version("Atspi", "2.0")
from gi.repository import Atspi

# Some of the calls used here are deprecated in newer AT-SPI, not removed.
warnings.simplefilter("ignore", DeprecationWarning)

def shell():
    desktop = Atspi.get_desktop(0)
    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)
        if app is not None and app.get_name() == "plasmashell":
            return app
    return None

def walk(node, depth, visit):
    if depth > 80:
        return
    try:
        count = node.get_child_count()
    except Exception:
        return
    for i in range(count):
        try:
            child = node.get_child_at_index(i)
        except Exception:
            continue
        if child is None:
            continue
        visit(child)
        walk(child, depth + 1, visit)

def text_of(node):
    try:
        if node.get_text_iface() is not None:
            return Atspi.Text.get_text(node, 0, Atspi.Text.get_character_count(node))
    except Exception:
        pass
    return ""

def showing(node):
    try:
        return node.get_state_set().contains(Atspi.StateType.SHOWING)
    except Exception:
        return False

def windows(app):
    result = []
    for i in range(app.get_child_count()):
        w = app.get_child_at_index(i)
        if w is not None:
            result.append(w)
    return result

cmd = sys.argv[1]
app = None
for attempt in range(20):
    app = shell()
    if app is not None:
        break
    time.sleep(0.5)
if app is None:
    print("plasmashell is not on the accessibility bus", file=sys.stderr)
    sys.exit(3)

if cmd == "windows":
    for w in windows(app):
        print(w.get_name())
elif cmd == "dump":
    # Exit 4 if plasmashell shows no windows, 5 if its windows carry no text.
    found = {"windows": 0, "lines": 0}
    with open(sys.argv[2], "w") as f:
        for w in windows(app):
            found["windows"] += 1
            wname = w.get_name() or ""
            def visit(n, wname=wname):
                if not showing(n):
                    return
                name = (n.get_name() or "").replace("\n", " ")
                text = text_of(n).replace("\n", " ")
                if name or text:
                    f.write("%s\t%s\t%s\t%s\n" % (wname, n.get_role_name(), name, text))
                    found["lines"] += 1
            walk(w, 0, visit)
    if not found["windows"]:
        sys.exit(4)
    if not found["lines"]:
        print("no text in: %s" % ", ".join(w.get_name() or "?" for w in windows(app)), file=sys.stderr)
        sys.exit(5)
elif cmd == "press":
    want_window, want_name = sys.argv[2], sys.argv[3]
    found = []
    for w in windows(app):
        if want_window not in (w.get_name() or ""):
            continue
        def visit(n):
            if not found and (n.get_name() or "") == want_name and n.get_role_name() == "page tab":
                found.append(n)
        walk(w, 0, visit)
    if not found:
        sys.exit(1)
    # A page tab offers SetFocus and Press; Press opens the page.
    action = found[0].get_action_iface()
    for i in range(action.get_n_actions() if action is not None else 0):
        if action.get_action_name(i).lower() == "press":
            sys.exit(0 if action.do_action(i) else 1)
    sys.exit(1)
PY
}

# plasmashell with one engine: "old" or "new" from the build directories, or
# "none". The engine installed on this machine is hidden in every case by an
# empty directory mounted over it in a private mount namespace, so that the
# run cannot silently fall back to it.
# Each line of plasmashell's log starts with the message type, and messages
# from QML code name their file, so that the package's own lines can be told
# apart from Plasma's.
MESSAGE_PATTERN='%{type}: %{if-category}%{category}: %{endif}%{file}:%{line}: %{message}'

shell_start() { # <old|new|none> <log> [VAR=value...]
    local engine=$1 log=$2 import='' _
    shift 2
    case "$engine" in
        old | new) import=$WORK/build-$engine/qml ;;
    esac
    rm -f "$D/shells-started"
    : > "$D/shells-started"
    if [ -n "$SYSTEM_ENGINE" ]; then
        # shellcheck disable=SC2016 # expanded by sh -c
        nrun env ${import:+QML_IMPORT_PATH="$import"} QT_FORCE_STDERR_LOGGING=1 \
            QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 QT_MESSAGE_PATTERN="$MESSAGE_PATTERN" "$@" \
            unshare -r -m sh -c 'mount --bind "$1" "$2" && exec unshare --user --map-user="$3" --map-group="$4" plasmashell --no-respawn' \
            _ "$D/empty" "$SYSTEM_ENGINE" "$(id -u)" "$(id -g)" > "$log" 2>&1 < /dev/null &
    else
        nrun env ${import:+QML_IMPORT_PATH="$import"} QT_FORCE_STDERR_LOGGING=1 \
            QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 QT_MESSAGE_PATTERN="$MESSAGE_PATTERN" "$@" \
            plasmashell --no-respawn > "$log" 2>&1 < /dev/null &
    fi
    SHELL_PID=
    for _ in $(seq 120); do
        if nrun "$QDBUS" org.kde.plasmashell /PlasmaShell > /dev/null 2>&1; then
            for SHELL_PID in $(desk_pids); do
                [ "$(cat "/proc/$SHELL_PID/comm" 2> /dev/null)" = plasmashell ] && break
                SHELL_PID=
            done
            [ -n "$SHELL_PID" ] && break
        fi
        sleep 0.5
    done
    [ -n "$SHELL_PID" ] || return 1
    # Let the desktop and its widgets load.
    sleep 6
}

shell_quit() {
    local _
    [ -n "$SHELL_PID" ] || return 0
    nrun "$QDBUS" org.kde.plasmashell /MainApplication quit > /dev/null 2>&1
    for _ in $(seq 40); do
        kill -0 "$SHELL_PID" 2> /dev/null || break
        sleep 0.5
    done
    if kill -0 "$SHELL_PID" 2> /dev/null && desk_pids | grep -qx "$SHELL_PID"; then
        kill -9 "$SHELL_PID"
    fi
    SHELL_PID=
    sleep 1
}

shell_eval() { # <javascript>: Plasma's desktop scripting
    nrun "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"
}

kwin_eval() { # <name> <javascript>: KWin scripting
    local id
    printf '%s\n' "$2" > "$D/$1.js"
    id=$(nrun "$QDBUS" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$D/$1.js" "$1") || return 1
    nrun "$QDBUS" org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run > /dev/null
}

close_settings() {
    kwin_eval "close$(date +%s%N)" 'workspace.windowList().forEach(function (w) { if (w.caption.indexOf("Settings") >= 0) { w.closeWindow(); } });'
    sleep 2
}

shot() { # <name>
    nrun timeout 30 spectacle -b -n -f -o "$out/desktop/$1.png" > /dev/null 2>&1
    if [ -s "$out/desktop/$1.png" ]; then
        echo "  screenshot: $out/desktop/$1.png"
    else
        echo "  screenshot $1 failed"
    fi
}

# The engine plasmashell has loaded, from its memory map.
engine_loaded() {
    grep -o '/[^ ]*/libplasmaterminalcoreplugin\.so' "/proc/$SHELL_PID/maps" 2> /dev/null | sort -u | tr '\n' ' '
}

expect_engine_loaded() { # <scenario> <old|new|none>
    local loaded want
    loaded=$(engine_loaded)
    case "$2" in
        none) want= ;;
        *) want="$WORK/build-$2/qml/io/github/cir0cuit/plasmaterminal/core/libplasmaterminalcoreplugin.so " ;;
    esac
    if [ "$loaded" = "$want" ]; then
        record desktop "$1" PASS "plasmashell has the $2 engine loaded${want:+ ($want)}"
    else
        record desktop "$1" FAIL "plasmashell should have the $2 engine loaded, has: ${loaded:-none}"
    fi
}

shells_started() { wc -l < "$D/shells-started"; }

wait_for_shells() { # <count> [seconds]
    local _
    for _ in $(seq $((${2:-20} * 2))); do
        [ "$(shells_started)" -ge "$1" ] && return 0
        sleep 0.5
    done
    return 1
}

# Warnings and errors from the widget package's own files. Plasma prints two
# kinds of line for every settings page of every widget; those are not the
# package's.
package_warnings() { # <log> [extra pattern to ignore]
    grep -E '^(warning|critical|fatal): ' "$1" |
        grep -F "/plasma/plasmoids/$APPLET/" |
        grep -v -e 'Created graphical object was not placed in the graphics scene' \
            -e 'Setting initial properties failed: ' |
        { if [ -n "${2:-}" ]; then grep -v -E -e "$2"; else cat; fi; }
}

expect_clean_log() { # <scenario> <log> [extra pattern to ignore]
    local found
    found=$(package_warnings "$2" "${3:-}")
    if [ -z "$found" ]; then
        record desktop "$1" PASS "no warnings or errors from the widget package's files in $(basename "$2")"
    else
        printf '%s\n' "$found" > "${2%.log}-package-warnings.txt"
        record desktop "$1" FAIL "$(printf '%s\n' "$found" | wc -l) warnings from the widget package, first: $(printf '%s\n' "$found" | head -n 1 | cut -c1-300)"
    fi
}

# The text plasmashell shows, one line per item, into $out/desktop/<name>.txt,
# with a failed check of the scenario if it cannot be read. A failed read
# leaves no file, so that no check passes on a partial one. With "textless",
# windows that show no text at all count as read.
screen_text() { # <scenario> <name> [textless]
    local rc=0 why
    if [ "$a11y" = 1 ]; then
        nrun python3 -I "$WORK/a11y.py" dump "$out/desktop/$2.txt" 2>> "$out/desktop/a11y.log" || rc=$?
        [ "$rc" -eq 0 ] && return 0
        [ "$rc" -eq 5 ] && [ "${3:-}" = textless ] && return 0
        case "$rc" in
            3) why="plasmashell is not on the accessibility bus" ;;
            4) why="the accessibility bus shows no plasmashell windows" ;;
            5) why="plasmashell's windows show no text on the accessibility bus" ;;
            *) why="a11y.py exited with $rc, see $out/desktop/a11y.log" ;;
        esac
    else
        why="the accessibility bus is not running"
    fi
    rm -f "$out/desktop/$2.txt"
    record desktop "$1" FAIL "cannot read the screen for $2: $why (see $out/desktop/$2.png)"
    return 1
}

expect_text() { # <scenario> <dump name> <window> <present|absent> <what> <text>...
    local scenario=$1 dump=$out/desktop/$2.txt window=$3 want=$4 what=$5 hits t
    shift 5
    if [ ! -f "$dump" ]; then
        record desktop "$scenario" FAIL "$what: the screen could not be read; see ${dump%.txt}.png"
        return
    fi
    # One item on screen has to carry every given text.
    hits=$(awk -F '\t' -v w="$window" 'index($1, w)' "$dump")
    for t in "$@"; do
        hits=$(printf '%s\n' "$hits" | grep -F -- "$t")
    done
    if [ "$want" = present ] && [ -n "$hits" ]; then
        record desktop "$scenario" PASS "$what"
    elif [ "$want" = absent ] && [ -z "$hits" ]; then
        record desktop "$scenario" PASS "$what"
    elif [ "$want" = present ]; then
        record desktop "$scenario" FAIL "$what: not on screen (see $dump)"
    else
        record desktop "$scenario" FAIL "$what: on screen: $(printf '%s\n' "$hits" | head -n 1 | cut -f 3- | cut -c1-200)"
    fi
}

seed_appletsrc() { # <desktop|panel>
    local f=$D/config/plasma-org.kde.plasma.desktop-appletsrc
    rm -f "$D/config/plasmashellrc"
    if [ "$1" = panel ]; then
        cat > "$f" <<EOF
[Containments][1]
activityId=$ACTIVITY
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.desktopcontainment
wallpaperplugin=org.kde.color

[Containments][1][General]
showToolbox=false

[Containments][1][Wallpaper][org.kde.color][General]
Color=46,52,64

[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][2][Applets][3]
immutability=1
plugin=$APPLET

[Containments][2][General]
AppletOrder=3
EOF
        cat > "$D/config/plasmashellrc" <<'EOF'
[PlasmaViews][Panel 2][Defaults]
thickness=44
EOF
    else
        cat > "$f" <<EOF
[Containments][1]
ItemGeometries-1280x800=Applet-2:40,40,880,420,0;
ItemGeometriesHorizontal=Applet-2:40,40,880,420,0;
activityId=$ACTIVITY
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.desktopcontainment
wallpaperplugin=org.kde.color

[Containments][1][Applets][2]
immutability=1
plugin=$APPLET

[Containments][1][Applets][2][Configuration][Appearance]
colorScheme=Breeze
fontSize=12
padding=10

[Containments][1][Applets][2][Configuration][Shell]
startupCommand=echo "update-routes: this terminal runs"

[Containments][1][General]
showToolbox=false

[Containments][1][Wallpaper][org.kde.color][General]
Color=46,52,64
EOF
    fi
}

# Open the settings of the first terminal widget and visit its three pages.
# The checks for each page are given as a function name and run while the
# page is shown.
visit_settings() { # <scenario> <page check function>
    local scenario=$1 check=$2 page name
    shell_eval "var ws = desktops()[0].widgets(\"$APPLET\"); if (ws.length) { ws[0].showConfigurationInterface(); }" > /dev/null
    sleep 5
    for page in Appearance Shell Behavior; do
        if [ "$page" != Appearance ] &&
            ! { [ "$a11y" = 1 ] && nrun python3 -I "$WORK/a11y.py" press Settings "$page" 2>> "$out/desktop/a11y.log"; }; then
            record desktop "$scenario" FAIL "could not switch to the $page settings page"
            continue
        fi
        sleep 3
        name="$scenario-settings-$(echo "$page" | tr '[:upper:]' '[:lower:]')"
        shot "$name"
        screen_text "$scenario" "$name" || continue
        # The page's own heading shows that the dialog really is on it.
        if ! awk -F '\t' -v p="$page" 'index($1, "Settings") && $2 == "heading" && $3 == p { f = 1 }
                END { exit !f }' "$out/desktop/$name.txt"; then
            record desktop "$scenario" FAIL "the settings dialog does not show the $page page (see $out/desktop/$name.png)"
            continue
        fi
        "$check" "$scenario" "$name" "$page"
    done
    close_settings
}

store_update_desktop() {
    local file_version installed
    file_version=$(version_of_metadata < "$WORK/repo/package/metadata.json")
    installed=$(version_of_metadata < "$D/data/plasma/plasmoids/$APPLET/metadata.json")
    if python3 -I -c 'import sys; k = lambda v: [int(x) for x in v.split(".")]; sys.exit(0 if k(sys.argv[1]) > k(sys.argv[2]) else 1)' "$file_version" "$installed"; then
        record desktop D1 PASS "the store file's Version $file_version is newer than the installed $installed, so KPackage replaces it"
    else
        record desktop D1 FAIL "the store file's Version $file_version is not newer than the installed $installed: KPackage would keep the old files"
    fi
    if nrun kpackagetool6 --type Plasma/Applet --upgrade "$WORK/repo/$PLASMOID" >> "$out/desktop/kpackagetool.log" 2>&1; then
        record desktop D1 PASS "kpackagetool6 replaced the package with $PLASMOID while plasmashell runs"
    else
        record desktop D1 FAIL "kpackagetool6 could not replace the package, see $out/desktop/kpackagetool.log"
    fi
}

# A page that failed to load is blank apart from the dialog's own buttons.
expect_page_controls() { # <scenario> <dump> <page>
    local n
    n=$(awk -F '\t' 'index($1, "Settings") && ($2 == "check box" || $2 == "combo box" || $2 == "spin button" || $2 == "slider")' \
        "$out/desktop/$2.txt" 2> /dev/null | wc -l)
    if [ "$n" -ge 3 ]; then
        record desktop "$1" PASS "$3 page shows its settings ($n controls)"
    else
        record desktop "$1" FAIL "$3 page shows $n controls; it looks blank (see $out/desktop/$2.png)"
    fi
}

page_outdated() { # <scenario> <dump> <page>
    expect_page_controls "$@"
    expect_text "$1" "$2" Settings present "$3 page says the engine is $OLD_ENGINE_SEEN and $REQUIRED_ENGINE is needed" \
        "$OLD_ENGINE_SEEN" "$REQUIRED_ENGINE"
    expect_text "$1" "$2" Settings present "$3 page gives the update command" "$REQUIRED_ENGINE" "git pull && ./update.sh"
    expect_text "$1" "$2" Settings absent "$3 page does not claim the engine is missing" "Terminal engine not installed"
}

page_current() { # <scenario> <dump> <page>
    expect_page_controls "$@"
    expect_text "$1" "$2" Settings absent "$3 page shows no outdated-engine notice" "$REQUIRED_ENGINE"
    expect_text "$1" "$2" Settings absent "$3 page shows no missing-engine notice" "Terminal engine not installed"
}

page_missing() { # <scenario> <dump> <page>
    expect_page_controls "$@"
    expect_text "$1" "$2" Settings present "$3 page says the engine is not installed" "Terminal engine not installed"
}

# The widget on the desktop shows a terminal, not one of its placeholders.
# The terminal offers no text to the accessibility interface, so a desktop with
# only a terminal on it has none at all, while a placeholder would show its
# text there.
expect_terminal_shown() { # <scenario> <dump>
    screen_text "$1" "$2" textless || return 0
    expect_text "$1" "$2" Desktop absent "the widget does not claim the engine is missing" "Terminal engine not installed"
    expect_text "$1" "$2" Desktop absent "the widget shows no load error" "could not be loaded"
}

desktop_part() {
    local t0 added
    t0=$(date +%s)
    mkdir -p "$out/desktop"
    say "Desktop: building the old and the new engine"
    if ! build_engine old "$OLD_COMMIT"; then
        record desktop setup FAIL "building the old engine failed, see $out/desktop/build-old.log"
        return
    fi
    if ! build_engine new "$NEW_COMMIT"; then
        record desktop setup FAIL "building the new engine failed, see $out/desktop/build-new.log"
        return
    fi
    local vfile=$WORK/build-new/qml/io/github/cir0cuit/plasmaterminal/core/version
    if [ "$(tr -d '[:space:]' < "$vfile" 2> /dev/null)" = "$NEW_VERSION" ]; then
        record desktop build PASS "the new engine's build writes qml/.../core/version with $NEW_VERSION"
    else
        record desktop build FAIL "the new engine's build has no qml/.../core/version saying $NEW_VERSION"
    fi
    echo "engines built in $(elapsed "$t0")"
    # What the old engine says about itself: engines before 1.1.0 have no
    # version file and count as 1.0.0.
    OLD_ENGINE_SEEN=1.0.0
    if [ -f "$WORK/build-old/qml/io/github/cir0cuit/plasmaterminal/core/version" ]; then
        OLD_ENGINE_SEEN=$(tr -d '[:space:]' < "$WORK/build-old/qml/io/github/cir0cuit/plasmaterminal/core/version")
    fi

    if [ -n "$SYSTEM_ENGINE" ]; then
        echo "the engine installed in $SYSTEM_ENGINE is hidden from the nested session"
    fi

    say "Desktop: starting the nested session"
    if ! desk_start; then
        record desktop setup FAIL "the nested session did not start, see $out/desktop/kwin.log"
        return
    fi

    say "D1: the store updates the widget package while Plasma runs"
    seed_appletsrc panel
    nrun kpackagetool6 --type Plasma/Applet --install "$WORK/src-old/package" > "$out/desktop/kpackagetool.log" 2>&1
    if ! shell_start old "$out/desktop/d1-plasmashell.log" PLASMA_PRELOAD_POLICY=none; then
        record desktop D1 FAIL "plasmashell did not start, see $out/desktop/d1-plasmashell.log"
    else
        if [ "$(shells_started)" -eq 0 ]; then
            record desktop D1 PASS "before the update, no terminal is loaded (the panel widget's popup was never opened)"
        else
            record desktop D1 FAIL "a terminal started before the update, so the test does not cover a never-loaded pane"
        fi
        shot d1-1-before-update
        store_update_desktop
        added=$(shell_eval "var w = desktops()[0].addWidget(\"$APPLET\", 40, 40, 880, 420); print(w.version);")
        echo "  added a desktop widget, version $added"
        if [ "$added" = "$NEW_VERSION" ]; then
            record desktop D1 PASS "the widget added after the update reports version $NEW_VERSION"
        else
            record desktop D1 FAIL "the widget added after the update reports version '$added', expected $NEW_VERSION"
        fi
        if wait_for_shells 1 20; then
            record desktop D1 PASS "the widget added after the update shows a terminal (its shell started)"
        else
            record desktop D1 FAIL "the widget added after the update started no shell, so it shows no terminal"
        fi
        expect_engine_loaded D1 old
        shot d1-2-widget-added
        expect_terminal_shown D1 d1-2-widget-added
        expect_clean_log D1 "$out/desktop/d1-plasmashell.log"
        shell_quit
    fi

    say "D2: the new widget package on the old engine, after a restart"
    seed_appletsrc desktop
    if [ "$(version_of_metadata < "$D/data/plasma/plasmoids/$APPLET/metadata.json")" != "$NEW_VERSION" ]; then
        nrun kpackagetool6 --type Plasma/Applet --upgrade "$WORK/repo/$PLASMOID" >> "$out/desktop/kpackagetool.log" 2>&1
    fi
    if ! shell_start old "$out/desktop/d2-plasmashell.log"; then
        record desktop D2 FAIL "plasmashell did not start, see $out/desktop/d2-plasmashell.log"
    else
        if wait_for_shells 1 20; then
            record desktop D2 PASS "the widget shows a terminal (its shell started)"
        else
            record desktop D2 FAIL "the widget started no shell"
        fi
        expect_engine_loaded D2 old
        shot d2-1-widget
        expect_terminal_shown D2 d2-1-widget
        # The pages call the old engine outdated exactly when it is older
        # than requiredEngine.
        if version_older "$OLD_ENGINE_SEEN" "$REQUIRED_ENGINE"; then
            visit_settings D2 page_outdated
        else
            visit_settings D2 page_current
        fi
        expect_clean_log D2 "$out/desktop/d2-plasmashell.log"
        shell_quit
    fi

    say "D3: the new widget package on the new engine"
    seed_appletsrc desktop
    if ! shell_start new "$out/desktop/d3-plasmashell.log"; then
        record desktop D3 FAIL "plasmashell did not start, see $out/desktop/d3-plasmashell.log"
    else
        if wait_for_shells 1 20; then
            record desktop D3 PASS "the widget shows a terminal (its shell started)"
        else
            record desktop D3 FAIL "the widget started no shell"
        fi
        expect_engine_loaded D3 new
        shot d3-1-widget
        expect_terminal_shown D3 d3-1-widget
        visit_settings D3 page_current
        expect_clean_log D3 "$out/desktop/d3-plasmashell.log"
        shell_quit
    fi

    say "D4: the new widget package without an engine"
    seed_appletsrc desktop
    if ! shell_start none "$out/desktop/d4-plasmashell.log"; then
        record desktop D4 FAIL "plasmashell did not start, see $out/desktop/d4-plasmashell.log"
    else
        sleep 4
        if [ "$(shells_started)" -eq 0 ]; then
            record desktop D4 PASS "no shell started"
        else
            record desktop D4 FAIL "a shell started although there is no engine"
        fi
        expect_engine_loaded D4 none
        shot d4-1-widget
        screen_text D4 d4-1-widget &&
            expect_text D4 d4-1-widget Desktop present "the widget says \"Terminal engine not installed\"" "Terminal engine not installed"
        visit_settings D4 page_missing
        if grep -q 'Error while loading page' "$out/desktop/d4-plasmashell.log"; then
            record desktop D4 FAIL "a settings page failed to load: $(grep -m 1 'Error while loading page' "$out/desktop/d4-plasmashell.log" | cut -c1-300)"
        else
            record desktop D4 PASS "every settings page loads"
        fi
        expect_clean_log D4 "$out/desktop/d4-plasmashell.log" '"io\.github\.cir0cuit\.plasmaterminal\.core" is not installed'
        shell_quit
    fi

    desk_stop
    timings+=("desktop: $(elapsed "$t0")")
}

# --- run --------------------------------------------------------------------

[ -n "$containers" ] && containers_part
[ "$desktop" = 1 ] && desktop_part

# --- results ----------------------------------------------------------------

say "Results"
summary() { # <part> <route>: PASS, FAIL <n>, or -
    awk -F '\t' -v p="$1" -v r="$2" '$1 == p && $2 == r { n++; if ($3 == "FAIL") f++ }
        END { if (!n) print "-"; else if (f) print "FAIL " f; else print "PASS" }' "$RESULTS"
}
if [ -n "$containers" ]; then
    printf '%-16s' route
    for d in $containers; do printf '%-10s' "$d"; done
    echo
    for r in image $routes; do
        [ "$r" = image ] && ! grep -q $'\timage\t' "$RESULTS" && continue
        printf '%-16s' "$r"
        for d in $containers; do printf '%-10s' "$(summary "$d" "$r")"; done
        echo
    done
fi
if [ "$desktop" = 1 ]; then
    for r in setup build D1 D2 D3 D4; do
        s=$(summary desktop "$r")
        [ "$s" = - ] && continue
        printf '%-16s%s\n' "desktop $r" "$s"
    done
fi
printf '%-16s%s\n' "setup" "$(summary setup versions)"

failed=$(awk -F '\t' '$3 == "FAIL"' "$RESULTS" | wc -l)
total=$(wc -l < "$RESULTS")
if [ "$failed" -gt 0 ]; then
    echo
    echo "Failed checks:"
    awk -F '\t' '$3 == "FAIL" { printf "  %s %s: %s\n", $1, $2, $4 }' "$RESULTS"
fi
echo
for t in "${timings[@]}"; do echo "time $t"; done
echo "time total: $(elapsed "$started")"
echo "$((total - failed)) of $total checks passed. Logs, screenshots and results.tsv: $out"
[ "$failed" -eq 0 ]
