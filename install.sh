#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build (if needed) and install both halves of the widget.
set -euo pipefail
# A stricter umask would leave the build output, and the install manifest
# written as root, readable by their owner alone. sudo applies this umask
# too. The installed engine gets fixed modes in src/CMakeLists.txt.
umask 022

cd "$(dirname "$0")"
# shellcheck source=scripts/common.sh
. scripts/common.sh

refuse_root

# Never put this copy over a newer one: Get New Widgets may have installed a
# newer widget package, and kpackagetool6 --upgrade below does not compare
# versions.
refuse_downgrade

# Check the tools up front, so a missing package fails here with a useful
# message instead of somewhere in the middle of a CMake trace.
missing=()
command -v cmake >/dev/null 2>&1 || missing+=("cmake")
{ command -v c++ >/dev/null 2>&1 || command -v g++ >/dev/null 2>&1; } || missing+=("a C++ compiler")
command -v kpackagetool6 >/dev/null 2>&1 || missing+=("kpackagetool6")
if [ ${#missing[@]} -gt 0 ]; then
    echo "error: missing ${missing[*]}." >&2
    echo "       See the Dependencies section of README.md for your distribution." >&2
    exit 1
fi

# An earlier run with sudo (1.0 did not refuse one) left build/ to root, and
# cmake would stop halfway with "is not writable". The install manifest is
# always root's: cmake --install writes it as root.
if [ -d build ] && [ -n "$(find build -path build/install_manifest.txt -prune -o ! -user "$(id -u)" -print -quit)" ]; then
    echo "error: build/ has files that belong to root, from an earlier run with sudo." >&2
    echo "       Remove it, then run this again: sudo rm -rf $(pwd)/build" >&2
    exit 1
fi

# Configure every time: it is quick on an existing build/, and a first attempt
# that failed (a missing dependency) leaves a build/ with nothing to build.
# -Wno-dev hides warnings meant for the project's developers, not its users.
cmake -Wno-dev -B build -S . -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j"$(nproc)"

echo "Installing the QML module (needs root: it must land on Qt's import path)..."
as_root cmake --install build

echo "Installing the applet for $(id -un)..."
if package_listed; then
    kpackagetool6 --type Plasma/Applet --upgrade package
    fresh=
else
    kpackagetool6 --type Plasma/Applet --install package
    fresh=1
fi

# update.sh gives the advice itself, after the changelog, for a first install
# as well. A blank line here would double the one it prints first.
if [ -z "${PT_UPDATING:-}" ]; then
    echo
    if [ -n "$fresh" ]; then
        echo "Done. Restart plasmashell so it finds the new widget:"
        echo "    systemctl --user restart plasma-plasmashell.service"
        echo "Then add it from the desktop context menu: Add Widgets... -> Terminal"
    else
        echo "Done. Restart plasmashell to load the new version:"
        echo "    systemctl --user restart plasma-plasmashell.service"
    fi
fi
