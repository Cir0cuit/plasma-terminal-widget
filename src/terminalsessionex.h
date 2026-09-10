// SPDX-License-Identifier: GPL-2.0-or-later
//
// TerminalSessionEx - the session type the plasmoid instantiates.
//
// The vendored TerminalSession keeps most of its interesting knobs (child
// environment, scrollback size, flow control, history/emulation resets)
// outside of the QML type system. This subclass exposes them, and picks
// defaults that suit a desktop widget rather than a phone.

#pragma once

#include <QQmlEngine>
#include <QStringList>

#include "TerminalSession.h"

class TerminalSessionEx : public TerminalSession
{
    Q_OBJECT
    QML_NAMED_ELEMENT(TerminalSession)

    /** Scrollback in lines. 0 disables it, a negative value means unlimited. */
    Q_PROPERTY(int scrollbackLines READ scrollbackLines WRITE setScrollbackLines NOTIFY scrollbackLinesChanged)
    /** Extra environment variables for the child, as "NAME=value" strings. */
    Q_PROPERTY(QStringList environment READ environment WRITE setEnvironmentList NOTIFY environmentChanged)
    /** Whether Ctrl+S / Ctrl+Q suspend output. */
    Q_PROPERTY(bool flowControl READ flowControl WRITE setFlowControl NOTIFY flowControlChanged)
    /** True between the shell starting and exiting. */
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    /** PID of the shell, or 0. */
    Q_PROPERTY(int processId READ processId NOTIFY runningChanged)

public:
    explicit TerminalSessionEx(QObject *parent = nullptr);
    ~TerminalSessionEx() override;

    int scrollbackLines() const;
    void setScrollbackLines(int lines);

    QStringList environment() const;
    void setEnvironmentList(const QStringList &environment);

    bool flowControl() const;
    void setFlowControl(bool enabled);

    bool running() const;
    int processId() const;

public Q_SLOTS:
    /** Start the shell if it is not running yet. */
    void start();
    /** Ask the shell to exit (SIGHUP). */
    void stop();
    /** Clear the visible screen only. */
    void clearDisplay();
    /** Drop the scrollback buffer. */
    void clearScrollback();
    /** Clear both the screen and the scrollback. */
    void clearAll();
    /** Full terminal reset, like the reset(1) command. */
    void resetTerminal();
    /** Working directory of the foreground process, or an empty string. */
    QString workingDirectory();
    /** Name of the foreground process, or an empty string. */
    QString foregroundProcess();

Q_SIGNALS:
    void scrollbackLinesChanged();
    void environmentChanged();
    void flowControlChanged();
    void runningChanged();

private:
    QStringList m_environment;
    int m_scrollbackLines = 10000;
    bool m_flowControl = true;
    bool m_running = false;
};
