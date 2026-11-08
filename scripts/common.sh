# shellcheck shell=bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Shared by install.sh, update.sh and uninstall.sh. They source it after
# changing to the project folder, so the paths below are relative to that.
# It only defines things; running it on its own does nothing.

APPLET_ID="io.github.cir0cuit.plasmaterminal"
MODULE_PATH="io/github/cir0cuit/plasmaterminal/core"

# The widget package and plasmashell belong to the user whose desktop shows
# the widget. As root they would go to root's home, and the build would leave
# files in build/ that the next run as that user cannot overwrite.
refuse_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "error: run this as the user whose desktop shows the widget, without sudo." >&2
        echo "       It asks for a password itself for the steps that need root." >&2
        exit 1
    fi
}

# Run a command as root: with sudo, or where that is not installed (Debian set
# up with a root password, a minimal Arch), with su. The scripts refuse to run
# as root, so the first branch is only a safeguard.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v su >/dev/null 2>&1; then
        # su keeps the current directory and asks for root's password. Unlike
        # sudo it reads the password from stdin, which uninstall.sh's loop
        # takes up with its list of directories, so it gets the terminal.
        if [ -z "${AS_ROOT_SU_SAID:-}" ]; then
            echo "sudo is not installed; su asks for the root password instead." >&2
            AS_ROOT_SU_SAID=1
        fi
        su root -c "$(printf '%q ' "$@")" </dev/tty
    else
        echo "error: this step needs root, and neither sudo nor su is installed." >&2
        exit 1
    fi
}

# True if this user has the widget package installed, by kpackagetool6's
# list. grep reads the whole list: under pipefail, one that quit at the first
# match could make kpackagetool6 die of SIGPIPE and turn the match into a no.
package_listed() {
    kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -xF "$APPLET_ID" >/dev/null
}

# Where Qt itself says its QML modules live, which is where plasmashell looks.
qt_qml_dirs() {
    local d tool
    for tool in qtpaths6 qmake6; do
        if command -v "$tool" >/dev/null 2>&1; then
            d=$("$tool" -query QT_INSTALL_QML 2>/dev/null) || d=
            if [ -n "$d" ]; then
                printf '%s\n' "$d"
            fi
        fi
    done
}

# Where Qt keeps its QML modules. This is not the same path on every
# distribution - Fedora uses /usr/lib64/qt6/qml, Arch /usr/lib/qt6/qml, Debian
# and Ubuntu a multiarch directory - so ask rather than assume, in the same
# order of confidence CMakeLists.txt uses. Prints one candidate per line;
# duplicates and paths that do not exist are dropped by the caller.
qml_dir_candidates() {
    # What this build tree actually installed, if it is still around. The
    # manifest is only a hint: one written as root under a strict umask cannot
    # be read, and cmake keeps that mode when it writes it again.
    if [ -r build/install_manifest.txt ]; then
        sed -n "s#\(.*\)/${MODULE_PATH}/.*#\1#p" build/install_manifest.txt | sed -n 1p
    fi
    # Ask Qt itself, exactly as the build does.
    qt_qml_dirs
    # Last resort: the layouts the distributions actually use, for a machine
    # where Qt's development tools were never installed or have since gone.
    printf '%s\n' \
        /usr/lib64/qt6/qml \
        /usr/lib/qt6/qml \
        "/usr/lib/$(uname -m)-linux-gnu/qt6/qml"
}

# Print a version as x.y.z: 1.0 recorded only major.minor. Prints nothing for
# anything that is not a version.
normalise_version() {
    case "$1" in
        *[!0-9.]* | .* | *. | *..*) ;;
        *.*.*) printf '%s\n' "$1" ;;
        *.*) printf '%s.0\n' "$1" ;;
    esac
}

# The version of this copy of the project, as x.y.z.
this_version() {
    normalise_version "$(sed -n 's/^project(plasma-terminal-widget VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt)"
}

# The version of the widget package installed for this user, wherever it came
# from (these scripts or Get New Widgets). Nothing if it is not installed.
installed_package_version() {
    local meta="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$APPLET_ID/metadata.json"
    if [ -f "$meta" ]; then
        normalise_version "$(sed -n 's/.*"Version": *"\([0-9.]*\)".*/\1/p' "$meta" | sed -n 1p)"
    fi
}

# The version of the engine plasmashell would load: the first module directory
# that holds the module's files, trying Qt's own answer first. An empty one,
# as `xargs rm < install_manifest.txt` leaves behind, is no engine. The build
# writes a "version" file next to the plugin since 1.1.0, so a module without
# one is 1.0.0. Nothing if no engine is installed.
installed_engine_version() {
    local qmldir dir types v
    while read -r qmldir; do
        dir=$qmldir/$MODULE_PATH
        if [ -n "$qmldir" ] && { [ -f "$dir/qmldir" ] || [ -f "$dir/version" ]; }; then
            v=
            if [ -f "$dir/version" ]; then
                v=$(normalise_version "$(sed -n 1p "$dir/version")")
            fi
            # 1.0's install.sh, run from an old copy, replaces a newer plugin
            # but leaves its version file behind. 1.0's type description is
            # the one without engineVersion.
            types=$dir/plasmaterminalcoreplugin.qmltypes
            if [ -f "$types" ] && ! grep -q engineVersion "$types"; then
                v=
            fi
            printf '%s\n' "${v:-1.0.0}"
            return 0
        fi
    done < <(
        qt_qml_dirs
        qml_dir_candidates
    )
}

# True if version $1 is newer than version $2.
version_newer() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]
}

# Stop if either installed half is newer than this copy. Get New Widgets can
# install a newer widget package before this copy has it, and kpackagetool6
# --upgrade would put the older one back without a word.
refuse_downgrade() {
    local new package engine half newer
    new=$(this_version)
    if [ -z "$new" ]; then
        echo "error: no version found in CMakeLists.txt; is this the project folder?" >&2
        exit 1
    fi
    package=$(installed_package_version)
    engine=$(installed_engine_version)
    if [ -n "$package" ] && version_newer "$package" "$new"; then
        half="widget package"
        newer=$package
    elif [ -n "$engine" ] && version_newer "$engine" "$new"; then
        half="engine"
        newer=$engine
    else
        return 0
    fi
    echo "error: the installed $half is $newer, newer than this copy ($new)." >&2
    echo "       Get the newer version first: run git pull here, or download the" >&2
    echo "       project again from GitHub. If that does not bring $newer yet, it has" >&2
    echo "       not been published there; run this script again once it has." >&2
    echo "       To go back to this older version on purpose, run ./uninstall.sh" >&2
    echo "       and then this script again, before restarting plasmashell." >&2
    echo "       Leave the widgets on the desktop: they keep their settings." >&2
    exit 1
}
