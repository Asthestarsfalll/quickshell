#include "runtime/rapl_helper_client.h"
#include "runtime/clavis_paths.h"

#include <QFile>
#include <QLocalServer>
#include <QLocalSocket>
#include <QTemporaryDir>
#include <QtTest>

#include <thread>

using Clavis::Runtime::RaplHelperClient;

class RaplHelperClientTest : public QObject {
    Q_OBJECT

private:
    static Clavis::Runtime::RaplHelperSnapshot queryPayload(
        const QByteArray &payload)
    {
        QTemporaryDir temporary;
        if (!temporary.isValid())
            qFatal("test temporary directory could not be created");
        const QString socketPath = temporary.filePath(QStringLiteral("rapl.sock"));
        QFile::remove(socketPath);
        QLocalServer server;
        if (!server.listen(socketPath))
            qFatal("test RAPL socket could not listen");
        Clavis::Runtime::RaplHelperSnapshot snapshot;
        std::thread clientThread([&] {
            snapshot = RaplHelperClient::query(socketPath);
        });
        if (server.waitForNewConnection(1000)) {
            QLocalSocket *client = server.nextPendingConnection();
            if (client) {
            client->write(payload);
            client->flush();
            client->waitForBytesWritten(1000);
            client->disconnectFromServer();
            }
        }
        clientThread.join();
        return snapshot;
    }

private slots:
    void resolvesCanonicalXdgOverrides()
    {
        QTemporaryDir temporary;
        const QByteArray root = temporary.path().toLocal8Bit();
        qputenv("HOME", root + "/home");
        qputenv("XDG_CONFIG_HOME", root + "/config");
        qputenv("XDG_DATA_HOME", root + "/data");
        qputenv("XDG_STATE_HOME", root + "/state");
        qputenv("XDG_CACHE_HOME", root + "/cache");
        qputenv("XDG_RUNTIME_DIR", root + "/runtime");
        qputenv("CLAVIS_CONFIG_HOME", root + "/config/clavis");
        qputenv("CLAVIS_DATA_HOME", root + "/data/clavis");
        qputenv("CLAVIS_STATE_HOME", root + "/state/clavis");
        qputenv("CLAVIS_CACHE_HOME", root + "/cache/clavis");
        qputenv("CLAVIS_RUNTIME_HOME", root + "/runtime/clavis");
        const auto paths = Clavis::Runtime::ClavisPaths::fromEnvironment();
        QCOMPARE(paths.configHome(), temporary.filePath(QStringLiteral("config/clavis")));
        QCOMPARE(paths.dataHome(), temporary.filePath(QStringLiteral("data/clavis")));
        QCOMPARE(paths.stateHome(), temporary.filePath(QStringLiteral("state/clavis")));
        QCOMPARE(paths.cacheHome(), temporary.filePath(QStringLiteral("cache/clavis")));
        QCOMPARE(paths.runtimeHome(), temporary.filePath(QStringLiteral("runtime/clavis")));
    }

    void missingHelperFailsClosed()
    {
        QTemporaryDir temporary;
        const auto snapshot = RaplHelperClient::query(
            temporary.filePath(QStringLiteral("missing.sock")));
        QCOMPARE(snapshot.status, QStringLiteral("helper_missing"));
        QVERIFY(!snapshot.energyMicroJoules.has_value());
    }

    void acceptsStrictProtocolResponse()
    {
        const auto snapshot = queryPayload(
            R"({"protocol":1,"ok":true,"status":"readable","energyUj":1234,"maxEnergyRangeUj":9999})");
        QCOMPARE(snapshot.status, QStringLiteral("readable"));
        QCOMPARE(snapshot.energyMicroJoules.value_or(-1), 1234);
        QCOMPARE(snapshot.rangeMicroJoules.value_or(-1), 9999);
    }

    void rejectsInvalidJson()
    {
        const auto snapshot = queryPayload("not-json\n");
        QCOMPARE(snapshot.status, QStringLiteral("helper_invalid_response"));
        QVERIFY(!snapshot.energyMicroJoules.has_value());
    }

    void rejectsIncompatibleProtocol()
    {
        const auto snapshot = queryPayload(
            R"({"protocol":2,"ok":true,"energyUj":1234})");
        QCOMPARE(snapshot.status, QStringLiteral("helper_protocol_incompatible"));
        QVERIFY(!snapshot.energyMicroJoules.has_value());
    }
};

QTEST_MAIN(RaplHelperClientTest)
#include "rapl_helper_client_test.moc"
