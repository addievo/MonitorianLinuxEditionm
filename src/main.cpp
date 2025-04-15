#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "monitormanager.h"
#include "monitor.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName("Monitor Brightness Control");
    app.setOrganizationName("MonitorControl");

    // Initialize monitor manager
    MonitorManager monitorManager;

    // Set up QML engine
    QQmlApplicationEngine engine;

    // Register custom types
    qmlRegisterType<Monitor>("MonitorControl", 1, 0, "Monitor");

    // Expose monitor manager to QML
    engine.rootContext()->setContextProperty("monitorManager", &monitorManager);

    // Load main QML file
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
