// SPDX-License-Identifier: GPL-2.0-or-later
//
// The widget comes in two halves that are installed separately: this QML
// package and the compiled terminal engine on Qt's import path. They can be
// updated at different times - the package from Get New Widgets, the engine
// only by rebuilding it - so the settings pages check which engine they are
// running on, through EngineInfo.qml.
//
// TerminalPane.qml must not import this file, nor any other file that an
// older release lacked. Get New Widgets can replace the package while Plasma
// runs, and a terminal opened after that loads the new TerminalPane.qml, but
// Plasma's QML engine still has the old folder listing and cannot find files
// that are new. The settings pages are safe: each settings dialog gets a
// fresh engine.

.pragma library

// The oldest engine this package works fully with. Raise it in the same
// change that adds anything users notice to the engine, new API or a fix, and
// keep the project version in CMakeLists.txt at least as high.
var requiredEngine = "1.1.0";

function parts(version) {
    return String(version).split(".").map(function (n) {
        return parseInt(n, 10) || 0;
    });
}

function compare(a, b) {
    var x = parts(a), y = parts(b);
    for (var i = 0; i < Math.max(x.length, y.length); i++) {
        var d = (x[i] || 0) - (y[i] || 0);
        if (d !== 0) {
            return d < 0 ? -1 : 1;
        }
    }
    return 0;
}

// Engines before 1.1.0 did not report a version at all.
function installedEngine(info) {
    return info.engineVersion !== undefined ? info.engineVersion : "1.0.0";
}

function engineOutdated(info) {
    return compare(installedEngine(info), requiredEngine) < 0;
}
