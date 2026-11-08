// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

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

    // The engine's TerminalInfo, or null when it is not installed.
    readonly property var engine: engineStatus.info

    readonly property var fontFamilies: engine ? engine.monospaceFamilies() : []
    readonly property var schemes: engine ? engine.colorSchemes() : []
    readonly property var konsoleProfile: engine ? engine.konsoleProfile() : ({})

    // The font style lookups only exist in engines from 1.1.0 on.
    readonly property bool engineHasFontStyles: engine !== null && typeof engine.fontStyleInfo === "function"

    // Engines before 1.1.0 know a font installed from two foundries only as
    // "Name [Foundry]", so the bare name is also looked up in Qt's own list.
    function familyInstalled(family) {
        return (engine !== null && engine.hasFamily(family)) || Qt.fontFamilies().some(f => f === family || f.startsWith(family + " ["));
    }

    readonly property bool matchKonsoleFont: cfg_fontFamily.length === 0 && cfg_fontSize === 0 && cfg_fontStyle.length === 0
    readonly property string konsoleFontSummary: {
        const family = konsoleProfile.fontFamily !== undefined ? konsoleProfile.fontFamily : i18n("Monospace");
        const size = konsoleProfile.fontSize !== undefined ? konsoleProfile.fontSize : 10;
        if (konsoleProfile.fontFamily !== undefined && !familyInstalled(family)) {
            return i18n("%1 is not installed, using Monospace, %2 pt", family, size);
        }
        const style = konsoleProfile.fontStyle;
        if (engineHasFontStyles && style !== undefined && style !== engine.regularFontStyle(family)) {
            return i18n("%1 %2, %3 pt", family, style, size);
        }
        return i18n("%1, %2 pt", family, size);
    }

    // What the pickers show: the configured font, or the Konsole profile's
    // while the widget follows it.
    readonly property string effectiveFontFamily: {
        if (cfg_fontFamily.length > 0 && familyInstalled(cfg_fontFamily)) {
            return cfg_fontFamily;
        }
        if (konsoleProfile.fontFamily !== undefined && familyInstalled(konsoleProfile.fontFamily)) {
            return konsoleProfile.fontFamily;
        }
        return "Monospace";
    }
    // List the font in use and the Konsole profile's even when the monospace
    // list leaves them out.
    readonly property var familyChoices: {
        const extra = [effectiveFontFamily];
        if (konsoleProfile.fontFamily !== undefined && familyInstalled(konsoleProfile.fontFamily)) {
            extra.push(konsoleProfile.fontFamily);
        }
        return extra.filter((f, i) => extra.indexOf(f) === i && fontFamilies.indexOf(f) < 0).concat(fontFamilies);
    }
    readonly property var fontStyles: engineHasFontStyles ? engine.fontStyles(effectiveFontFamily) : []
    readonly property string effectiveFontStyle: {
        if (!engineHasFontStyles) {
            return "";
        }
        if (cfg_fontStyle.length > 0 && fontStyles.indexOf(cfg_fontStyle) >= 0) {
            return cfg_fontStyle;
        }
        if (cfg_fontFamily.length === 0 && konsoleProfile.fontStyle !== undefined && fontStyles.indexOf(konsoleProfile.fontStyle) >= 0) {
            return konsoleProfile.fontStyle;
        }
        return engine.regularFontStyle(effectiveFontFamily);
    }
    readonly property var effectiveFontStyleInfo: !engineHasFontStyles || effectiveFontStyle.length === 0 ? {} : engine.fontStyleInfo(effectiveFontFamily, effectiveFontStyle)
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

        EngineStatus {
            id: engineStatus
            Layout.fillWidth: true
            outdatedNotes: [
                {
                    version: "1.1.0",
                    text: i18n("Until it is rebuilt, font styles are unavailable, Antialias is one setting for all terminal widgets and takes effect only after a font change, Padding takes effect only after a resize, and the Family list still has symbol fonts and a separate entry for each weight but leaves out Noto Sans Mono. The blinking cursor still stops blinking from about the 40th column, and Cursor covers the full line height and Draw bold text in a bold font change only what is drawn afterwards.")
                }
            ]
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Font:")
                // The font and colour scheme pickers list what the engine finds.
                visible: page.engine !== null
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
                visible: page.engine !== null
                enabled: !page.matchKonsoleFont
                model: page.familyChoices
                currentIndex: Math.max(0, page.familyChoices.indexOf(page.effectiveFontFamily))
                onActivated: {
                    const family = page.familyChoices[currentIndex];
                    // Keep the style when the new family has one of that name
                    // (most have Regular, Bold, Italic); otherwise fall back to
                    // the new family's regular face.
                    if (page.cfg_fontStyle.length > 0 && (!page.engineHasFontStyles || page.engine.fontStyles(family).indexOf(page.cfg_fontStyle) < 0)) {
                        page.cfg_fontStyle = "";
                    }
                    page.cfg_fontFamily = family;
                }
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Style:")
                visible: page.engine !== null
                enabled: !page.matchKonsoleFont && page.fontStyles.length > 1
                model: page.engineHasFontStyles ? page.fontStyles : [i18n("Regular")]
                currentIndex: Math.max(0, page.fontStyles.indexOf(page.effectiveFontStyle))
                onActivated: page.cfg_fontStyle = page.fontStyles[currentIndex]
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            }

            QQC2.SpinBox {
                Kirigami.FormData.label: i18n("Size:")
                visible: page.engine !== null
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
                visible: page.engine !== null
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
                    readonly property var info: page.engine ? page.engine.colorSchemeInfo(page.effectiveScheme) : ({})
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                    Layout.preferredHeight: schemeCombo.height
                    // cornerRadius is new in KDE Frameworks 6.2.
                    radius: Kirigami.Units.cornerRadius !== undefined ? Kirigami.Units.cornerRadius : Kirigami.Units.smallSpacing
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
