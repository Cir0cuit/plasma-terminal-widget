// SPDX-License-Identifier: GPL-2.0-or-later
//
// The notice at the top of a settings page when the terminal engine is not
// installed or is older than this package. It reaches the engine only through
// EngineInfo.qml, so the page around it still loads without one.

import QtQuick

import org.kde.kirigami as Kirigami

Kirigami.InlineMessage {
    id: status

    // What on this page works only once the engine is rebuilt, as a list of
    // { version, text }: the engine version that brings it, and sentences
    // that read correctly on their own. The notice shows the entries for
    // versions newer than the loaded engine, in the order given, so an engine
    // between two releases is told only what it lacks. List them oldest
    // first, and keep old entries: an engine that old can still be installed.
    property var outdatedNotes: []

    // The same for what waits for the rebuild outside the settings pages,
    // shown after the page's own entries.
    readonly property var commonNotes: [
        {
            version: "1.1.0",
            text: i18n("Other fixes, to how the terminal draws text and the cursor and how it handles input, wait for the rebuild as well.")
        }
    ]

    // TerminalInfo, or null without an engine.
    readonly property var info: engineLoader.item ? engineLoader.item.info : null
    readonly property bool outdated: engineLoader.item ? engineLoader.item.outdated : false
    readonly property bool missing: engineComponent.status === Component.Error

    // Compiled here rather than by the Loader, so that a missing engine is
    // shown on the page instead of being logged as an error.
    readonly property Component engineComponent: Qt.createComponent(Qt.resolvedUrl("EngineInfo.qml"), Component.PreferSynchronous, status)

    visible: missing || outdated
    type: missing ? Kirigami.MessageType.Error : Kirigami.MessageType.Warning
    text: {
        if (missing) {
            return i18n("Terminal engine not installed") + "\n" + i18n("The terminal is drawn by a compiled QML module that has to be built and installed system-wide; a widget package cannot do that on its own. The project page on GitHub has the commands: install the build dependencies for your distribution, build and install, then restart Plasma.");
        }
        if (outdated) {
            const engine = engineLoader.item;
            const notes = outdatedNotes.concat(commonNotes).filter(note => engine.lacks(note.version)).map(note => " " + note.text).join("");
            // The version is the one compiled into the plugin Plasma has
            // loaded. Plasma keeps that plugin until it restarts, so the
            // notice stays after update.sh has installed the new engine, and
            // its last line is for that case. The command gets a line of its
            // own. Within a sentence Qt can wrap it after the slash in
            // ./update.sh: <nobr> only keeps spaces from breaking, and a word
            // joiner would be copied along with the command.
            return i18n("The terminal engine Plasma has loaded is version %1, older than this widget, which needs %2.", engine.installedVersion, engine.requiredVersion) + notes + " " + i18n("To rebuild it, run this in your copy of the project, and restart Plasma when it has finished:") + "\ngit pull && ./update.sh\n" + i18n("If you have run it since Plasma last started, restarting Plasma is enough: Plasma keeps the engine it loaded at startup.");
        }
        return "";
    }
    actions: [
        Kirigami.Action {
            visible: status.missing
            icon.name: "internet-services"
            text: i18n("Open the project page")
            onTriggered: Qt.openUrlExternally("https://github.com/Cir0cuit/plasma-terminal-widget#build-and-install")
        },
        Kirigami.Action {
            visible: status.outdated
            icon.name: "internet-services"
            text: i18n("How to update")
            onTriggered: Qt.openUrlExternally("https://github.com/Cir0cuit/plasma-terminal-widget#updating")
        }
    ]

    Loader {
        id: engineLoader
        sourceComponent: status.engineComponent.status === Component.Ready ? status.engineComponent : null
    }
}
