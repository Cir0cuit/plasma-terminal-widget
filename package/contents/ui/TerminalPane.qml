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
import org.kde.notification

import io.github.cir0cuit.plasmaterminal.core as PT

import "version.js" as Version

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

    // An engine older than this package lacks the font style lookups, so
    // the terminal keeps the regular face until it is rebuilt.
    readonly property bool engineOutdated: Version.engineOutdated(PT.TerminalInfo)

    // The style is handed to the terminal as a weight and a slant, not by
    // name, so bold text can still pick the family's real Bold face. An empty
    // style means the regular face - or, while the family itself follows the
    // Konsole profile, whatever style that profile uses.
    readonly property var fontStyleInfo: {
        if (engineOutdated) {
            return {};
        }
        if (cfg.fontStyle.length > 0) {
            return PT.TerminalInfo.fontStyleInfo(fontFamily, cfg.fontStyle);
        }
        if (cfg.fontFamily.length === 0 && konsoleProfile.fontWeight !== undefined && konsoleProfile.fontFamily === fontFamily) {
            return {
                weight: konsoleProfile.fontWeight,
                italic: konsoleProfile.fontItalic === true
            };
        }
        return {};
    }
    readonly property int fontWeight: fontStyleInfo.weight !== undefined ? fontStyleInfo.weight : Font.Normal
    readonly property bool fontItalic: fontStyleInfo.italic === true

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
    // start() is synchronous: a shell that cannot be started never emits
    // started() or finished(), so the result is checked right after it.
    property bool startFailed: false
    // Set once the user asks for a shell, so a recreated terminal starts even
    // with "Start on load" off.
    property bool startRequested: false

    // The size hints live on the Loader in main.qml: that is the item the
    // containment lays out, and this one only fills it.

    // ------------------------------------------------------------------
    // helpers

    // Shell-style words: quotes may appear anywhere in a word, a backslash
    // escapes outside single quotes, and an unmatched quote is kept as is.
    function parseArguments(text) {
        const out = [];
        const re = /(?:'[^']*'|"(?:\\.|[^"\\])*"|\\.|\S)+/g;
        const part = /'([^']*)'|"((?:\\.|[^"\\])*)"|\\(.)/g;
        let m;
        while ((m = re.exec(text)) !== null) {
            out.push(m[0].replace(part, (s, sq, dq, esc) => sq !== undefined ? sq : dq !== undefined ? dq.replace(/\\([\\"$`])/g, "$1") : esc));
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
        pane.startRequested = true;
        pane.sessionEnded = false;
        pane.startFailed = false;
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

    // "Terminal bell: Notification". Plasma's own event, so nothing extra has
    // to be installed for it; one object per bell, gone once it closes.
    Component {
        id: bellNotification

        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            iconName: "utilities-terminal"
            title: pane.titleText
            text: i18n("The terminal rang its bell")
            onClosed: destroy()
        }
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
                active: pane.sessionEnded || pane.startFailed || (!cfg.autoStart && pane.session !== null && !pane.session.running && !pane.sessionEnded)
                visible: active
                sourceComponent: PlasmaExtras.PlaceholderMessage {
                    iconName: "utilities-terminal"
                    text: {
                        if (pane.startFailed) {
                            return i18n("Could not start %1 in %2", pane.session.shellProgram, pane.session.initialWorkingDirectory);
                        }
                        return pane.sessionEnded ? i18n("The shell exited") : i18n("Terminal is not running");
                    }
                    helpfulAction: Kirigami.Action {
                        icon.name: "system-run"
                        text: pane.sessionEnded ? i18n("Start a new session") : i18n("Start")
                        onTriggered: pane.restartSession()
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
                font.weight: pane.fontWeight
                font.italic: pane.fontItalic
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

                    property double startedAt: 0
                    onStarted: startedAt = Date.now()
                    onFinished: {
                        // A program that exits at once would respawn forever;
                        // offer the restart button for it instead.
                        if (cfg.exitAction === 0 && Date.now() - startedAt > 3000) {
                            restartTimer.restart();
                        } else if (cfg.exitAction !== 2) {
                            pane.sessionEnded = true;
                        }
                    }
                }

                onNotifyBell: bellNotification.createObject(pane).sendEvent()

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
                    if (cfg.autoStart || pane.startRequested) {
                        shellSession.start();
                        pane.startFailed = !shellSession.running;
                        if (!pane.startFailed && cfg.startupCommand.length > 0) {
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
