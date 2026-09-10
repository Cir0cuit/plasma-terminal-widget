// SPDX-License-Identifier: GPL-2.0-or-later
//
// TerminalView - the QML item the plasmoid actually instantiates.
//
// It is a thin subclass of the vendored Konsole::TerminalDisplay that adds
// everything the base class does not expose to QML: right/middle mouse
// buttons, click-to-focus, copy-on-select, built-in clipboard shortcuts,
// Ctrl+wheel zoom, a read-only mode, drag-and-drop of file paths, and a
// handful of Q_INVOKABLEs for the widget's context menu.

#pragma once

#include <QQmlEngine>

#include "TerminalDisplay.h"

class TerminalView : public Konsole::TerminalDisplay
{
    Q_OBJECT
    QML_NAMED_ELEMENT(TerminalView)

    /** Paste the primary selection on middle click. Off by default. */
    Q_PROPERTY(bool middleClickPaste READ middleClickPaste WRITE setMiddleClickPaste NOTIFY middleClickPasteChanged)
    /** Copy to the clipboard as soon as a selection is made with the mouse. */
    Q_PROPERTY(bool copyOnSelect READ copyOnSelect WRITE setCopyOnSelect NOTIFY copyOnSelectChanged)
    /** Swallow all keyboard input, so the widget can only be read. */
    Q_PROPERTY(bool readOnly READ readOnly WRITE setReadOnly NOTIFY readOnlyChanged)
    /** Handle Ctrl+Shift+C/V/+/-/0 inside the view. */
    Q_PROPERTY(bool builtInShortcuts READ builtInShortcuts WRITE setBuiltInShortcuts NOTIFY builtInShortcutsChanged)
    /** Emit zoomRequested() on Ctrl+wheel instead of scrolling. */
    Q_PROPERTY(bool wheelZoom READ wheelZoom WRITE setWheelZoom NOTIFY wheelZoomChanged)
    /** Give the view keyboard focus when it is clicked. */
    Q_PROPERTY(bool focusOnClick READ focusOnClick WRITE setFocusOnClick NOTIFY focusOnClickChanged)
    /** Padding between the widget edge and the character grid, in pixels. */
    Q_PROPERTY(int padding READ padding WRITE setPadding NOTIFY paddingChanged)
    /** 0 = block, 1 = underline, 2 = I-beam. */
    Q_PROPERTY(int cursorShape READ cursorShape WRITE setCursorShape NOTIFY cursorShapeChanged)
    /** 0 = system beep, 1 = notification, 2 = visual, 3 = none. */
    Q_PROPERTY(int bellMode READ bellModeInt WRITE setBellModeInt NOTIFY bellModeChanged)
    /** True while the mouse has selected some text. */
    Q_PROPERTY(bool hasSelection READ hasSelection NOTIFY selectionChangedNotify)
    /** Characters treated as part of a word for double-click selection. */
    Q_PROPERTY(QString wordCharacters READ wordCharactersQml WRITE setWordCharactersQml NOTIFY wordCharactersChanged)

public:
    explicit TerminalView(QQuickItem *parent = nullptr);
    ~TerminalView() override;

    bool middleClickPaste() const;
    void setMiddleClickPaste(bool enabled);

    bool copyOnSelect() const;
    void setCopyOnSelect(bool enabled);

    bool readOnly() const;
    void setReadOnly(bool readOnly);

    bool builtInShortcuts() const;
    void setBuiltInShortcuts(bool enabled);

    bool wheelZoom() const;
    void setWheelZoom(bool enabled);

    bool focusOnClick() const;
    void setFocusOnClick(bool enabled);

    int padding() const;
    void setPadding(int padding);

    int cursorShape() const;
    void setCursorShape(int shape);

    int bellModeInt() const;
    void setBellModeInt(int mode);

    QString wordCharactersQml() const;
    void setWordCharactersQml(const QString &chars);

    bool hasSelection() const;

public Q_SLOTS:
    /** Copy the current selection to the clipboard. */
    void copy();
    /** Paste the clipboard into the terminal. */
    void paste();
    /** Paste the primary selection into the terminal. */
    void pastePrimary();
    /** Drop the current selection. */
    void clearSelection();
    /** Return the selected text, or an empty string. */
    QString selectedText() const;
    /** Scroll the view to the bottom. */
    void scrollToBottom();
    /** Scroll by @p lines (negative scrolls up). */
    void scrollLines(int lines);
    /** Scroll by @p pages (negative scrolls up). */
    void scrollPages(int pages);
    /** Scroll so that scrollback line @p line is at the top of the view. */
    void scrollToLine(int line);
    /** First scrollback line currently visible. */
    int currentScrollLine() const;
    /** Feed a key press to the emulation, e.g. from a toolbar button. */
    void sendKey(int key, int modifiers = 0, const QString &text = QString());

Q_SIGNALS:
    void middleClickPasteChanged();
    void copyOnSelectChanged();
    void readOnlyChanged();
    void builtInShortcutsChanged();
    void wheelZoomChanged();
    void focusOnClickChanged();
    void paddingChanged();
    void cursorShapeChanged();
    void bellModeChanged();
    void wordCharactersChanged();
    void selectionChangedNotify();
    /** The user asked for a context menu at @p position (item coordinates). */
    void contextMenuRequested(const QPointF &position);
    /** Ctrl+wheel or Ctrl+Shift+/- ; @p delta is in points. */
    void zoomRequested(int delta);
    /** Ctrl+Shift+0 */
    void zoomResetRequested();
    /** The user dropped files or text on the terminal. */
    void textDropped(const QString &text);

private:
    void applyScrollChange();

protected:
    void keyPressEvent(QKeyEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void mouseDoubleClickEvent(QMouseEvent *event) override;
    void wheelEvent(QWheelEvent *event) override;
    void dragEnterEvent(QDragEnterEvent *event) override;
    void dropEvent(QDropEvent *event) override;

private:
    bool m_middleClickPaste = false;
    bool m_copyOnSelect = false;
    bool m_readOnly = false;
    bool m_builtInShortcuts = true;
    bool m_wheelZoom = true;
    bool m_focusOnClick = true;
    int m_cursorShape = 0;
    int m_bellMode = 3;
    QString m_wordCharacters = QStringLiteral(":@-./_~");
};
