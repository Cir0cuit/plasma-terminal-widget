# SPDX-License-Identifier: GPL-2.0-or-later
#
# The QML module that the plasmoid imports. It has to live on the QML import
# path of plasmashell itself, which is why this half is installed system-wide
# while the applet package is installed per-user with kpackagetool6.

set(PT_QML_OUTPUT_DIR ${CMAKE_BINARY_DIR}/qml/local/plasmaterminal/core)

qt_add_qml_module(plasmaterminalcoreplugin
    URI ${PT_QML_URI}
    VERSION 1.0
    PLUGIN_TARGET plasmaterminalcoreplugin
    OUTPUT_DIRECTORY ${PT_QML_OUTPUT_DIR}
    NO_PLUGIN_OPTIONAL
    SOURCES
        terminalview.h
        terminalview.cpp
        terminalsessionex.h
        terminalsessionex.cpp
        terminalinfo.h
        terminalinfo.cpp
        foreigntypes.h
)

# Extra colour schemes, published under the same resource prefix that the
# vendored core scans, so they appear alongside the built-in ones.
qt_add_resources(plasmaterminalcoreplugin "extraschemes"
    PREFIX "/konsoleqml"
    FILES
        "color-schemes/Breeze.colorscheme"
        "color-schemes/Campbell.colorscheme"
        "color-schemes/Catppuccin Mocha.colorscheme"
        "color-schemes/Dracula.colorscheme"
        "color-schemes/Gruvbox Dark.colorscheme"
        "color-schemes/Nord.colorscheme"
        "color-schemes/One Dark.colorscheme"
        "color-schemes/Tokyo Night.colorscheme"
)

target_link_libraries(plasmaterminalcoreplugin
    PRIVATE
        PlasmaTerminalCore
        Qt6::Qml
        Qt6::Quick
)

install(DIRECTORY ${PT_QML_OUTPUT_DIR}/
    DESTINATION ${PT_QMLDIR}/local/plasmaterminal/core
    USE_SOURCE_PERMISSIONS
)
