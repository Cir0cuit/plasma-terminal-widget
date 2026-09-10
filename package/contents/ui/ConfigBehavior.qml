// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property bool cfg_middleClickPaste
    property bool cfg_copyOnSelect
    property bool cfg_builtInShortcuts
    property bool cfg_wheelZoom
    property bool cfg_focusOnClick
    property bool cfg_readOnly
    property int cfg_bellMode
    property string cfg_wordCharacters
    property int cfg_exitAction

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Mouse:")
            text: i18n("Focus the terminal when it is clicked")
            checked: page.cfg_focusOnClick
            onToggled: page.cfg_focusOnClick = checked
        }

        QQC2.CheckBox {
            text: i18n("Copy the selection to the clipboard immediately")
            checked: page.cfg_copyOnSelect
            onToggled: page.cfg_copyOnSelect = checked
        }

        QQC2.CheckBox {
            text: i18n("Paste the selection on middle click")
            checked: page.cfg_middleClickPaste
            onToggled: page.cfg_middleClickPaste = checked
        }

        QQC2.CheckBox {
            text: i18n("Ctrl+wheel changes the font size")
            checked: page.cfg_wheelZoom
            onToggled: page.cfg_wheelZoom = checked
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Word characters:")
            text: page.cfg_wordCharacters
            onTextChanged: page.cfg_wordCharacters = text
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        }

        QQC2.Label {
            text: i18n("Counted as part of a word when double-clicking.")
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Keyboard:")
            text: i18n("Ctrl+Shift+C and Ctrl+Shift+V copy and paste")
            checked: page.cfg_builtInShortcuts
            onToggled: page.cfg_builtInShortcuts = checked
        }

        QQC2.CheckBox {
            text: i18n("Read-only: ignore all keyboard input")
            checked: page.cfg_readOnly
            onToggled: page.cfg_readOnly = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Terminal bell:")
            model: [i18n("System beep"), i18n("Notification"), i18n("Flash the terminal"), i18n("Ignore")]
            currentIndex: page.cfg_bellMode
            onActivated: page.cfg_bellMode = currentIndex
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("When the shell exits:")
            model: [i18n("Start a new session"), i18n("Offer a restart button"), i18n("Leave the last screen visible")]
            currentIndex: page.cfg_exitAction
            onActivated: page.cfg_exitAction = currentIndex
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        }
    }
}
