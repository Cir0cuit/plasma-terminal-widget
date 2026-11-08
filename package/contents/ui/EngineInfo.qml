// SPDX-License-Identifier: GPL-2.0-or-later
//
// The settings pages' only way to the terminal engine. EngineStatus.qml loads
// this file, so that a page still opens, and says why, when the engine is
// not installed.

import QtQml

import io.github.cir0cuit.plasmaterminal.core as PT

import "version.js" as Version

QtObject {
    readonly property var info: PT.TerminalInfo
    readonly property string installedVersion: Version.installedEngine(PT.TerminalInfo)
    readonly property string requiredVersion: Version.requiredEngine
    readonly property bool outdated: Version.engineOutdated(PT.TerminalInfo)

    // True if the loaded engine is older than the given version.
    function lacks(version) {
        return Version.compare(installedVersion, version) < 0;
    }
}
