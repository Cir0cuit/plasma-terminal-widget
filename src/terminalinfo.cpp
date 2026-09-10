// SPDX-License-Identifier: GPL-2.0-or-later

#include "terminalinfo.h"

#include "ColorScheme.h"

#include <QDir>
#include <QFileInfo>
#include <QFont>
#include <QFontDatabase>
#include <QSettings>
#include <QStandardPaths>

#include <pwd.h>
#include <unistd.h>

using namespace Konsole;

TerminalInfo::TerminalInfo(QObject *parent)
    : QObject(parent)
{
}

QStringList TerminalInfo::monospaceFamilies() const
{
    QStringList families;
    const QStringList all = QFontDatabase::families();
    for (const QString &family : all) {
        if (QFontDatabase::isPrivateFamily(family)) {
            continue;
        }
        if (QFontDatabase::isFixedPitch(family)) {
            families << family;
        }
    }
    families.removeDuplicates();
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
    return QFontDatabase::families().contains(family, Qt::CaseInsensitive);
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
