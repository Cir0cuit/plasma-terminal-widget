// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

import io.github.cir0cuit.plasmaterminal.core as PT

KCM.SimpleKCM {
    id: page

    property string cfg_shellProgram
    property string cfg_shellArgs
    property string cfg_workingDirectory
    property string cfg_environmentVars
    property string cfg_startupCommand
    property int cfg_scrollbackLines
    property bool cfg_unlimitedScrollback
    property bool cfg_flowControl
    property bool cfg_autoStart

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Program:")
            text: page.cfg_shellProgram
            onTextChanged: page.cfg_shellProgram = text
            placeholderText: PT.TerminalInfo.defaultShell()
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        }

        QQC2.Label {
            text: i18n("Leave empty to use the login shell from $SHELL.")
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Arguments:")
            text: page.cfg_shellArgs
            onTextChanged: page.cfg_shellArgs = text
            placeholderText: i18n("e.g. -l")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Working directory:")
            text: page.cfg_workingDirectory
            onTextChanged: page.cfg_workingDirectory = text
            placeholderText: PT.TerminalInfo.homeDirectory()
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Run at startup:")
            text: page.cfg_startupCommand
            onTextChanged: page.cfg_startupCommand = text
            placeholderText: i18n("e.g. btop")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        }

        QQC2.CheckBox {
            text: i18n("Start the shell as soon as the widget loads")
            checked: page.cfg_autoStart
            onToggled: page.cfg_autoStart = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Scrollback:")
            text: i18n("Unlimited (kept in a temporary file)")
            checked: page.cfg_unlimitedScrollback
            onToggled: page.cfg_unlimitedScrollback = checked
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Lines:")
            from: 0
            to: 1000000
            stepSize: 1000
            enabled: !page.cfg_unlimitedScrollback
            value: page.cfg_scrollbackLines
            onValueModified: page.cfg_scrollbackLines = value
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Flow control:")
            text: i18n("Ctrl+S and Ctrl+Q suspend and resume output")
            checked: page.cfg_flowControl
            onToggled: page.cfg_flowControl = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Environment:")
            text: i18n("One NAME=value pair per line, added to the shell's environment.")
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        QQC2.ScrollView {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
            Layout.minimumHeight: Kirigami.Units.gridUnit * 7

            QQC2.TextArea {
                text: page.cfg_environmentVars
                onTextChanged: page.cfg_environmentVars = text
                wrapMode: TextEdit.NoWrap
                font.family: "monospace"
            }
        }
    }
}
