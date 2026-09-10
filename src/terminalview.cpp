// SPDX-License-Identifier: GPL-2.0-or-later

#include "terminalview.h"

#include "ScreenWindow.h"
#include "TerminalSession.h"

#include <QClipboard>
#include <QDragEnterEvent>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QMimeData>
#include <QRegularExpression>
#include <QUrl>
#include <QWheelEvent>

using namespace Konsole;

TerminalView::TerminalView(QQuickItem *parent)
    : TerminalDisplay(parent)
{
    // The base class only accepts the left button, which leaves no way to
    // offer a context menu or a middle-click paste.
    setAcceptedMouseButtons(Qt::LeftButton | Qt::RightButton | Qt::MiddleButton);
    setFlag(ItemAcceptsDrops, true);
    setCursor(Qt::IBeamCursor);

    setBellMode(m_bellMode);
    setWordCharacters(m_wordCharacters);
}

TerminalView::~TerminalView() = default;

bool TerminalView::middleClickPaste() const
{
    return m_middleClickPaste;
}

void TerminalView::setMiddleClickPaste(bool enabled)
{
    if (m_middleClickPaste == enabled) {
        return;
    }
    m_middleClickPaste = enabled;
    Q_EMIT middleClickPasteChanged();
}

bool TerminalView::copyOnSelect() const
{
    return m_copyOnSelect;
}

void TerminalView::setCopyOnSelect(bool enabled)
{
    if (m_copyOnSelect == enabled) {
        return;
    }
    m_copyOnSelect = enabled;
    Q_EMIT copyOnSelectChanged();
}

bool TerminalView::readOnly() const
{
    return m_readOnly;
}

void TerminalView::setReadOnly(bool readOnly)
{
    if (m_readOnly == readOnly) {
        return;
    }
    m_readOnly = readOnly;
    Q_EMIT readOnlyChanged();
}

bool TerminalView::builtInShortcuts() const
{
    return m_builtInShortcuts;
}

void TerminalView::setBuiltInShortcuts(bool enabled)
{
    if (m_builtInShortcuts == enabled) {
        return;
    }
    m_builtInShortcuts = enabled;
    Q_EMIT builtInShortcutsChanged();
}

bool TerminalView::wheelZoom() const
{
    return m_wheelZoom;
}

void TerminalView::setWheelZoom(bool enabled)
{
    if (m_wheelZoom == enabled) {
        return;
    }
    m_wheelZoom = enabled;
    Q_EMIT wheelZoomChanged();
}

bool TerminalView::focusOnClick() const
{
    return m_focusOnClick;
}

void TerminalView::setFocusOnClick(bool enabled)
{
    if (m_focusOnClick == enabled) {
        return;
    }
    m_focusOnClick = enabled;
    Q_EMIT focusOnClickChanged();
}

int TerminalView::padding() const
{
    return margin();
}

void TerminalView::setPadding(int padding)
{
    if (margin() == padding) {
        return;
    }
    setMargin(padding);
    Q_EMIT paddingChanged();
}

int TerminalView::cursorShape() const
{
    return m_cursorShape;
}

void TerminalView::setCursorShape(int shape)
{
    if (m_cursorShape == shape) {
        return;
    }
    m_cursorShape = qBound(0, shape, 2);
    setKeyboardCursorShape(static_cast<Emulation::KeyboardCursorShape>(m_cursorShape));
    QQuickPaintedItem::update();
    Q_EMIT cursorShapeChanged();
}

int TerminalView::bellModeInt() const
{
    return m_bellMode;
}

void TerminalView::setBellModeInt(int mode)
{
    if (m_bellMode == mode) {
        return;
    }
    m_bellMode = qBound(0, mode, 3);
    setBellMode(m_bellMode);
    Q_EMIT bellModeChanged();
}

QString TerminalView::wordCharactersQml() const
{
    return m_wordCharacters;
}

void TerminalView::setWordCharactersQml(const QString &chars)
{
    if (m_wordCharacters == chars) {
        return;
    }
    m_wordCharacters = chars;
    setWordCharacters(chars);
    Q_EMIT wordCharactersChanged();
}

bool TerminalView::hasSelection() const
{
    return screenWindow() && !screenWindow()->selectedText(false).isEmpty();
}

void TerminalView::copy()
{
    copyClipboard();
}

void TerminalView::paste()
{
    if (m_readOnly) {
        return;
    }
    pasteClipboard();
}

void TerminalView::pastePrimary()
{
    if (m_readOnly) {
        return;
    }
    pasteSelection();
}

void TerminalView::clearSelection()
{
    if (screenWindow()) {
        screenWindow()->clearSelection();
        Q_EMIT selectionChangedNotify();
    }
}

QString TerminalView::selectedText() const
{
    return screenWindow() ? screenWindow()->selectedText(true) : QString();
}

void TerminalView::scrollToBottom()
{
    scrollToEnd();
}

// Scrolling from QML has to do what the internal scrollbar does: move the
// window, decide whether new output should still stick to the bottom, and ask
// the display to rebuild its image. Without the trackOutput update the view
// snaps straight back to the end.
void TerminalView::applyScrollChange()
{
    auto *window = screenWindow();
    if (!window) {
        return;
    }

    const int lastLine = qMax(0, window->lineCount() - window->windowLines());
    window->setTrackOutput(window->currentLine() >= lastLine);

    updateImage();
    QQuickPaintedItem::update();
}

void TerminalView::scrollLines(int lines)
{
    if (screenWindow()) {
        screenWindow()->scrollBy(ScreenWindow::ScrollLines, lines);
        applyScrollChange();
    }
}

void TerminalView::scrollPages(int pages)
{
    if (screenWindow()) {
        screenWindow()->scrollBy(ScreenWindow::ScrollPages, pages);
        applyScrollChange();
    }
}

void TerminalView::scrollToLine(int line)
{
    if (screenWindow()) {
        screenWindow()->scrollTo(line);
        applyScrollChange();
    }
}

int TerminalView::currentScrollLine() const
{
    return screenWindow() ? screenWindow()->currentLine() : 0;
}

void TerminalView::sendKey(int key, int modifiers, const QString &text)
{
    if (m_readOnly) {
        return;
    }
    simulateKeyPress(key, modifiers, true, 0, text);
}

void TerminalView::keyPressEvent(QKeyEvent *event)
{
    if (m_readOnly) {
        event->accept();
        return;
    }

    const auto mods = event->modifiers();
    if (m_builtInShortcuts && mods.testFlag(Qt::ControlModifier) && mods.testFlag(Qt::ShiftModifier)) {
        switch (event->key()) {
        case Qt::Key_C:
            copyClipboard();
            event->accept();
            return;
        case Qt::Key_V:
            pasteClipboard();
            event->accept();
            return;
        case Qt::Key_Plus:
        case Qt::Key_Equal:
            Q_EMIT zoomRequested(1);
            event->accept();
            return;
        case Qt::Key_Minus:
        case Qt::Key_Underscore:
            Q_EMIT zoomRequested(-1);
            event->accept();
            return;
        case Qt::Key_0:
        case Qt::Key_ParenRight:
            Q_EMIT zoomResetRequested();
            event->accept();
            return;
        default:
            break;
        }
    }

    TerminalDisplay::keyPressEvent(event);
}

void TerminalView::mousePressEvent(QMouseEvent *event)
{
    if (m_focusOnClick) {
        forceActiveFocus();
    }

    if (event->button() == Qt::RightButton) {
        Q_EMIT contextMenuRequested(event->position());
        event->accept();
        return;
    }

    if (event->button() == Qt::MiddleButton) {
        if (m_middleClickPaste && !m_readOnly) {
            pasteSelection();
        }
        event->accept();
        return;
    }

    TerminalDisplay::mousePressEvent(event);
}

void TerminalView::mouseReleaseEvent(QMouseEvent *event)
{
    TerminalDisplay::mouseReleaseEvent(event);

    if (event->button() == Qt::LeftButton) {
        if (m_copyOnSelect && hasSelection()) {
            copyClipboard();
        }
        Q_EMIT selectionChangedNotify();
    }
}

void TerminalView::mouseDoubleClickEvent(QMouseEvent *event)
{
    TerminalDisplay::mouseDoubleClickEvent(event);

    if (m_copyOnSelect && hasSelection()) {
        copyClipboard();
    }
    Q_EMIT selectionChangedNotify();
}

void TerminalView::wheelEvent(QWheelEvent *event)
{
    if (m_wheelZoom && event->modifiers().testFlag(Qt::ControlModifier)) {
        const int dy = event->angleDelta().y();
        if (dy != 0) {
            Q_EMIT zoomRequested(dy > 0 ? 1 : -1);
        }
        event->accept();
        return;
    }

    TerminalDisplay::wheelEvent(event);
}

void TerminalView::dragEnterEvent(QDragEnterEvent *event)
{
    if (m_readOnly) {
        event->ignore();
        return;
    }

    if (event->mimeData()->hasUrls() || event->mimeData()->hasText()) {
        event->acceptProposedAction();
        return;
    }

    event->ignore();
}

void TerminalView::dropEvent(QDropEvent *event)
{
    if (m_readOnly) {
        event->ignore();
        return;
    }

    QString text;
    const QList<QUrl> urls = event->mimeData()->urls();
    if (!urls.isEmpty()) {
        QStringList parts;
        parts.reserve(urls.size());
        for (const QUrl &url : urls) {
            QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
            // Quote anything the shell would otherwise split or expand.
            if (path.contains(QRegularExpression(QStringLiteral("[\\s'\"$`\\\\;&|<>()*?\\[\\]#~]")))) {
                path = QLatin1Char('\'') + QString(path).replace(QStringLiteral("'"), QStringLiteral("'\\''")) + QLatin1Char('\'');
            }
            parts << path;
        }
        text = parts.join(QLatin1Char(' '));
    } else if (event->mimeData()->hasText()) {
        text = event->mimeData()->text();
    }

    if (text.isEmpty()) {
        event->ignore();
        return;
    }

    event->acceptProposedAction();
    Q_EMIT textDropped(text);
}
