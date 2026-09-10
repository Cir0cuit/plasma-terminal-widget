// SPDX-License-Identifier: GPL-2.0-or-later
//
// The QML engine needs to know about the vendored base classes so that
// TerminalView's "session" property (typed TerminalSession*) can be
// assigned from QML. They are registered anonymously: QML code never
// names them, it only ever creates our subclasses.

#pragma once

#include <QQmlEngine>

#include "TerminalDisplay.h"
#include "TerminalSession.h"

struct TerminalSessionForeign {
    Q_GADGET
    QML_FOREIGN(TerminalSession)
    QML_ANONYMOUS
};

struct TerminalDisplayForeign {
    Q_GADGET
    QML_FOREIGN(Konsole::TerminalDisplay)
    QML_ANONYMOUS
};
