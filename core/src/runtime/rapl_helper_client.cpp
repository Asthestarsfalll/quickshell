#include "rapl_helper_client.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>

namespace Clavis::Runtime {

QString RaplHelperClient::defaultSocketPath()
{
    const QString configured = QString::fromLocal8Bit(
        qgetenv("CLAVIS_RAPL_SOCKET")).trimmed();
    return configured.isEmpty()
        ? QStringLiteral("/run/clavis-rapl/rapl.sock")
        : configured;
}

RaplHelperSnapshot RaplHelperClient::query(const QString &requestedSocketPath)
{
    const QString socketPath = requestedSocketPath.isEmpty()
        ? defaultSocketPath() : requestedSocketPath;
    QLocalSocket socket;
    socket.connectToServer(socketPath, QIODevice::ReadOnly);
    if (!socket.waitForConnected(40))
        return {QStringLiteral("helper_missing"), {}, {}};
    if (!socket.waitForReadyRead(60) && socket.bytesAvailable() == 0)
        return {QStringLiteral("helper_read_failed"), {}, {}};
    QByteArray payload = socket.readAll();
    while (socket.waitForReadyRead(10) && payload.size() <= 4096)
        payload += socket.readAll();
    if (payload.size() > 4096)
        return {QStringLiteral("helper_invalid_response"), {}, {}};

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(payload, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return {QStringLiteral("helper_invalid_response"), {}, {}};
    const QJsonObject object = document.object();
    if (object.value(QStringLiteral("protocol")).toInt(-1) != ProtocolVersion)
        return {QStringLiteral("helper_protocol_incompatible"), {}, {}};
    if (!object.value(QStringLiteral("ok")).toBool(false)) {
        return {
            QStringLiteral("helper_%1").arg(
                object.value(QStringLiteral("status")).toString(
                    QStringLiteral("read_failed"))),
            {},
            {},
        };
    }
    const qint64 energy = object.value(QStringLiteral("energyUj")).toInteger(-1);
    const qint64 range =
        object.value(QStringLiteral("maxEnergyRangeUj")).toInteger(-1);
    if (energy < 0)
        return {QStringLiteral("helper_invalid_response"), {}, {}};
    return {
        QStringLiteral("readable"),
        energy,
        range >= 0 ? std::optional<qint64>(range) : std::nullopt,
    };
}

} // namespace Clavis::Runtime
