#include "lyrics.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>

#include <cstring>
#include <utility>

class ScopedEnvironment final {
public:
    explicit ScopedEnvironment(const char *name)
        : m_name(name), m_wasSet(qEnvironmentVariableIsSet(name)),
          m_value(qgetenv(name))
    {
    }

    ~ScopedEnvironment()
    {
        if (m_wasSet)
            qputenv(m_name.constData(), m_value);
        else
            qunsetenv(m_name.constData());
    }

private:
    QByteArray m_name;
    bool m_wasSet;
    QByteArray m_value;
};

class FixtureReply final : public QNetworkReply {
public:
    FixtureReply(const QNetworkRequest &request, QByteArray body,
                 bool *aborted, QObject *parent)
        : QNetworkReply(parent), m_body(std::move(body)), m_aborted(aborted)
    {
        setRequest(request);
        setUrl(request.url());
        setOperation(QNetworkAccessManager::GetOperation);
        setOpenMode(QIODevice::ReadOnly | QIODevice::Unbuffered);
        setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        setAttribute(QNetworkRequest::HttpStatusCodeAttribute, 200);
        QTimer::singleShot(0, this, [this]() {
            if (m_finished)
                return;
            m_finished = true;
            emit readyRead();
            emit finished();
        });
    }

    void abort() override
    {
        if (m_finished)
            return;
        if (m_aborted)
            *m_aborted = true;
        m_finished = true;
        setError(QNetworkReply::OperationCanceledError, QStringLiteral("cancelled"));
        emit finished();
    }

    bool isSequential() const override { return true; }

protected:
    qint64 readData(char *data, qint64 maxlen) override
    {
        if (m_offset >= m_body.size())
            return -1;
        const qint64 count = qMin(maxlen, static_cast<qint64>(m_body.size() - m_offset));
        memcpy(data, m_body.constData() + m_offset, static_cast<size_t>(count));
        m_offset += count;
        return count;
    }

private:
    QByteArray m_body;
    qint64 m_offset = 0;
    bool *m_aborted = nullptr;
    bool m_finished = false;
};

class FixtureNetworkAccessManager final : public QNetworkAccessManager {
public:
    QByteArray body = QByteArrayLiteral(R"({"syncedLyrics":"[00:01.00]Injected"})");
    int requests = 0;
    bool firstRequestAborted = false;

protected:
    QNetworkReply *createRequest(Operation operation,
                                 const QNetworkRequest &request,
                                 QIODevice *outgoingData = nullptr) override
    {
        Q_UNUSED(operation)
        Q_UNUSED(outgoingData)
        ++requests;
        return new FixtureReply(request, body,
                                requests == 1 ? &firstRequestAborted : nullptr,
                                this);
    }
};

class LyricsTest : public QObject {
    Q_OBJECT

private slots:
    void parsesMultipleTimestampsAndSorts();
    void appliesOffsetAndPlainText();
    void mapsTimeAndIndex();
    void handlesEmptyLyrics();
    void usesInjectedHttpProvider();
    void cancelsStaleRequests();
};

void LyricsTest::parsesMultipleTimestampsAndSorts()
{
    Lyrics lyrics;
    const QVariantList lines = lyrics.parseLrc(
        QStringLiteral("[00:10.00][00:02.50]second\n[00:01.00]first\n"));
    QCOMPARE(lines.size(), 3);
    QCOMPARE(lines.at(0).toMap().value("text").toString(), QStringLiteral("first"));
    QCOMPARE(lines.at(0).toMap().value("time").toDouble(), 1.0);
    QCOMPARE(lines.at(1).toMap().value("time").toDouble(), 2.5);
    QCOMPARE(lines.at(2).toMap().value("time").toDouble(), 10.0);
}

void LyricsTest::appliesOffsetAndPlainText()
{
    Lyrics lyrics;
    const QVariantList lines = lyrics.parseLrc(
        QStringLiteral("[offset:500]\n[00:01.20]hello\nplain line\n"), -200.0);
    QCOMPARE(lines.size(), 2);
    QCOMPARE(lines.at(0).toMap().value("time").toDouble(), 1.5);
    QCOMPARE(lines.at(1).toMap().value("time").toDouble(), -1.0);
}

void LyricsTest::mapsTimeAndIndex()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    qputenv("XDG_DATA_HOME", QFile::encodeName(temporary.path()));
    const QByteArray key = QCryptographicHash::hash(
        QByteArrayLiteral("artist\ntest\nalbum"), QCryptographicHash::Sha256).toHex();
    const QString directory = QDir(temporary.path()).filePath(QStringLiteral("clavis/lyrics"));
    QVERIFY(QDir().mkpath(directory));
    QFile fixture(QDir(directory).filePath(QString::fromLatin1(key) + QStringLiteral(".lrc")));
    QVERIFY(fixture.open(QIODevice::WriteOnly));
    fixture.write("[00:01.00]one\n[00:03.00]two\n");
    fixture.close();

    Lyrics lyrics;
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("test"), QStringLiteral("album"));
    QCOMPARE(lyrics.lyrics().size(), 2);
    QCOMPARE(lyrics.indexForTime(0.9), -1);
    QCOMPARE(lyrics.indexForTime(1.0), 0);
    QCOMPARE(lyrics.indexForTime(4.0), 1);
    QCOMPARE(lyrics.timeForIndex(1), 3.0);
    QCOMPARE(lyrics.timeForIndex(4), -1.0);
}

void LyricsTest::handlesEmptyLyrics()
{
    Lyrics lyrics;
    QVERIFY(lyrics.parseLrc({}).isEmpty());
    QCOMPARE(lyrics.indexForTime(0.0), -1);
    QCOMPARE(lyrics.timeForIndex(0), -1.0);
}

void LyricsTest::usesInjectedHttpProvider()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    qputenv("XDG_DATA_HOME", QFile::encodeName(temporary.path() + QStringLiteral("/data")));
    qputenv("XDG_CACHE_HOME", QFile::encodeName(temporary.path() + QStringLiteral("/cache")));
    FixtureNetworkAccessManager manager;
    Lyrics lyrics;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("title"));
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1000);
    QCOMPARE(manager.requests, 1);
    QCOMPARE(lyrics.provider(), QStringLiteral("LRCLIB"));
    QCOMPARE(lyrics.timeForIndex(0), 1.0);
}

void LyricsTest::cancelsStaleRequests()
{
    FixtureNetworkAccessManager manager;
    Lyrics lyrics;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("first"));
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("second"));
    QVERIFY(manager.requests >= 2);
    QVERIFY(manager.firstRequestAborted);
    lyrics.cancel();
    QVERIFY(!lyrics.loading());
}

QTEST_MAIN(LyricsTest)

#include "lyrics_test.moc"
