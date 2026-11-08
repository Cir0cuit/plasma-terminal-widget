<!-- The description of the KDE Store entry, https://store.kde.org/p/2371024. The store shows it as plain text: every line break is kept, so each paragraph is one line, web addresses become links, and Markdown is not rendered, and "&&" inside an indented command is shown as "&amp;&amp;". Paste everything below this comment. -->

A terminal emulator for the KDE Plasma 6 desktop, made as an ordinary Plasma widget. Put it on the desktop or in a panel, resize it, and give each terminal its own font, colour scheme and background. A terminal without a font or colour scheme of its own uses your default Konsole profile's.

The terminal is drawn by Plasma itself, inside the widget, not in a window of its own. It moves, resizes and stacks along with the other widgets, stays sharp on HiDPI screens, and handles selection, the clipboard and the keyboard like any other Qt application.

SETTINGS

Appearance: font family, style and size, line spacing, colour scheme, background, opacity, padding, cursor, the title strip and the scrollbar.

Shell: program and arguments, working directory, a command to run at startup, scrollback and environment variables.

Behavior: focus, copy on select, middle-click paste, Ctrl+wheel zoom, read-only mode, the terminal bell, and what happens when the shell exits.

INSTALLING

The widget comes in two halves. Get New Widgets installs the widget package, which is QML files in your home folder. The terminal itself is the engine, a compiled QML module that Plasma loads from Qt's system-wide QML folder. Get New Widgets cannot write there, so on its own it gives you a widget that says "Terminal engine not installed". The commands below compile the engine on your system and install both halves. Later versions are installed from the same folder with git pull && ./update.sh, as UPDATING below describes.

First, install what the build and the widget need, with the command for your distribution.

Fedora:

    sudo dnf install cmake gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qt5compat-devel kf6-kcoreaddons-devel kf6-kpty-devel

Debian / Ubuntu (Debian 13 or later, Ubuntu 26.04 or later):

    sudo apt install cmake build-essential qt6-base-dev qt6-declarative-dev qt6-5compat-dev libkf6coreaddons-dev libkf6pty-dev qml6-module-org-kde-notifications

Arch:

    sudo pacman -S --needed base-devel cmake qt6-base qt6-declarative qt6-5compat kcoreaddons kpty

Then download the project, build it and install both halves. Run install.sh as yourself, not with sudo: it asks for your password once, to install the engine.

    git clone https://github.com/Cir0cuit/plasma-terminal-widget.git
    cd plasma-terminal-widget
    ./install.sh

Restart Plasma so that it loads the engine:

    systemctl --user restart plasma-plasmashell.service

If Plasma does not run as a systemd user service on your system, log out and back in instead. Then add the widget from the desktop context menu: Add Widgets… → Terminal.

UPDATING

Updating keeps your widgets and their settings. In the folder you cloned, run:

    git pull
    ./update.sh

It rebuilds the engine, installs the new widget package, lists what changed and offers to restart Plasma.

Get New Widgets and Discover update only the widget package, and Plasma keeps running the old one until it restarts, so restart Plasma after such an update. If the engine is then older than the widget, the widget's settings pages say so and name what waits for it; git pull && ./update.sh brings the engine up to date.

If your copy of the project is from version 1.0, run git pull in it before anything else: its install.sh would put the older widget package back.

REMOVING

Take the widgets off the desktop, then run ./uninstall.sh in the folder you cloned. It removes both halves. Removing the widget in Get New Widgets removes only the widget package and leaves the engine installed.

TESTED ON

Fedora 44 (Plasma 6.7.5), Debian (Plasma 6.7.4), Arch (Plasma 6.6.5) and Ubuntu, all on Wayland: the dependency command installs, the build is clean, and the widget runs a live shell. For 1.1.0, every way of updating from 1.0 was tested on Fedora 45, Debian 13, Ubuntu 26.04 and Arch, and the widget ran on Plasma 6.8.2 with the old engine, the new one and none. X11, fractional or 1× scaling and multiple monitors are untried; bug reports that say what your setup was are welcome.

Source code and bug reports are on GitHub: https://github.com/Cir0cuit/plasma-terminal-widget

The terminal emulation comes from Konsole, ported to QML by QMLTermWidget and to Qt 6 by KDE's qmlkonsole. Licence: GPL-2.0-or-later.

Written with an AI coding agent doing the implementation, under human direction and review; the project's page on GitHub describes what that means and what was and was not tested.
