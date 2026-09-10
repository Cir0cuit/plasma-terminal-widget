# SPDX-License-Identifier: GPL-2.0-or-later
#
# Plasma Terminal - a real terminal emulator as a KDE Plasma 6 widget.
#
# The terminal core in lib/ is vendored from KDE's qmlkonsole 26.08.0
# (itself a Qt6 port of QMLTermWidget / Konsole), GPL-2.0-or-later.

cmake_minimum_required(VERSION 3.20)

project(plasma-terminal-widget VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick Widgets Core5Compat)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6Pty REQUIRED)

# The applet id and the QML module URI. Keep them in sync with
# package/metadata.json and the imports in package/contents/ui/*.qml.
set(PT_APPLET_ID "io.github.cir0cuit.plasmaterminal")
set(PT_QML_URI "io.github.cir0cuit.plasmaterminal.core")
# Qt looks the module up under a directory tree that mirrors the URI.
string(REPLACE "." "/" PT_QML_URI_PATH "${PT_QML_URI}")

# The module has to end up on plasmashell's QML import path, which is Qt's
# own qml directory - ask Qt where that is rather than guessing lib vs lib64.
if(NOT PT_QMLDIR)
    get_target_property(PT_QMAKE Qt6::qmake IMPORTED_LOCATION)
    execute_process(
        COMMAND ${PT_QMAKE} -query QT_INSTALL_QML
        OUTPUT_VARIABLE PT_QMLDIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE PT_QMAKE_RESULT
    )
    if(NOT PT_QMAKE_RESULT EQUAL 0 OR PT_QMLDIR STREQUAL "")
        include(GNUInstallDirs)
        set(PT_QMLDIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/qt6/qml")
    endif()
endif()

add_subdirectory(lib)
add_subdirectory(src)

message(STATUS "QML module '${PT_QML_URI}' installs to ${PT_QMLDIR}/${PT_QML_URI_PATH}")

# Optional developer harness: a QApplication that hosts test/harness.qml.
option(PT_BUILD_HARNESS "Build the interactive test harness" ON)
if(PT_BUILD_HARNESS)
    add_executable(pt-harness test/harness_main.cpp)
    target_link_libraries(pt-harness PRIVATE Qt6::Widgets Qt6::Qml Qt6::Quick)
endif()
