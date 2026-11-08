// SPDX-License-Identifier: GPL-2.0-or-later
//
// TerminalInfo - a QML singleton the configuration pages use to populate
// their pickers without having to instantiate a live terminal.

#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QStringList>
#include <QVariantMap>

class TerminalInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    /**
     * The version of this module, e.g. "1.1.0". The plasmoid compares it with
     * the version it was written against, so a widget package that is newer
     * than the installed module can say so instead of failing quietly.
     * Modules before 1.1.0 do not have this property at all.
     */
    Q_PROPERTY(QString engineVersion READ engineVersion CONSTANT)

public:
    explicit TerminalInfo(QObject *parent = nullptr);

    QString engineVersion() const;

    /**
     * Font families with fixed character width that cover Latin text, sorted,
     * deduplicated, without the legacy per-style names ("JetBrains Mono Light").
     */
    Q_INVOKABLE QStringList monospaceFamilies() const;
    /** Every installed font family. */
    Q_INVOKABLE QStringList allFamilies() const;
    /** True if @p family exists on this system. */
    Q_INVOKABLE bool hasFamily(const QString &family) const;

    /**
     * The styles @p family is installed in ("Light", "Regular", "Medium",
     * "Bold Italic", ...), upright before italic and lightest first. Styles
     * the terminal cannot draw, such as condensed widths, are left out.
     */
    Q_INVOKABLE QStringList fontStyles(const QString &family) const;
    /**
     * {"weight", "italic"} for @p style of @p family, or an empty map if the
     * family has no such style. The terminal is given the weight and slant
     * rather than the style name: a QFont with a style name set ignores its
     * weight when matching, so bold text would stop finding the Bold face.
     */
    Q_INVOKABLE QVariantMap fontStyleInfo(const QString &family, const QString &style) const;
    /** The upright style of @p family closest to a normal weight. */
    Q_INVOKABLE QString regularFontStyle(const QString &family) const;

    /**
     * Colour schemes found in the built-in set, ~/.local/share/konsole and
     * /usr/share/konsole - i.e. Konsole's own schemes are picked up too.
     */
    Q_INVOKABLE QStringList colorSchemes() const;
    /** {"name", "description", "background", "foreground"} for @p name. */
    Q_INVOKABLE QVariantMap colorSchemeInfo(const QString &name) const;

    /** $SHELL, then the login shell from /etc/passwd, then /bin/bash. */
    Q_INVOKABLE QString defaultShell() const;

    /**
     * The user's default Konsole profile, so the widget can look like the
     * terminal they already use. Keys: name, fontFamily, fontSize,
     * fontStyle, fontWeight, fontItalic, colorScheme, lineSpacing. Missing
     * entries are simply absent.
     */
    Q_INVOKABLE QVariantMap konsoleProfile() const;
    /** The user's home directory. */
    Q_INVOKABLE QString homeDirectory() const;
};
