# SPDX-License-Identifier: GPL-2.0-or-later
#
# The QML module that the plasmoid imports. It has to live on the QML import
# path of plasmashell itself, which is why this half is installed system-wide
# while the applet package is installed per-user with kpackagetool6.

set(PT_QML_OUTPUT_DIR ${CMAKE_BINARY_DIR}/qml/${PT_QML_URI_PATH})

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

# Reported to QML as TerminalInfo.engineVersion; see package/contents/ui/version.js.
target_compile_definitions(plasmaterminalcoreplugin PRIVATE PT_ENGINE_VERSION="${PROJECT_VERSION}")

# The same version as a file next to the plugin, for update.sh and install.sh:
# they have to know the installed engine's version without loading it, because
# Get New Widgets can update the widget package while the engine stays old.
# Engines from before 1.1.0 have no such file. Written at configure time, so a
# rebuild keeps it, and installed with the rest of the directory below.
file(CONFIGURE OUTPUT "${PT_QML_OUTPUT_DIR}/version" CONTENT "@PROJECT_VERSION@\n" @ONLY)

target_link_libraries(plasmaterminalcoreplugin
    PRIVATE
        PlasmaTerminalCore
        Qt6::Qml
        Qt6::Quick
)

# Everything from io/ down, with fixed modes. Under a umask stricter than 022
# the build's files and the directories the install creates would otherwise be
# readable by root alone, and plasmashell could not load the engine. Naming
# io/ rather than core/ also opens up directories an earlier install made that
# way, since cmake sets the mode of every directory it installs. build/qml
# holds nothing but this module. The plugin keeps the execute bits a library
# has.
install(DIRECTORY ${CMAKE_BINARY_DIR}/qml/io
    DESTINATION ${PT_QMLDIR}
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
    DIRECTORY_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    PATTERN "*.so"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
)
