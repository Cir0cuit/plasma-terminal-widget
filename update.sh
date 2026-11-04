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

if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
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
    echo "error: could not fast-forward this checkout to the published branch." >&2
    echo "       If you committed your own changes, rebase them (git pull --rebase)" >&2
    echo "       and run ./update.sh again." >&2
    exit 1
fi

new_version=$(version)
if [ "$(git rev-parse HEAD)" = "$old_head" ]; then
    echo "Already up to date ($new_version) - reinstalling it anyway, in case one"
    echo "half of the widget was updated without the other."
else
    echo "Updating $old_version -> $new_version."
    if [ -f CHANGELOG.md ]; then
        echo "What changed: CHANGELOG.md"
    fi
fi
echo

# install.sh builds incrementally in build/ and re-runs CMake by itself when
# the build files changed, then upgrades the applet in place.
./install.sh

plasma_running() {
    systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null
}

echo
if ! plasma_running; then
    echo "plasmashell is not running as a user service here; the new version"
    echo "loads the next time Plasma starts."
    exit 0
fi

if [ "$restart" = ask ]; then
    if [ -t 0 ]; then
        echo "Plasma keeps the old version loaded until plasmashell restarts."
        echo "Restarting ends the shells running inside terminal widgets."
        read -r -p "Restart plasmashell now? [Y/n] " answer
        case "$answer" in
            [nN]*) restart=no ;;
            *) restart=yes ;;
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
