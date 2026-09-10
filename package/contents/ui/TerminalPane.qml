// SPDX-License-Identifier: GPL-2.0-or-later
//
// The full representation: an optional header strip, the terminal itself and
// a scrollbar for the scrollback buffer.

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import local.plasmaterminal.core as PT

Item {
    id: pane

    readonly property var cfg: Plasmoid.configuration

    // Empty font / colour scheme settings mean "look like the terminal the
    // user already has", i.e. their default Konsole profile.
    readonly property var konsoleProfile: PT.TerminalInfo.konsoleProfile()
    readonly property var availableSchemes: PT.TerminalInfo.colorSchemes()

    readonly property string fontFamily: {
        if (cfg.fontFamily.length > 0) {
            return cfg.fontFamily;
        }
        if (konsoleProfile.fontFamily !== undefined && PT.TerminalInfo.hasFamily(konsoleProfile.fontFamily)) {
            return konsoleProfile.fontFamily;
        }
        return "Monospace";
    }

    readonly property string colorScheme: {
        if (cfg.colorScheme.length > 0 && availableSchemes.indexOf(cfg.colorScheme) >= 0) {
            return cfg.colorScheme;
        }
        if (konsoleProfile.colorScheme !== undefined && availableSchemes.indexOf(konsoleProfile.colorScheme) >= 0) {
            return konsoleProfile.colorScheme;
        }
        return "BreezeModified";
    }

    // Transient zoom, deliberately not written back to the configuration.
    property int zoomDelta: 0
    readonly property int baseFontSize: {
        if (cfg.fontSize > 0) {
            return cfg.fontSize;
        }
        if (konsoleProfile.fontSize !== undefined) {
            return konsoleProfile.fontSize;
        }
        return 10;
    }
    readonly property int fontSize: Math.max(4, Math.min(96, baseFontSize + zoomDelta))

    // The live terminal, or null while it is being recreated.
    readonly property PT.TerminalView terminal: terminalLoader.item ? terminalLoader.item.view : null
    readonly property PT.TerminalSession session: terminalLoader.item ? terminalLoader.item.session : null

    property string titleText: i18n("Terminal")
    property bool sessionEnded: false

    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
    Layout.minimumHeight: Kirigami.Units.gridUnit * 6
    Layout.preferredWidth: Kirigami.Units.gridUnit * 32
    Layout.preferredHeight: Kirigami.Units.gridUnit * 18

    // ------------------------------------------------------------------
    // helpers

    function parseArguments(text) {
        const out = [];
        const re = /'([^']*)'|"([^"]*)"|(\S+)/g;
        let m;
        while ((m = re.exec(text)) !== null) {
            out.push(m[1] !== undefined ? m[1] : (m[2] !== undefined ? m[2] : m[3]));
        }
        return out;
    }

    function expandPath(path) {
        const home = PT.TerminalInfo.homeDirectory();
        if (path.length === 0) {
            return home;
        }
        if (path === "~") {
            return home;
        }
        if (path.startsWith("~/")) {
            return home + path.substring(1);
        }
        if (path.startsWith("$HOME")) {
            return home + path.substring(5);
        }
        return path;
    }

    function parseEnvironment(text) {
        const out = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length > 0 && line.indexOf("=") > 0 && !line.startsWith("#")) {
                out.push(line);
            }
        }
        return out;
    }

    function shellQuote(text) {
        return "'" + text.replace(/'/g, "'\\''") + "'";
    }

    function restartSession() {
        pane.sessionEnded = false;
        terminalLoader.active = false;
        terminalLoader.active = true;
    }

    function focusTerminal() {
        if (pane.terminal) {
            pane.terminal.forceActiveFocus();
        }
    }

    function openInKonsole() {
        let dir = pane.session ? pane.session.workingDirectory() : "";
        if (!dir || dir.length === 0) {
            dir = expandPath(cfg.workingDirectory);
        }
        executable.exec("konsole --workdir " + shellQuote(dir));
    }

    function updateTitle() {
        if (!pane.session) {
            return;
        }
        const process = pane.session.foregroundProcess();
        const dir = pane.session.workingDirectory();
        const home = PT.TerminalInfo.homeDirectory();
        let shortDir = dir;
        if (dir === home) {
            shortDir = "~";
        } else if (dir.startsWith(home + "/")) {
            shortDir = "~" + dir.substring(home.length);
        }
        if (process.length > 0 && shortDir.length > 0) {
            pane.titleText = process + " — " + shortDir;
        } else if (shortDir.length > 0) {
            pane.titleText = shortDir;
        } else {
            pane.titleText = i18n("Terminal");
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
        function exec(command) {
            if (command) {
                connectSource(command);
            }
        }
    }

    Timer {
        id: titleTimer
        interval: 2000
        repeat: true
        running: cfg.showHeader && pane.session !== null && pane.session.running
        triggeredOnStart: true
        onTriggered: pane.updateTitle()
    }

    // A session that ends must not tear its own item down from inside its
    // finished() handler, so the restart is deferred by one event loop pass.
    Timer {
        id: restartTimer
        interval: 60
        repeat: false
        onTriggered: pane.restartSession()
    }

    // Auto-hide state for the scrollbar: it appears while the pointer is over
    // the widget and for a moment after the view scrolls, so it is visible
    // exactly when it is useful.
    property bool scrollBarActive: false

    Timer {
        id: scrollBarFade
        interval: 1500
        repeat: false
        onTriggered: pane.scrollBarActive = false
    }

    function flashScrollBar() {
        pane.scrollBarActive = true;
        scrollBarFade.restart();
    }

    MouseArea {
        id: paneHover
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        z: -1
    }

    // ------------------------------------------------------------------
    // layout

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Loader {
            Layout.fillWidth: true
            active: cfg.showHeader
            visible: active
            sourceComponent: headerComponent
        }

        Item {
            id: terminalHost
            Layout.fillWidth: true
            Layout.fillHeight: true

            // The scrollbar lives in a reserved gutter rather than on top of
            // the text, so the last column is never covered.
            RowLayout {
                anchors.fill: parent
                spacing: 0

                Loader {
                    id: terminalLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: terminalComponent
                }

                Item {
                    id: scrollGutter
                    Layout.fillHeight: true
                    Layout.preferredWidth: cfg.showScrollBar ? verticalScrollBar.implicitWidth : 0
                    visible: cfg.showScrollBar
                }
            }

            PlasmaComponents.ScrollBar {
                id: verticalScrollBar

                property bool syncing: false

                // Computed on demand rather than bound: this is read from the
                // same signal handler that updates it, and binding evaluation
                // order against that handler is not guaranteed.
                function totalLines() {
                    return pane.terminal ? pane.terminal.lines + pane.terminal.scrollbarMaximum : 0;
                }

                parent: scrollGutter
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                orientation: Qt.Vertical
                interactive: true
                visible: cfg.showScrollBar && pane.terminal !== null && pane.terminal.scrollbarMaximum > 0
                opacity: !cfg.scrollBarAutoHide || paneHover.containsMouse || pane.scrollBarActive || pressed || hovered ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }

                function syncFromTerminal() {
                    const total = totalLines();
                    if (!pane.terminal || total <= 0) {
                        return;
                    }
                    if (cfg.scrollBarAutoHide && Math.abs(position * total - pane.terminal.scrollbarCurrentValue) > 0.5) {
                        pane.flashScrollBar();
                    }
                    syncing = true;
                    size = Math.min(1, pane.terminal.lines / total);
                    position = Math.max(0, Math.min(1 - size, pane.terminal.scrollbarCurrentValue / total));
                    syncing = false;
                }

                onPositionChanged: {
                    const total = totalLines();
                    if (syncing || !pane.terminal || total <= 0) {
                        return;
                    }
                    const line = Math.round(position * total);
                    if (line !== pane.terminal.scrollbarCurrentValue) {
                        pane.terminal.scrollToLine(line);
                    }
                }
            }

            Connections {
                target: pane.terminal
                function onScrollbarParamsChanged() {
                    verticalScrollBar.syncFromTerminal();
                }
                function onChangedContentSizeSignal(height, width) {
                    verticalScrollBar.syncFromTerminal();
                }
            }

            // Shown when the shell exited and the widget is configured to wait
            // for the user, and when auto-start is off.
            Loader {
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 20)
                active: pane.sessionEnded || (!cfg.autoStart && pane.session !== null && !pane.session.running && !pane.sessionEnded)
                visible: active
                sourceComponent: PlasmaExtras.PlaceholderMessage {
                    iconName: "utilities-terminal"
                    text: pane.sessionEnded ? i18n("The shell exited") : i18n("Terminal is not running")
                    helpfulAction: Kirigami.Action {
                        icon.name: "system-run"
                        text: pane.sessionEnded ? i18n("Start a new session") : i18n("Start")
                        onTriggered: {
                            if (pane.sessionEnded) {
                                pane.restartSession();
                            } else if (pane.session) {
                                pane.session.start();
                                pane.focusTerminal();
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // header

    Component {
        id: headerComponent

        PlasmaExtras.PlasmoidHeading {
            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    text: pane.titleText
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }

                PlasmaComponents.ToolButton {
                    icon.name: "edit-copy"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Copy")
                    enabled: pane.terminal !== null && pane.terminal.hasSelection
                    onClicked: {
                        pane.terminal.copy();
                        pane.focusTerminal();
                    }
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents.ToolButton {
                    icon.name: "edit-paste"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Paste")
                    enabled: pane.terminal !== null && !cfg.readOnly
                    onClicked: {
                        pane.terminal.paste();
                        pane.focusTerminal();
                    }
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents.ToolButton {
                    icon.name: "edit-clear-history"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Clear and reset")
                    enabled: pane.session !== null
                    onClicked: {
                        pane.session.clearAll();
                        pane.focusTerminal();
                    }
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Restart session")
                    onClicked: pane.restartSession()
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents.ToolButton {
                    icon.name: "window"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Open in Konsole")
                    onClicked: pane.openInKonsole()
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // terminal

    Component {
        id: terminalComponent

        Item {
            id: terminalItem

            property alias view: view
            property alias session: shellSession

            PT.TerminalView {
                id: view
                anchors.fill: parent
                focus: true

                font.family: pane.fontFamily
                font.pointSize: pane.fontSize
                lineSpacing: cfg.lineSpacing
                colorScheme: pane.colorScheme
                backgroundOpacity: cfg.terminalOpacity
                padding: cfg.padding
                cursorShape: cfg.cursorShape
                blinkingCursor: cfg.blinkingCursor
                fullCursorHeight: cfg.fullCursorHeight
                enableBold: cfg.boldIntense
                antialiasText: cfg.antialiasText
                bellMode: cfg.bellMode
                wordCharacters: cfg.wordCharacters
                middleClickPaste: cfg.middleClickPaste
                copyOnSelect: cfg.copyOnSelect
                builtInShortcuts: cfg.builtInShortcuts
                wheelZoom: cfg.wheelZoom
                focusOnClick: cfg.focusOnClick
                readOnly: cfg.readOnly

                session: PT.TerminalSession {
                    id: shellSession

                    shellProgram: cfg.shellProgram.length > 0 ? cfg.shellProgram : PT.TerminalInfo.defaultShell()
                    shellProgramArgs: pane.parseArguments(cfg.shellArgs)
                    initialWorkingDirectory: pane.expandPath(cfg.workingDirectory)
                    environment: pane.parseEnvironment(cfg.environmentVars)
                    scrollbackLines: cfg.unlimitedScrollback ? -1 : cfg.scrollbackLines
                    flowControl: cfg.flowControl

                    onFinished: {
                        if (cfg.exitAction === 0) {
                            restartTimer.restart();
                        } else if (cfg.exitAction === 1) {
                            pane.sessionEnded = true;
                        }
                    }
                }

                onZoomRequested: delta => pane.zoomDelta += delta
                onZoomResetRequested: pane.zoomDelta = 0
                onTextDropped: text => {
                    shellSession.sendText(text);
                    view.forceActiveFocus();
                }
                onContextMenuRequested: position => {
                    const mapped = view.mapToItem(pane, position.x, position.y);
                    contextMenu.x = mapped.x;
                    contextMenu.y = mapped.y;
                    contextMenu.open();
                }

                Component.onCompleted: {
                    if (cfg.autoStart) {
                        shellSession.start();
                        if (cfg.startupCommand.length > 0) {
                            startupTimer.start();
                        }
                    }
                    view.forceActiveFocus();
                    verticalScrollBar.syncFromTerminal();
                }

                Timer {
                    id: startupTimer
                    interval: 250
                    repeat: false
                    onTriggered: shellSession.sendText(cfg.startupCommand + "\n")
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // context menu

    PlasmaComponents.Menu {
        id: contextMenu

        onClosed: pane.focusTerminal()

        PlasmaComponents.MenuItem {
            text: i18n("Copy")
            icon.name: "edit-copy"
            enabled: pane.terminal !== null && pane.terminal.hasSelection
            onTriggered: pane.terminal.copy()
        }

        PlasmaComponents.MenuItem {
            text: i18n("Paste")
            icon.name: "edit-paste"
            enabled: pane.terminal !== null && !cfg.readOnly
            onTriggered: pane.terminal.paste()
        }

        PlasmaComponents.MenuSeparator {}

        PlasmaComponents.MenuItem {
            text: i18n("Clear Scrollback and Reset")
            icon.name: "edit-clear-history"
            enabled: pane.session !== null
            onTriggered: pane.session.clearAll()
        }

        PlasmaComponents.MenuItem {
            text: i18n("Restart Session")
            icon.name: "view-refresh"
            onTriggered: pane.restartSession()
        }

        PlasmaComponents.MenuItem {
            text: i18n("Open in Konsole")
            icon.name: "window"
            onTriggered: pane.openInKonsole()
        }

        PlasmaComponents.MenuSeparator {}

        PlasmaComponents.MenuItem {
            text: i18n("Configure Terminal…")
            icon.name: "configure"
            onTriggered: Plasmoid.internalAction("configure").trigger()
        }
    }

    // ------------------------------------------------------------------
    // actions offered in Plasma's own widget menu

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Copy")
            icon.name: "edit-copy"
            enabled: pane.terminal !== null && pane.terminal.hasSelection
            onTriggered: pane.terminal.copy()
        },
        PlasmaCore.Action {
            text: i18n("Paste")
            icon.name: "edit-paste"
            enabled: pane.terminal !== null && !cfg.readOnly
            onTriggered: pane.terminal.paste()
        },
        PlasmaCore.Action {
            text: i18n("Clear Scrollback and Reset")
            icon.name: "edit-clear-history"
            enabled: pane.session !== null
            onTriggered: pane.session.clearAll()
        },
        PlasmaCore.Action {
            text: i18n("Restart Session")
            icon.name: "view-refresh"
            onTriggered: pane.restartSession()
        },
        PlasmaCore.Action {
            text: i18n("Open in Konsole")
            icon.name: "window"
            onTriggered: pane.openInKonsole()
        }
    ]
}
