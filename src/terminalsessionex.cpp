// SPDX-License-Identifier: GPL-2.0-or-later

#include "terminalsessionex.h"

#include "Emulation.h"
#include "Session.h"

#include <QFileInfo>
#include <QTimer>

#include <csignal>

TerminalSessionEx::TerminalSessionEx(QObject *parent)
    : TerminalSession(parent)
{
    // A terminal that claims to be a plain "xterm" makes ncurses applications
    // fall back to 8 colours. The vendored code used to set this by mutating
    // the host process environment; we pass it to the child instead.
    m_environment = {
        QStringLiteral("TERM=xterm-256color"),
        QStringLiteral("COLORTERM=truecolor"),
    };
    setEnvironment(m_environment);

    setHistorySize(m_scrollbackLines);
    setFlowControlEnabled(m_flowControl);

    connect(this, &TerminalSession::started, this, [this] {
        if (!m_running) {
            m_running = true;
            Q_EMIT runningChanged();
        }
    });
    connect(this, &TerminalSession::finished, this, [this] {
        if (m_running) {
            m_running = false;
            Q_EMIT runningChanged();
        }
    });
}

TerminalSessionEx::~TerminalSessionEx() = default;

int TerminalSessionEx::scrollbackLines() const
{
    return m_scrollbackLines;
}

void TerminalSessionEx::setScrollbackLines(int lines)
{
    if (m_scrollbackLines == lines) {
        return;
    }
    m_scrollbackLines = lines;
    setHistorySize(lines);
    Q_EMIT scrollbackLinesChanged();
}

QStringList TerminalSessionEx::environment() const
{
    return m_environment;
}

void TerminalSessionEx::setEnvironmentList(const QStringList &environment)
{
    if (m_environment == environment) {
        return;
    }
    m_environment = environment;
    setEnvironment(m_environment);
    Q_EMIT environmentChanged();
}

bool TerminalSessionEx::flowControl() const
{
    return m_flowControl;
}

void TerminalSessionEx::setFlowControl(bool enabled)
{
    if (m_flowControl == enabled) {
        return;
    }
    m_flowControl = enabled;
    setFlowControlEnabled(enabled);
    Q_EMIT flowControlChanged();
}

bool TerminalSessionEx::running() const
{
    return m_running;
}

int TerminalSessionEx::processId() const
{
    auto *session = konsoleSession();
    return session && session->isRunning() ? session->processId() : 0;
}

void TerminalSessionEx::start()
{
    startShellProgram();
}

void TerminalSessionEx::stop()
{
    if (m_running) {
        sendSignal(SIGHUP);
    }
}

void TerminalSessionEx::clearDisplay()
{
    clearScreen();
}

void TerminalSessionEx::clearScrollback()
{
    if (auto *session = konsoleSession()) {
        session->clearHistory();
        // Let the views catch up, or the scrollbar keeps the old range.
        QMetaObject::invokeMethod(session->emulation(), "bufferedUpdate");
    }
}

void TerminalSessionEx::clearAll()
{
    auto *session = konsoleSession();
    if (!session) {
        return;
    }
    // A reset turns off bracketed paste; the shell enabled it for its line
    // editor and would not turn it on again until the next command.
    const bool bracketedPaste = session->emulation()->programBracketedPasteMode();
    resetTerminal(); // pushes the old screen into the history...
    clearScrollback(); // ...so this comes after it
    if (bracketedPaste) {
        session->emulation()->receiveData("\x1b[?2004h", 8);
    }

    // Ctrl+L makes bash, zsh and fish redraw their prompt, but only while the
    // shell itself waits for input: any other program would read it as typing.
    static const QStringList redrawingShells{QStringLiteral("bash"), QStringLiteral("zsh"), QStringLiteral("fish")};
    if (session->isRunning() && session->foregroundProcessId() == session->processId()
        && redrawingShells.contains(QFileInfo(shellProgram()).fileName())) {
        sendText(QStringLiteral("\x0c"));
        // fish scrolls the old screen into the history to redraw; clear it again.
        QTimer::singleShot(250, this, &TerminalSessionEx::clearScrollback);
    }
}

void TerminalSessionEx::resetTerminal()
{
    if (auto *session = konsoleSession()) {
        session->emulation()->reset();
    }
}

QString TerminalSessionEx::workingDirectory()
{
    return currentDir();
}

QString TerminalSessionEx::foregroundProcess()
{
    return foregroundProcessName();
}
