// SPDX-License-Identifier: GPL-2.0-or-later
//
// Terminal - a Plasma 6 widget that hosts a real terminal emulator.
//
// The emulator is a QQuickItem from the io.github.cir0cuit.plasmaterminal.core QML module,
// so it lives in plasmashell's own scene graph: it moves, clips, scales and
// stacks exactly like any other widget, and it renders at the screen's device
// pixel ratio instead of being scaled up from a lower-resolution surface.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
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
    // that is when it should take the keyboard. On the desktop each shortcut
    // press flips `expanded`, so every change counts.
    onExpandedChanged: {
        if ((root.expanded || Plasmoid.formFactor === PlasmaCore.Types.Planar) && fullRepresentationItem && fullRepresentationItem.focusTerminal) {
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

    // The terminal item comes from a compiled QML module that has to sit on
    // Qt's own import path, which a widget archive cannot install by itself.
    // Loading the pane through a Loader keeps that failure legible: with the
    // module missing the widget says how to install it, instead of taking the
    // whole plasmoid down with Plasma's generic "error loading QML file" box.
    fullRepresentation: Loader {
        id: paneLoader

        // Compiled here rather than by the Loader, so the error can be read:
        // a missing engine is not the only way the pane can fail to load.
        readonly property Component paneComponent: Qt.createComponent(Qt.resolvedUrl("TerminalPane.qml"), Component.PreferSynchronous, paneLoader)
        readonly property string paneError: paneComponent.status === Component.Error ? paneComponent.errorString() : ""
        readonly property bool engineMissing: paneError.indexOf("io.github.cir0cuit.plasmaterminal.core") >= 0

        sourceComponent: paneComponent.status === Component.Ready ? paneComponent : null

        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: Kirigami.Units.gridUnit * 32
        Layout.preferredHeight: Kirigami.Units.gridUnit * 18

        function focusTerminal() {
            if (item && item.focusTerminal) {
                item.focusTerminal();
            }
        }

        Component.onCompleted: {
            if (paneError.length > 0 && !engineMissing) {
                console.warn(paneError);
            }
        }

        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 2
            visible: paneLoader.engineMissing

            iconName: "utilities-terminal"
            text: i18n("Terminal engine not installed")
            // Plasma keeps a failed import until it restarts, so a widget
            // still says this after the engine has been installed. The
            // settings pages do not need the last sentence: each settings
            // dialog loads the engine afresh.
            explanation: i18n("The terminal is drawn by a compiled QML module that has to be built and installed system-wide; a widget package cannot do that on its own. The project page on GitHub has the commands: install the build dependencies for your distribution, build and install, then restart Plasma.") + " " + i18n("If you have installed it already, restarting Plasma is enough.")

            helpfulAction: QQC2.Action {
                icon.name: "internet-services"
                text: i18n("Open the project page")
                onTriggered: Qt.openUrlExternally("https://github.com/Cir0cuit/plasma-terminal-widget#build-and-install")
            }
        }

        // For example a file that an update added a moment ago: Plasma does
        // not see new files in a widget's folder until it restarts.
        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 2
            visible: paneLoader.paneError.length > 0 && !paneLoader.engineMissing

            iconName: "utilities-terminal"
            text: i18n("The terminal could not be loaded")
            // The first error, without the folder each file name starts with.
            explanation: i18n("If the widget was updated a moment ago, restart Plasma.") + "\n\n" + paneLoader.paneError.split("\n")[0].replace(/file:\/\/\S*\//g, "")
        }
    }
}
