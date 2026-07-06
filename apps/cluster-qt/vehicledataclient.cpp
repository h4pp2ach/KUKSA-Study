#include "vehicledataclient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

VehicleDataClient::VehicleDataClient(QObject *parent)
    : QObject(parent)
{
    connect(&m_socket, &QTcpSocket::connected,
            this, &VehicleDataClient::onConnected);

    connect(&m_socket, &QTcpSocket::disconnected,
            this, &VehicleDataClient::onDisconnected);

    connect(&m_socket, &QTcpSocket::readyRead,
            this, &VehicleDataClient::onReadyRead);

    connect(&m_socket, &QTcpSocket::errorOccurred,
            this, &VehicleDataClient::onErrorOccurred);
}

double VehicleDataClient::vehicleSpeed() const
{
    return m_vehicleSpeed;
}

double VehicleDataClient::batterySoc() const
{
    return m_batterySoc;
}

QString VehicleDataClient::gear() const
{
    return m_gear;
}

bool VehicleDataClient::connected() const
{
    return m_connected;
}

void VehicleDataClient::connectToServer(const QString &host, quint16 port)
{
    if (m_socket.state() == QAbstractSocket::ConnectedState ||
        m_socket.state() == QAbstractSocket::ConnectingState) {
        return;
    }

    qDebug() << "[VehicleDataClient] Connecting to" << host << port;
    m_socket.connectToHost(host, port);
}

void VehicleDataClient::onConnected()
{
    m_connected = true;
    emit connectedChanged();

    qDebug() << "[VehicleDataClient] Connected";
}

void VehicleDataClient::onDisconnected()
{
    m_connected = false;
    emit connectedChanged();

    qDebug() << "[VehicleDataClient] Disconnected";
}

void VehicleDataClient::onReadyRead()
{
    m_buffer.append(m_socket.readAll());

    while (true) {
        int newlineIndex = m_buffer.indexOf('\n');
        if (newlineIndex < 0) {
            break;
        }

        QByteArray line = m_buffer.left(newlineIndex).trimmed();
        m_buffer.remove(0, newlineIndex + 1);

        if (!line.isEmpty()) {
            parseLine(line);
        }
    }
}

void VehicleDataClient::onErrorOccurred(QAbstractSocket::SocketError socketError)
{
    Q_UNUSED(socketError)
    qWarning() << "[VehicleDataClient] Socket error:" << m_socket.errorString();
}

void VehicleDataClient::parseLine(const QByteArray &line)
{
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(line, &parseError);

    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[VehicleDataClient] Invalid JSON:" << line;
        return;
    }

    QJsonObject obj = doc.object();

    if (obj.contains("vehicleSpeed")) {
        double newSpeed = obj.value("vehicleSpeed").toDouble();

        if (!qFuzzyCompare(m_vehicleSpeed + 1.0, newSpeed + 1.0)) {
            m_vehicleSpeed = newSpeed;
            emit vehicleSpeedChanged();
        }
    }

    if (obj.contains("batterySoc")) {
        double newBatterySoc = obj.value("batterySoc").toDouble();

        if (!qFuzzyCompare(m_batterySoc + 1.0, newBatterySoc + 1.0)) {
            m_batterySoc = newBatterySoc;
            emit batterySocChanged();
        }
    }

    if (obj.contains("gear")) {
        QString newGear = obj.value("gear").toString();

        if (m_gear != newGear) {
            m_gear = newGear;
            emit gearChanged();
        }
    }
}
