// SPDX-License-Identifier: GPL-2.0-or-later

#include "terminalinfo.h"

#include "ColorScheme.h"

#include <QDir>
#include <QFileInfo>
#include <QFont>
#include <QFontDatabase>
#include <QFontInfo>
#include <QFontMetrics>
#include <QSettings>
#include <QStandardPaths>

#include <algorithm>
#include <cstdlib>

#include <pwd.h>
#include <unistd.h>

using namespace Konsole;

namespace
{
struct StyleKey {
    QString name;
    int weight;
    bool slanted;
};

// What QFontDatabase knows about one style. The face is looked up through
// QFontDatabase::font() because that reports oblique faces (DejaVu's
// "Oblique") as slanted, where QFontDatabase::italic() only counts "Italic".
StyleKey styleKey(const QString &family, const QString &style)
{
    const QFont font = QFontDatabase::font(family, style, 10);
    return {style, font.weight(), font.style() != QFont::StyleNormal};
}

QList<StyleKey> styleKeys(const QString &family)
{
    QList<StyleKey> keys;
    QStringList seen;
    const QStringList styles = QFontDatabase::styles(family);
    for (const QString &style : styles) {
        if (style.isEmpty() || seen.contains(style)) {
            continue;
        }
        seen << style;
        const StyleKey key = styleKey(family, style);
        // The terminal is given a weight and slant, not a style name, so a
        // style those resolve away from (Noto Sans Mono's Condensed widths,
        // for one) cannot be drawn and is left out.
        QFont font(family);
        font.setWeight(QFont::Weight(key.weight));
        font.setItalic(key.slanted);
        const QString resolved = QFontInfo(font).styleName();
        if (resolved != style && styles.contains(resolved)) {
            continue;
        }
        keys << key;
    }
    std::stable_sort(keys.begin(), keys.end(), [](const StyleKey &a, const StyleKey &b) {
        if (a.slanted != b.slanted) {
            return !a.slanted;
        }
        return a.weight < b.weight;
    });
    return keys;
}
}

TerminalInfo::TerminalInfo(QObject *parent)
    : QObject(parent)
{
}

QString TerminalInfo::engineVersion() const
{
    return QStringLiteral(PT_ENGINE_VERSION);
}

QStringList TerminalInfo::monospaceFamilies() const
{
    QStringList families;
    const QStringList all = QFontDatabase::families();
    for (const QString &family : all) {
        // Without Latin it is a symbol font fontconfig calls monospace, such as Cursor or Noto Color Emoji.
        if (QFontDatabase::isPrivateFamily(family) || !QFontDatabase::writingSystems(family).contains(QFontDatabase::Latin)) {
            continue;
        }
        if (!QFontDatabase::isFixedPitch(family)) {
            // Fontconfig leaves some monospace fonts unflagged (Noto Sans Mono), so measure them.
            const QFontMetrics fm{QFont(family)};
            const int width = fm.horizontalAdvance(u'i');
            if (width <= 0 || width != fm.horizontalAdvance(u'W') || width != fm.horizontalAdvance(u'm')) {
                continue;
            }
        }
        families << family;
    }
    families.removeDuplicates();
    // Drop legacy per-style names ("Noto Sans Mono Light"); the Style picker offers that style of the family.
    const QStringList listed = families;
    families.removeIf([&listed](const QString &family) {
        return std::any_of(listed.begin(), listed.end(), [&family](const QString &base) {
            return family.startsWith(base + u' ') && QFontDatabase::styles(base).contains(family.mid(base.size() + 1));
        });
    });
    families.sort(Qt::CaseInsensitive);
    return families;
}

QStringList TerminalInfo::allFamilies() const
{
    QStringList families = QFontDatabase::families();
    families.removeDuplicates();
    families.sort(Qt::CaseInsensitive);
    return families;
}

bool TerminalInfo::hasFamily(const QString &family) const
{
    // A family installed from two foundries is listed as "Name [Foundry]".
    const QString withFoundry = family + QStringLiteral(" [");
    const QStringList all = QFontDatabase::families();
    return std::any_of(all.begin(), all.end(), [&](const QString &f) {
        return f.compare(family, Qt::CaseInsensitive) == 0 || f.startsWith(withFoundry, Qt::CaseInsensitive);
    });
}

QStringList TerminalInfo::fontStyles(const QString &family) const
{
    QStringList names;
    const QList<StyleKey> keys = styleKeys(family);
    for (const StyleKey &key : keys) {
        names << key.name;
    }
    return names;
}

QVariantMap TerminalInfo::fontStyleInfo(const QString &family, const QString &style) const
{
    QVariantMap info;
    if (style.isEmpty() || !QFontDatabase::styles(family).contains(style)) {
        return info;
    }
    const StyleKey key = styleKey(family, style);
    info[QStringLiteral("weight")] = key.weight;
    info[QStringLiteral("italic")] = key.slanted;
    return info;
}

QString TerminalInfo::regularFontStyle(const QString &family) const
{
    const QList<StyleKey> keys = styleKeys(family);
    const StyleKey *best = nullptr;
    for (const StyleKey &key : keys) {
        if (key.slanted) {
            continue;
        }
        if (!best || std::abs(key.weight - QFont::Normal) < std::abs(best->weight - QFont::Normal)) {
            best = &key;
        }
    }
    if (best) {
        return best->name;
    }
    return keys.isEmpty() ? QString() : keys.first().name;
}

QStringList TerminalInfo::colorSchemes() const
{
    QStringList names;
    const QList<ColorScheme *> schemes = ColorSchemeManager::instance()->allColorSchemes();
    names.reserve(schemes.size());
    for (const ColorScheme *scheme : schemes) {
        names << scheme->name();
    }
    names.removeDuplicates();
    names.sort(Qt::CaseInsensitive);
    return names;
}

QVariantMap TerminalInfo::colorSchemeInfo(const QString &name) const
{
    QVariantMap info;
    const ColorScheme *scheme = ColorSchemeManager::instance()->findColorScheme(name);
    if (!scheme) {
        return info;
    }
    info[QStringLiteral("name")] = scheme->name();
    info[QStringLiteral("description")] = scheme->description();
    info[QStringLiteral("background")] = scheme->backgroundColor();
    info[QStringLiteral("foreground")] = scheme->foregroundColor();
    return info;
}

QString TerminalInfo::defaultShell() const
{
    const QString shell = qEnvironmentVariable("SHELL");
    if (!shell.isEmpty() && QFileInfo::exists(shell)) {
        return shell;
    }

    // plasmashell is not always started with a useful $SHELL, so fall back to
    // the login shell rather than to whatever bash happens to be installed.
    if (const struct passwd *pw = getpwuid(getuid())) {
        const QString loginShell = QString::fromLocal8Bit(pw->pw_shell);
        if (!loginShell.isEmpty() && QFileInfo::exists(loginShell)) {
            return loginShell;
        }
    }

    return QStringLiteral("/bin/bash");
}

QVariantMap TerminalInfo::konsoleProfile() const
{
    QVariantMap profile;

    const QString configHome = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    QSettings konsolerc(configHome + QStringLiteral("/konsolerc"), QSettings::IniFormat);
    QString profileName = konsolerc.value(QStringLiteral("Desktop Entry/DefaultProfile")).toString();
    if (profileName.isEmpty()) {
        profileName = QStringLiteral("Default.profile");
    } else if (!profileName.endsWith(QLatin1String(".profile"))) {
        profileName += QStringLiteral(".profile");
    }

    const QString dataHome = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    const QString path = dataHome + QStringLiteral("/konsole/") + profileName;
    if (!QFileInfo::exists(path)) {
        return profile;
    }

    QSettings profileSettings(path, QSettings::IniFormat);
    profile[QStringLiteral("name")] = profileSettings.value(QStringLiteral("General/Name"), profileName).toString();

    // QSettings splits unquoted values containing commas into a list, which is
    // exactly what a serialised QFont looks like.
    const QVariant fontValue = profileSettings.value(QStringLiteral("Appearance/Font"));
    QString fontString;
    if (fontValue.metaType().id() == QMetaType::QStringList) {
        fontString = fontValue.toStringList().join(QLatin1Char(','));
    } else {
        fontString = fontValue.toString();
    }
    if (!fontString.isEmpty()) {
        QFont font;
        if (font.fromString(fontString)) {
            profile[QStringLiteral("fontFamily")] = font.family();
            if (font.pointSize() > 0) {
                profile[QStringLiteral("fontSize")] = font.pointSize();
            }
            // Konsole saves the style both as a weight and slant and, when one
            // was picked by name, as a style name. The name is only for
            // display; the weight and slant are what the terminal is given.
            QString styleName = font.styleName();
            if (!styleName.isEmpty() && fontStyles(font.family()).contains(styleName)) {
                const StyleKey key = styleKey(font.family(), styleName);
                profile[QStringLiteral("fontWeight")] = key.weight;
                profile[QStringLiteral("fontItalic")] = key.slanted;
            } else {
                // Older profiles carry only the weight and slant: name the
                // installed style that has exactly those, if there is one.
                styleName.clear();
                const bool slanted = font.style() != QFont::StyleNormal;
                const QList<StyleKey> keys = styleKeys(font.family());
                for (const StyleKey &key : keys) {
                    if (key.weight == font.weight() && key.slanted == slanted) {
                        styleName = key.name;
                        break;
                    }
                }
                profile[QStringLiteral("fontWeight")] = font.weight();
                profile[QStringLiteral("fontItalic")] = slanted;
            }
            if (!styleName.isEmpty()) {
                profile[QStringLiteral("fontStyle")] = styleName;
            }
        }
    }

    const QString scheme = profileSettings.value(QStringLiteral("Appearance/ColorScheme")).toString();
    if (!scheme.isEmpty()) {
        profile[QStringLiteral("colorScheme")] = scheme;
    }

    const QVariant lineSpacing = profileSettings.value(QStringLiteral("Appearance/LineSpacing"));
    if (lineSpacing.isValid()) {
        profile[QStringLiteral("lineSpacing")] = lineSpacing.toInt();
    }

    return profile;
}

QString TerminalInfo::homeDirectory() const
{
    return QDir::homePath();
}
