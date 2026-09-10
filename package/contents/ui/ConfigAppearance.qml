// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

import local.plasmaterminal.core as PT

KCM.SimpleKCM {
    id: page

    property string cfg_fontFamily
    property int cfg_fontSize
    property int cfg_lineSpacing
    property string cfg_colorScheme
    property real cfg_terminalOpacity
    property int cfg_backgroundMode
    property int cfg_padding
    property int cfg_cursorShape
    property bool cfg_blinkingCursor
    property bool cfg_fullCursorHeight
    property bool cfg_boldIntense
    property bool cfg_antialiasText
    property bool cfg_showHeader
    property bool cfg_showScrollBar
    property bool cfg_scrollBarAutoHide

    readonly property var fontFamilies: PT.TerminalInfo.monospaceFamilies()
    readonly property var schemes: PT.TerminalInfo.colorSchemes()
    readonly property var konsoleProfile: PT.TerminalInfo.konsoleProfile()

    readonly property bool matchKonsoleFont: cfg_fontFamily.length === 0 && cfg_fontSize === 0
    readonly property string konsoleFontSummary: {
        const family = konsoleProfile.fontFamily !== undefined ? konsoleProfile.fontFamily : i18n("Monospace");
        const size = konsoleProfile.fontSize !== undefined ? konsoleProfile.fontSize : 10;
        return i18n("%1, %2 pt", family, size);
    }
    readonly property string effectiveScheme: {
        if (cfg_colorScheme.length > 0) {
            return cfg_colorScheme;
        }
        if (konsoleProfile.colorScheme !== undefined && schemes.indexOf(konsoleProfile.colorScheme) >= 0) {
            return konsoleProfile.colorScheme;
        }
        return "BreezeModified";
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Font:")
            text: i18n("Match my Konsole profile (%1)", page.konsoleFontSummary)
            checked: page.matchKonsoleFont
            onToggled: {
                if (checked) {
                    page.cfg_fontFamily = "";
                    page.cfg_fontSize = 0;
                } else {
                    page.cfg_fontFamily = page.konsoleProfile.fontFamily !== undefined ? page.konsoleProfile.fontFamily : "Monospace";
                    page.cfg_fontSize = page.konsoleProfile.fontSize !== undefined ? page.konsoleProfile.fontSize : 10;
                }
            }
        }

        QQC2.ComboBox {
            id: fontCombo
            Kirigami.FormData.label: i18n("Family:")
            enabled: !page.matchKonsoleFont
            model: page.fontFamilies
            currentIndex: Math.max(0, page.fontFamilies.indexOf(page.cfg_fontFamily))
            onActivated: page.cfg_fontFamily = page.fontFamilies[currentIndex]
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Size:")
            enabled: !page.matchKonsoleFont
            from: 4
            to: 72
            value: page.cfg_fontSize > 0 ? page.cfg_fontSize : 10
            onValueModified: page.cfg_fontSize = value
            textFromValue: (value, locale) => i18np("%1 pt", "%1 pt", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Line spacing:")
            from: 0
            to: 24
            value: page.cfg_lineSpacing
            onValueModified: page.cfg_lineSpacing = value
            textFromValue: (value, locale) => i18np("%1 px", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Colour scheme:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.ComboBox {
                id: schemeCombo
                model: page.schemes
                currentIndex: Math.max(0, page.schemes.indexOf(page.effectiveScheme))
                onActivated: page.cfg_colorScheme = page.schemes[currentIndex]
                Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            }

            // Live preview of the scheme's background and foreground.
            Rectangle {
                readonly property var info: PT.TerminalInfo.colorSchemeInfo(page.effectiveScheme)
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                Layout.preferredHeight: schemeCombo.height
                radius: Kirigami.Units.cornerRadius
                border.width: 1
                border.color: Kirigami.Theme.disabledTextColor
                color: info.background !== undefined ? info.background : "transparent"

                QQC2.Label {
                    anchors.centerIn: parent
                    text: "Abc"
                    color: parent.info.foreground !== undefined ? parent.info.foreground : Kirigami.Theme.textColor
                    font.family: page.cfg_fontFamily.length > 0 ? page.cfg_fontFamily : "monospace"
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Widget background:")
            model: [i18n("Plasma widget background"), i18n("Translucent"), i18n("None")]
            currentIndex: page.cfg_backgroundMode
            onActivated: page.cfg_backgroundMode = currentIndex
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Terminal opacity:")

            QQC2.Slider {
                id: opacitySlider
                from: 0.1
                to: 1.0
                stepSize: 0.05
                value: page.cfg_terminalOpacity
                onMoved: page.cfg_terminalOpacity = value
                Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            }

            QQC2.Label {
                text: Math.round(opacitySlider.value * 100) + "%"
            }
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Padding:")
            from: 0
            to: 64
            value: page.cfg_padding
            onValueModified: page.cfg_padding = value
            textFromValue: (value, locale) => i18np("%1 px", "%1 px", value)
            valueFromText: text => parseInt(text)
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Cursor:")
            model: [i18n("Block"), i18n("Underline"), i18n("I-beam")]
            currentIndex: page.cfg_cursorShape
            onActivated: page.cfg_cursorShape = currentIndex
        }

        QQC2.CheckBox {
            text: i18n("Blinking cursor")
            checked: page.cfg_blinkingCursor
            onToggled: page.cfg_blinkingCursor = checked
        }

        QQC2.CheckBox {
            text: i18n("Cursor covers the full line height")
            checked: page.cfg_fullCursorHeight
            onToggled: page.cfg_fullCursorHeight = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Text:")
            text: i18n("Draw bold text in intense colours")
            checked: page.cfg_boldIntense
            onToggled: page.cfg_boldIntense = checked
        }

        QQC2.CheckBox {
            text: i18n("Antialias glyphs")
            checked: page.cfg_antialiasText
            onToggled: page.cfg_antialiasText = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Widget:")
            text: i18n("Show title and toolbar")
            checked: page.cfg_showHeader
            onToggled: page.cfg_showHeader = checked
        }

        QQC2.CheckBox {
            text: i18n("Show scrollbar")
            checked: page.cfg_showScrollBar
            onToggled: page.cfg_showScrollBar = checked
        }

        QQC2.CheckBox {
            text: i18n("Hide the scrollbar until the pointer is over the widget")
            enabled: page.cfg_showScrollBar
            checked: page.cfg_scrollBarAutoHide
            onToggled: page.cfg_scrollBarAutoHide = checked
        }
    }
}
