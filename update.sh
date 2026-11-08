#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Update an existing installation from this git checkout: pull the new
# version, rebuild, reinstall both halves and restart plasmashell so it loads
# them. Widget settings are not touched - they live in Plasma's own config.
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
        sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "error: unknown option '$1' (try --help)" >&2
        exit 1
        ;;
esac

cd "$(dirname "$0")"

version() {
    sed -n 's/^project(plasma-terminal-widget VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt
}

# Look for .git here rather than asking git: a downloaded copy unpacked inside
# some other repository (a home directory kept in git) must not pull that one.
if ! command -v git >/dev/null 2>&1 || [ ! -e .git ]; then
    echo "error: this copy was not cloned with git, so there is nothing to pull." >&2
    echo "       Download the new version and run its ./install.sh instead; it" >&2
    echo "       upgrades an existing installation in place." >&2
    exit 1
fi

# A pull over local edits either fails half-way or silently merges them into
# what gets installed. Neither is what an update should do.
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: this checkout has local changes:" >&2
    git status --short >&2
    echo "       Commit or stash them (git stash), then run ./update.sh again." >&2
    exit 1
fi

old_version=$(version)
old_head=$(git rev-parse HEAD)

echo "Fetching the new version..."
if ! git pull --ff-only; then
    echo "error: git could not update this checkout; its message above says why." >&2
    echo "       If you committed changes of your own:  git pull --rebase" >&2
    echo "       If a release tag is checked out:       git switch main" >&2
    echo "       Then run ./update.sh again." >&2
    exit 1
fi

new_version=$(version)

# What changed is counted from the widget package installed now, not from the
# checkout: a 1.0 clone has already been pulled by hand, and a run after a
# failed install finds the checkout up to date.
installed=$(sed -n 's/.*"Version": *"\([0-9.]*\)".*/\1/p' \
    "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/io.github.cir0cuit.plasmaterminal/metadata.json" 2>/dev/null || true)
case "$installed" in
    *.*.*) ;;
    *.*) installed=$installed.0 ;; # 1.0 recorded only major.minor
    *) installed=$old_version ;;
esac

if [ "$(git rev-parse HEAD)" = "$old_head" ]; then
    echo "Already up to date ($new_version) - reinstalling it anyway, in case one"
    echo "half of the widget was updated without the other."
else
    echo "Updating $old_version -> $new_version."
fi
echo

# install.sh builds incrementally in build/, then upgrades the applet in
# place. PT_UPDATING keeps it from printing restart advice of its own.
PT_UPDATING=1 ./install.sh

# What is new since the installed version, next to the restart prompt rather
# than above the build output.
if [ "$installed" != "$new_version" ] && [ -f CHANGELOG.md ]; then
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
