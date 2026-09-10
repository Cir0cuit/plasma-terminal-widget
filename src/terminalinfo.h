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

public:
    explicit TerminalInfo(QObject *parent = nullptr);

    /** Font families with fixed character width, sorted, deduplicated. */
    Q_INVOKABLE QStringList monospaceFamilies() const;
    /** Every installed font family. */
    Q_INVOKABLE QStringList allFamilies() const;
    /** True if @p family exists on this system. */
    Q_INVOKABLE bool hasFamily(const QString &family) const;

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
     * colorScheme, lineSpacing. Missing entries are simply absent.
     */
    Q_INVOKABLE QVariantMap konsoleProfile() const;
    /** The user's home directory. */
    Q_INVOKABLE QString homeDirectory() const;
};
