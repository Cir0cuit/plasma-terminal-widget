#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build (if needed) and install both halves of the widget.
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d build ]; then
    cmake -B build -S . -DCMAKE_BUILD_TYPE=RelWithDebInfo
fi
cmake --build build -j"$(nproc)"

echo "Installing the QML module (needs root: it must land on Qt's import path)..."
sudo cmake --install build

echo "Installing the applet for $USER..."
if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q '^local\.plasmaterminal$'; then
    kpackagetool6 --type Plasma/Applet --upgrade package
else
    kpackagetool6 --type Plasma/Applet --install package
fi

echo
echo "Done. Restart plasmashell to pick up QML changes:"
echo "    systemctl --user restart plasma-plasmashell.service"
echo "Then add it from the desktop context menu: Add Widgets... -> Terminal"
