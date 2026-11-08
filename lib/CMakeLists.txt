# SPDX-FileCopyrightText: 2023 Jonah Brüchert <jbb@kaidan.im>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Vendored terminal core from qmlkonsole 26.08.0. Local patches are marked
# "(patched)" in the sources and listed in README.md under "Vendored code and
# local modifications".

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
