#ifndef VEHICLEDATACLIENT_H
#define VEHICLEDATACLIENT_H

#include <QObject>
#include <QTcpSocket>

class VehicleDataClient : public QObject
{
    Q_OBJECT

    Q_PROPERTY(double vehicleSpeed READ vehicleSpeed NOTIFY vehicleSpeedChanged)
    Q_PROPERTY(double batterySoc READ batterySoc NOTIFY batterySocChanged)
    Q_PROPERTY(QString gear READ gear NOTIFY gearChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit VehicleDataClient(QObject *parent = nullptr);

    double vehicleSpeed() const;
    double batterySoc() const;
    QString gear() const;
    bool connected() const;

    Q_INVOKABLE void connectToServer(const QString &host = "127.0.0.1", quint16 port = 55556);
    Q_INVOKABLE void disconnectFromServer();

signals:
    void vehicleSpeedChanged();
    void batterySocChanged();
    void gearChanged();
    void connectedChanged();

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onErrorOccurred(QAbstractSocket::SocketError socketError);

private:
    void parseLine(const QByteArray &line);

    QTcpSocket m_socket;
    QByteArray m_buffer;
    QString m_host = "127.0.0.1";
    quint16 m_port = 55556;

    double m_vehicleSpeed = 0.0;
    double m_batterySoc = 65.0;
    QString m_gear = "P";
    bool m_connected = false;
};

#endif
