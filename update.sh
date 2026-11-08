#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Install the version in this folder over an existing installation. Run it
# after `git pull`, which downloads the new version; this script downloads
# nothing. It rebuilds, reinstalls both halves, shows what changed and
# restarts plasmashell so it loads them. Widget settings are not touched -
# they live in Plasma's own config.
#
#   ./update.sh              ask before restarting plasmashell
#   ./update.sh --restart    restart it without asking
#   ./update.sh --no-restart leave it running; restart it yourself later
set -euo pipefail

if [ $# -gt 1 ]; then
    echo "error: give at most one option (try --help)" >&2
    exit 1
fi

restart=ask
case "${1:-}" in
    "") ;;
    --restart) restart=yes ;;
    --no-restart) restart=no ;;
    -h | --help)
        sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "error: unknown option '$1' (try --help)" >&2
        exit 1
        ;;
esac

cd "$(dirname "$0")"

new_version=$(sed -n 's/^project(plasma-terminal-widget VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt)

# The widget package installed now says which version is being replaced.
installed=$(sed -n 's/.*"Version": *"\([0-9.]*\)".*/\1/p' \
    "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/io.github.cir0cuit.plasmaterminal/metadata.json" 2>/dev/null || true)
case "$installed" in
    *.*.*) ;;
    *.*) installed=$installed.0 ;; # 1.0 recorded only major.minor
    *) installed= ;;
esac

if [ -z "$installed" ]; then
    echo "Installing $new_version."
elif [ "$installed" = "$new_version" ]; then
    echo "$new_version is installed already. Rebuilding and reinstalling both halves"
    echo "anyway, so that an engine older than the widget catches up."
elif [ "$(printf '%s\n' "$installed" "$new_version" | sort -V | tail -n 1)" = "$installed" ]; then
    # Get New Widgets updated the widget package, and this folder is older.
    echo "error: the installed widget is $installed, newer than this folder ($new_version)." >&2
    echo "       Run git pull first, then ./update.sh again." >&2
    exit 1
else
    echo "Updating $installed -> $new_version."
fi
echo

# install.sh builds incrementally in build/, then upgrades the applet in
# place. PT_UPDATING keeps it from printing restart advice of its own.
PT_UPDATING=1 ./install.sh

# What is new since the installed version, next to the restart prompt rather
# than above the build output.
if [ -n "$installed" ] && [ "$installed" != "$new_version" ] && [ -f CHANGELOG.md ]; then
    echo
    awk -v v="$installed" '/^## / { if ($2 == v) exit; p = 1 } p' CHANGELOG.md
fi

plasma_running() {
    systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null
}

echo
if ! plasma_running; then
    echo "plasmashell is not running as a systemd user service, so it was not"
    echo "restarted. Log out and back in to load $new_version."
    exit 0
fi

if [ "$restart" = ask ]; then
    if [ -t 0 ]; then
        echo "Plasma keeps the old version loaded until plasmashell restarts."
        echo "Restarting ends the shells running inside terminal widgets."
        read -r -p "Restart plasmashell now? [Y/n] " answer || { echo; answer=n; }
        # Only Enter or yes restarts: a restart ends the terminal sessions.
        case "$answer" in
            "" | [yY]*) restart=yes ;;
            *) restart=no ;;
        esac
    else
        restart=no
    fi
fi

if [ "$restart" = yes ]; then
    systemctl --user restart plasma-plasmashell.service
    echo "plasmashell restarted - the widgets are now running $new_version."
else
    echo "Restart plasmashell when it suits you to load $new_version:"
    echo "    systemctl --user restart plasma-plasmashell.service"
fi
