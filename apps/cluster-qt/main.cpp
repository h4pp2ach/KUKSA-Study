#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "radialbar.h"
#include "vehicledataclient.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    qmlRegisterType<RadialBar>("CustomControls", 1, 0, "RadialBar");
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);

    VehicleDataClient vehicleData;
    engine.rootContext()->setContextProperty("vehicleData", &vehicleData);
    engine.load(url);

    return app.exec();
}
