// SPDX-License-Identifier: GPL-2.0-or-later
//
// Terminal - a Plasma 6 widget that hosts a real terminal emulator.
//
// The emulator is a QQuickItem from the local.plasmaterminal.core QML module,
// so it lives in plasmashell's own scene graph: it moves, clips, scales and
// stacks exactly like any other widget, and it renders at the screen's device
// pixel ratio instead of being scaled up from a lower-resolution surface.

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    Plasmoid.icon: "utilities-terminal"

    Plasmoid.backgroundHints: {
        switch (cfg.backgroundMode) {
        case 1:
            return PlasmaCore.Types.TranslucentBackground;
        case 2:
            return PlasmaCore.Types.NoBackground;
        default:
            return PlasmaCore.Types.StandardBackground;
        }
    }

    // On the desktop the terminal itself is the widget. In a panel it collapses
    // to an icon that opens the terminal in a popup.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 8

    toolTipMainText: i18n("Terminal")
    toolTipSubText: Plasmoid.formFactor === PlasmaCore.Types.Planar ? "" : i18n("Click to open a terminal")

    // In a panel the terminal only becomes visible when the popup opens, so
    // that is when it should take the keyboard.
    onExpandedChanged: {
        if (expanded && fullRepresentationItem && fullRepresentationItem.focusTerminal) {
            Qt.callLater(fullRepresentationItem.focusTerminal);
        }
    }

    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactMouse.containsMouse || root.expanded
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: TerminalPane {}
}
