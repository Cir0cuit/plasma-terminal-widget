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
# shellcheck source=scripts/common.sh
. scripts/common.sh

refuse_root

# Get New Widgets may have installed a newer widget package than this copy,
# and an older copy must not replace it.
refuse_downgrade

new_version=$(this_version)

# The two halves can be at different versions: Get New Widgets updates only
# the widget package, and only these scripts update the engine. The older of
# the two is the version being replaced.
package=$(installed_package_version)
engine=$(installed_engine_version)
oldest=$package
if [ -z "$oldest" ] || { [ -n "$engine" ] && version_newer "$oldest" "$engine"; }; then
    oldest=$engine
fi

if [ -z "$package" ] && [ -z "$engine" ]; then
    echo "Installing $new_version."
elif [ -z "$engine" ]; then
    echo "The widget package $package is installed, but no engine. Installing both halves of $new_version."
elif [ "$package" = "$new_version" ] && [ "$engine" = "$new_version" ]; then
    echo "$new_version is installed already. Rebuilding and reinstalling both halves anyway."
elif [ "$package" = "$new_version" ]; then
    echo "The widget package is $new_version already (updated from the KDE Store); the engine is $engine. Updating the engine to $new_version."
elif [ "$oldest" = "$new_version" ]; then
    # Only the engine is installed, and it is this version already.
    echo "Installing $new_version."
else
    echo "Updating $oldest -> $new_version."
fi
echo

# install.sh builds incrementally in build/, then installs or upgrades the
# applet. PT_UPDATING keeps it from printing restart advice of its own, on a
# first install too, so the advice below is the only one. bash runs it even
# if an unpacked download lost the executable bit.
PT_UPDATING=1 bash ./install.sh

# What is new since the older installed half, next to the restart prompt
# rather than above the build output. After Get New Widgets updated only the
# widget package, that is the engine's version, so the list still shows. The
# blank lines before the next heading are left out: the echo below adds one.
if [ -n "$oldest" ] && version_newer "$new_version" "$oldest" && [ -f CHANGELOG.md ]; then
    echo
    awk -v v="$oldest" '
        /^## / { if ($2 == v) exit; p = 1 }
        !p { next }
        /^$/ { blank++; next }
        { for (; blank > 0; blank--) print ""; print }
    ' CHANGELOG.md
fi

plasma_running() {
    systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null
}

# Without a widget package before this run there is no widget on the desktop
# yet: it has to be added once plasmashell has restarted.
add_widget_hint() { # <first word>
    if [ -z "$package" ]; then
        echo "$1 add the widget from the desktop context menu: Add Widgets... -> Terminal"
    fi
}

echo
if ! plasma_running; then
    echo "plasmashell is not running as a systemd user service, so it was not"
    echo "restarted. Log out and back in to load $new_version."
    add_widget_hint Then
    exit 0
fi

if [ "$restart" = ask ]; then
    if [ -t 0 ]; then
        if [ -z "$package" ]; then
            echo "Plasma finds the new widget only after plasmashell restarts."
        else
            echo "Plasma keeps the old version loaded until plasmashell restarts."
        fi
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
    if [ -z "$package" ]; then
        echo "plasmashell restarted."
    else
        echo "plasmashell restarted - the widgets are now running $new_version."
    fi
    add_widget_hint Now
else
    echo "Restart plasmashell when it suits you to load $new_version:"
    echo "    systemctl --user restart plasma-plasmashell.service"
    add_widget_hint Then
fi
