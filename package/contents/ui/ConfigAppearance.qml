// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

import io.github.cir0cuit.plasmaterminal.core as PT

import "version.js" as Version

KCM.SimpleKCM {
    id: page

    property string cfg_fontFamily
    property string cfg_fontStyle
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

    // The font style lookups only exist in engines from 1.1.0 on.
    readonly property bool engineOutdated: Version.engineOutdated(PT.TerminalInfo)

    readonly property bool matchKonsoleFont: cfg_fontFamily.length === 0 && cfg_fontSize === 0 && cfg_fontStyle.length === 0
    readonly property string konsoleFontSummary: {
        const family = konsoleProfile.fontFamily !== undefined ? konsoleProfile.fontFamily : i18n("Monospace");
        const size = konsoleProfile.fontSize !== undefined ? konsoleProfile.fontSize : 10;
        if (konsoleProfile.fontFamily !== undefined && !PT.TerminalInfo.hasFamily(family)) {
            return i18n("%1 is not installed, using Monospace, %2 pt", family, size);
        }
        const style = konsoleProfile.fontStyle;
        if (!engineOutdated && style !== undefined && style !== PT.TerminalInfo.regularFontStyle(family)) {
            return i18n("%1 %2, %3 pt", family, style, size);
        }
        return i18n("%1, %2 pt", family, size);
    }

    // What the pickers show: the configured font, or the Konsole profile's
    // while the widget follows it.
    readonly property string effectiveFontFamily: {
        if (cfg_fontFamily.length > 0 && PT.TerminalInfo.hasFamily(cfg_fontFamily)) {
            return cfg_fontFamily;
        }
        if (konsoleProfile.fontFamily !== undefined && PT.TerminalInfo.hasFamily(konsoleProfile.fontFamily)) {
            return konsoleProfile.fontFamily;
        }
        return "Monospace";
    }
    // List the font in use and the Konsole profile's even when the monospace
    // list leaves them out.
    readonly property var familyChoices: {
        const extra = [effectiveFontFamily];
        if (konsoleProfile.fontFamily !== undefined && PT.TerminalInfo.hasFamily(konsoleProfile.fontFamily)) {
            extra.push(konsoleProfile.fontFamily);
        }
        return extra.filter((f, i) => extra.indexOf(f) === i && fontFamilies.indexOf(f) < 0).concat(fontFamilies);
    }
    readonly property var fontStyles: engineOutdated ? [] : PT.TerminalInfo.fontStyles(effectiveFontFamily)
    readonly property string effectiveFontStyle: {
        if (engineOutdated) {
            return "";
        }
        if (cfg_fontStyle.length > 0 && fontStyles.indexOf(cfg_fontStyle) >= 0) {
            return cfg_fontStyle;
        }
        if (cfg_fontFamily.length === 0 && konsoleProfile.fontStyle !== undefined && fontStyles.indexOf(konsoleProfile.fontStyle) >= 0) {
            return konsoleProfile.fontStyle;
        }
        return PT.TerminalInfo.regularFontStyle(effectiveFontFamily);
    }
    readonly property var effectiveFontStyleInfo: engineOutdated || effectiveFontStyle.length === 0 ? {} : PT.TerminalInfo.fontStyleInfo(effectiveFontFamily, effectiveFontStyle)
    readonly property string effectiveScheme: {
        if (cfg_colorScheme.length > 0 && schemes.indexOf(cfg_colorScheme) >= 0) {
            return cfg_colorScheme;
        }
        if (konsoleProfile.colorScheme !== undefined && schemes.indexOf(konsoleProfile.colorScheme) >= 0) {
            return konsoleProfile.colorScheme;
        }
        return "BreezeModified";
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.engineOutdated
            type: Kirigami.MessageType.Warning
            text: i18n("The terminal engine on this system is version %1, older than this widget, which needs %2. Font styles and the fixes made in the engine stay unavailable until it is rebuilt: in your copy of the project, run git pull, then ./update.sh. If you have just done that, restart Plasma.", Version.installedEngine(PT.TerminalInfo), Version.requiredEngine)
            actions: [
                Kirigami.Action {
                    icon.name: "internet-services"
                    text: i18n("How to update")
                    onTriggered: Qt.openUrlExternally("https://github.com/Cir0cuit/plasma-terminal-widget#updating")
                }
            ]
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Font:")
                text: i18n("Match my Konsole profile (%1)", page.konsoleFontSummary)
                checked: page.matchKonsoleFont
                onToggled: {
                    if (checked) {
                        page.cfg_fontFamily = "";
                        page.cfg_fontStyle = "";
                        page.cfg_fontSize = 0;
                    } else {
                        // Start from exactly what was being shown.
                        const style = page.effectiveFontStyle;
                        page.cfg_fontFamily = page.effectiveFontFamily;
                        page.cfg_fontStyle = style;
                        page.cfg_fontSize = page.konsoleProfile.fontSize !== undefined ? page.konsoleProfile.fontSize : 10;
                    }
                }
            }

            QQC2.ComboBox {
                id: fontCombo
                Kirigami.FormData.label: i18n("Family:")
                enabled: !page.matchKonsoleFont
                model: page.familyChoices
                currentIndex: Math.max(0, page.familyChoices.indexOf(page.effectiveFontFamily))
                onActivated: {
                    const family = page.familyChoices[currentIndex];
                    // Keep the style when the new family has one of that name
                    // (most have Regular, Bold, Italic); otherwise fall back to
                    // the new family's regular face.
                    if (page.cfg_fontStyle.length > 0 && (page.engineOutdated || PT.TerminalInfo.fontStyles(family).indexOf(page.cfg_fontStyle) < 0)) {
                        page.cfg_fontStyle = "";
                    }
                    page.cfg_fontFamily = family;
                }
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Style:")
                enabled: !page.matchKonsoleFont && page.fontStyles.length > 1
                model: page.engineOutdated ? [i18n("Regular")] : page.fontStyles
                currentIndex: Math.max(0, page.fontStyles.indexOf(page.effectiveFontStyle))
                onActivated: page.cfg_fontStyle = page.fontStyles[currentIndex]
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            }

            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Size:")
                enabled: !page.matchKonsoleFont
                from: 4
                to: 72
                value: page.cfg_fontSize > 0 ? page.cfg_fontSize : (page.konsoleProfile.fontSize !== undefined ? page.konsoleProfile.fontSize : 10)
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
                        font.family: page.effectiveFontFamily
                        font.weight: page.effectiveFontStyleInfo.weight !== undefined ? page.effectiveFontStyleInfo.weight : Font.Normal
                        font.italic: page.effectiveFontStyleInfo.italic === true
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
                text: i18n("Draw bold text in a bold font")
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
}
