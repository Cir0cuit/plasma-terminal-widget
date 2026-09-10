#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build (if needed) and install both halves of the widget.
set -euo pipefail

cd "$(dirname "$0")"

# Run a command as root. Already root: run it. Otherwise sudo, and if that is
# not installed (a minimal Debian or Arch may not have it), say so plainly
# rather than dying on "sudo: command not found".
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "error: this step needs root and sudo is not installed." >&2
        echo "       Run the script as root, or: su -c '$*'" >&2
        exit 1
    fi
}

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

if [ ! -d build ]; then
    cmake -B build -S . -DCMAKE_BUILD_TYPE=RelWithDebInfo
fi
cmake --build build -j"$(nproc)"

echo "Installing the QML module (needs root: it must land on Qt's import path)..."
as_root cmake --install build

echo "Installing the applet for $USER..."
if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q '^io\.github\.cir0cuit\.plasmaterminal$'; then
    kpackagetool6 --type Plasma/Applet --upgrade package
else
    kpackagetool6 --type Plasma/Applet --install package
fi

echo
echo "Done. Restart plasmashell to pick up QML changes:"
echo "    systemctl --user restart plasma-plasmashell.service"
echo "Then add it from the desktop context menu: Add Widgets... -> Terminal"
