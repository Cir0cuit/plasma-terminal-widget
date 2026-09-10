#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Remove both halves. Widget instances have to be removed from the desktop
# first, or plasmashell will show an empty placeholder until it is restarted.
set -uo pipefail

cd "$(dirname "$0")"

echo "Removing the applet..."
kpackagetool6 --type Plasma/Applet --remove io.github.cir0cuit.plasmaterminal || true

echo "Removing the QML module..."
if [ -f build/install_manifest.txt ]; then
    sudo xargs -a build/install_manifest.txt rm -f
else
    sudo rm -rf /usr/lib64/qt6/qml/io/github/cir0cuit/plasmaterminal/core
fi
sudo rmdir --ignore-fail-on-non-empty \
    /usr/lib64/qt6/qml/io/github/cir0cuit/plasmaterminal \
    /usr/lib64/qt6/qml/io/github/cir0cuit \
    /usr/lib64/qt6/qml/io/github /usr/lib64/qt6/qml/io 2>/dev/null || true

echo "Done. Restart plasmashell: systemctl --user restart plasma-plasmashell.service"
