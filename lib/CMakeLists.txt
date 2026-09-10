# SPDX-FileCopyrightText: 2023 Jonah Brüchert <jbb@kaidan.im>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Vendored terminal core from qmlkonsole 26.08.0. Two local patches, both
# marked with "(patched)" in the sources:
#   * TerminalSession.cpp no longer calls setenv() on the *host* process.
#   * Session::run() no longer appends COLORFGBG to the stored environment
#     on every start.

add_library(PlasmaTerminalCore STATIC
    BlockArray.cpp
    ColorScheme.cpp
    Emulation.cpp
    Filter.cpp
    History.cpp
    HistorySearch.cpp
    KeyboardTranslator.cpp
    ProcessInfo.cpp
    Pty.cpp
    Screen.cpp
    ScreenWindow.cpp
    Session.cpp
    ShellCommand.cpp
    TerminalCharacterDecoder.cpp
    TerminalDisplay.cpp
    tools.cpp
    Vt102Emulation.cpp
    TerminalSession.cpp
    terminal.qrc
)

target_link_libraries(PlasmaTerminalCore
    PUBLIC
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::Widgets
        Qt6::Core5Compat
        KF6::CoreAddons
        KF6::Pty
)

target_include_directories(PlasmaTerminalCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# The vendored code predates a few Qt deprecations; they are not worth
# patching out and only add noise to the build log.
target_compile_options(PlasmaTerminalCore PRIVATE -Wno-deprecated-declarations)
