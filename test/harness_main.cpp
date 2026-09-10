// SPDX-License-Identifier: GPL-2.0-or-later
//
// A minimal host for test/harness.qml.
//
// It has to be a QApplication rather than the stock `qml` tool: the vendored
// terminal core builds a QScrollBar to model the scroll position, and
// constructing any QWidget under a bare QGuiApplication is fatal. plasmashell
// is a QApplication, so this matches the real environment.

#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("plasma-terminal-harness"));

    QQmlApplicationEngine engine;
    for (int i = 1; i < argc - 1; ++i) {
        if (qstrcmp(argv[i], "-I") == 0) {
            engine.addImportPath(QString::fromLocal8Bit(argv[i + 1]));
        }
    }

    QString source = QStringLiteral("harness.qml");
    if (argc > 1) {
        source = QString::fromLocal8Bit(argv[argc - 1]);
    }

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] {
        qCritical("harness: failed to load QML");
        QCoreApplication::exit(2);
    });

    engine.load(QUrl::fromLocalFile(source));

    // Safety net so an unattended run always terminates.
    int seconds = qEnvironmentVariableIntValue("HARNESS_SECONDS");
    if (seconds <= 0) {
        seconds = 30;
    }
    QTimer::singleShot(seconds * 1000, &app, &QCoreApplication::quit);

    return app.exec();
}
