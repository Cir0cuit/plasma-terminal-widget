// SPDX-License-Identifier: GPL-2.0-or-later
//
// Standalone exercise for the terminal item, without plasmashell in the way.
// Run with:  qml -I <builddir>/qml test/harness.qml
//
// It starts a shell, feeds it commands through the same path a key press
// takes, resizes the view, and reports what it observed on stderr.

import QtQuick
import QtQuick.Window

import io.github.cir0cuit.plasmaterminal.core as PT

Window {
    id: win

    width: 900
    height: 620
    visible: true
    title: "Plasma Terminal harness"
    color: "#000000"

    property int step: 0

    PT.TerminalView {
        id: view

        anchors.fill: parent
        focus: true

        font.family: "MesloLGS Nerd Font"
        font.pointSize: 11
        colorScheme: "Dracula"
        padding: 8
        cursorShape: 0
        copyOnSelect: false
        middleClickPaste: false

        session: PT.TerminalSession {
            id: shellSession
            shellProgram: "/bin/bash"
            shellProgramArgs: ["--norc", "--noprofile", "-i"]
            initialWorkingDirectory: PT.TerminalInfo.homeDirectory()
            scrollbackLines: 5000

            onStarted: console.warn("HARNESS started pid=" + shellSession.processId)
            onFinished: console.warn("HARNESS finished")
        }

        onZoomRequested: delta => console.warn("HARNESS zoomRequested " + delta)
        onContextMenuRequested: position => console.warn("HARNESS contextMenu at " + position.x + "," + position.y)

        Component.onCompleted: {
            shellSession.start();
            view.forceActiveFocus();
        }
    }

    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            win.step++;
            switch (win.step) {
            case 1:
                shellSession.sendText("PS1='harness$ '\n");
                break;
            case 2:
                shellSession.sendText("echo TERM=$TERM COLORTERM=$COLORTERM; tput colors; stty size\n");
                break;
            case 3:
                // Typed one key at a time, through the key event path.
                "echo keypath".split("").forEach(function (c) {
                    view.sendKey(0, 0, c);
                });
                view.sendKey(Qt.Key_Return, 0, "\r");
                break;
            case 4:
                shellSession.sendText("for i in 1 2 3 4 5 6; do printf '\\033[4%dm  \\033[0m' $i; done; printf '\\033[38;2;255;120;0mtruecolor\\033[0m\\n'\n");
                break;
            case 5:
                shellSession.sendText("printf 'bold:\\033[1mBOLD\\033[0m dim:\\033[2mDIM\\033[0m ital:\\033[3mITAL\\033[0m under:\\033[4mUNDER\\033[0m rev:\\033[7mREV\\033[0m\\n'\n");
                break;
            case 6:
                win.width = 1100;
                win.height = 700;
                break;
            case 7:
                shellSession.sendText("stty size; echo lines=" + view.lines + " columns=" + view.columns + "\n");
                break;
            case 8:
                shellSession.sendText("seq 1 200 | tail -3\n");
                break;
            case 9:
                console.warn("HARNESS geometry lines=" + view.lines + " columns=" + view.columns
                             + " scrollbackMax=" + view.scrollbarMaximum
                             + " fontMetrics=" + view.fontMetrics.width + "x" + view.fontMetrics.height
                             + " dpr=" + Screen.devicePixelRatio);
                console.warn("HARNESS schemes=" + PT.TerminalInfo.colorSchemes().join(","));
                console.warn("HARNESS konsoleProfile=" + JSON.stringify(PT.TerminalInfo.konsoleProfile()));
                console.warn("HARNESS defaultShell=" + PT.TerminalInfo.defaultShell());
                break;
            case 10:
                shellSession.sendText("printf '\\033[38;5;%dm#\\033[0m' $(seq 16 231); echo\n");
                break;
            case 12:
                console.warn("HARNESS DONE");
                break;
            }
        }
    }
}
