#include "lyrics.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>
#include <QUrlQuery>

#include <functional>
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
    FixtureReply(const QNetworkRequest &request, bool *aborted, QObject *parent)
        : QNetworkReply(parent), m_aborted(aborted)
    {
        setRequest(request);
        setUrl(request.url());
        setOperation(QNetworkAccessManager::GetOperation);
        setOpenMode(QIODevice::ReadOnly | QIODevice::Unbuffered);
        setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    }

    void complete(const QByteArray &body, int statusCode = 200)
    {
        if (m_completed)
            return;
        m_body = body;
        setAttribute(QNetworkRequest::HttpStatusCodeAttribute, statusCode);
        m_completed = true;
        emit readyRead();
        emit finished();
    }

    void abort() override
    {
        if (m_completed || m_abortedState)
            return;
        if (m_aborted)
            *m_aborted = true;
        m_abortedState = true;
        setError(QNetworkReply::OperationCanceledError, QStringLiteral("cancelled"));
        emit finished();
    }

    bool isSequential() const override { return true; }
    bool completed() const { return m_completed; }
    bool aborted() const { return m_abortedState; }

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
    bool m_completed = false;
    bool m_abortedState = false;
};

class FixtureNetworkAccessManager final : public QNetworkAccessManager {
public:
    using Responder = std::function<QByteArray(const QUrl &, int)>;

    bool autoFinish = true;
    int requests = 0;
    bool firstRequestAborted = false;
    Responder responder = [](const QUrl &, int) {
        return QByteArrayLiteral(R"({"syncedLyrics":"[00:01.00]Injected"})");
    };

    FixtureReply *replyAt(int index) const
    {
        return index >= 0 && index < m_replies.size() ? m_replies.at(index) : nullptr;
    }

protected:
    QNetworkReply *createRequest(Operation operation, const QNetworkRequest &request,
                                 QIODevice *outgoingData = nullptr) override
    {
        Q_UNUSED(operation)
        Q_UNUSED(outgoingData)
        ++requests;
        auto *reply = new FixtureReply(request,
                                       requests == 1 ? &firstRequestAborted : nullptr,
                                       this);
        m_replies.append(reply);
        if (autoFinish) {
            QTimer::singleShot(0, reply, [this, reply]() {
                if (!reply->completed() && !reply->aborted())
                    reply->complete(responder(reply->url(), m_replies.indexOf(reply)));
            });
        }
        return reply;
    }

private:
    QList<FixtureReply *> m_replies;
};

class LyricsTest : public QObject {
    Q_OBJECT

private slots:
    void parsesNormalAndMillisecondTimestamps();
    void parsesMultipleTimestampsWithSharedText();
    void parsesSortingOffsetAndPlainLyrics();
    void ignoresMalformedLrcMetadata();
    void mapsTimelineAndOffset();
    void localLyricsUseReadableFilename();
    void cacheUsesProviderIdentityAndDuration();
    void fallsBackToNetEaseWithScoring();
    void plainLyricsAreUnsynced();
    void reportsEmptyAndErrorStates();
    void deduplicatesSameTrackButRefreshes();
    void staleReplyCannotReplaceTrack();
    void rapidSwitchingAndClearTrackInvalidateReplies();
};

namespace {

void configureTemporaryPaths(const QString &root,
                             ScopedEnvironment &cacheHome,
                             ScopedEnvironment &dataHome,
                             ScopedEnvironment &localDirectory)
{
    Q_UNUSED(cacheHome)
    Q_UNUSED(dataHome)
    Q_UNUSED(localDirectory)
    qputenv("XDG_CACHE_HOME", QFile::encodeName(root + QStringLiteral("/cache")));
    qputenv("XDG_DATA_HOME", QFile::encodeName(root + QStringLiteral("/data")));
    qputenv("CLAVIS_LYRICS_DIR", QFile::encodeName(root + QStringLiteral("/local")));
    QVERIFY(QDir().mkpath(root + QStringLiteral("/local")));
}

void waitForRequests(const FixtureNetworkAccessManager &manager, int count)
{
    QTRY_VERIFY_WITH_TIMEOUT(manager.requests >= count, 1500);
}

QByteArray lrclibResponse(const QString &id, const QString &lyrics)
{
    QJsonObject object{
        {QStringLiteral("id"), id},
        {QStringLiteral("trackName"), QStringLiteral("title")},
        {QStringLiteral("artistName"), QStringLiteral("artist")},
        {QStringLiteral("albumName"), QStringLiteral("album")},
        {QStringLiteral("duration"), 120.0},
        {QStringLiteral("syncedLyrics"), lyrics},
    };
    return QJsonDocument(object).toJson(QJsonDocument::Compact);
}

} // namespace

void LyricsTest::parsesNormalAndMillisecondTimestamps()
{
    Lyrics lyrics;
    const QVariantList lines = lyrics.parseLrc(
        QStringLiteral("[1:02]minute\n[00:03.1]tenths\n[00:04.125]milliseconds\n"));
    QCOMPARE(lines.size(), 3);
    QCOMPARE(lines.at(0).toMap().value(QStringLiteral("time")).toDouble(), 3.1);
    QCOMPARE(lines.at(1).toMap().value(QStringLiteral("time")).toDouble(), 4.125);
    QCOMPARE(lines.at(2).toMap().value(QStringLiteral("time")).toDouble(), 62.0);
}

void LyricsTest::parsesMultipleTimestampsWithSharedText()
{
    Lyrics lyrics;
    const QVariantList lines = lyrics.parseLrc(
        QStringLiteral("[00:10.00][00:02.50]second\n[00:01.00]first\n"));
    QCOMPARE(lines.size(), 3);
    QCOMPARE(lines.at(0).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("first"));
    QCOMPARE(lines.at(1).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("second"));
    QCOMPARE(lines.at(2).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("second"));
    QCOMPARE(lines.at(1).toMap().value(QStringLiteral("time")).toDouble(), 2.5);
    QCOMPARE(lines.at(2).toMap().value(QStringLiteral("time")).toDouble(), 10.0);
}

void LyricsTest::parsesSortingOffsetAndPlainLyrics()
{
    Lyrics lyrics;
    const QVariantList lines = lyrics.parseLrc(
        QStringLiteral("[offset:500]\n[00:01.20]hello\nplain line\n[ti:title]\n"), -200.0);
    QCOMPARE(lines.size(), 2);
    QCOMPARE(lines.at(0).toMap().value(QStringLiteral("time")).toDouble(), 1.5);
    QCOMPARE(lines.at(1).toMap().value(QStringLiteral("time")).toDouble(), -1.0);
    QCOMPARE(lines.at(1).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("plain line"));
}

void LyricsTest::ignoresMalformedLrcMetadata()
{
    Lyrics lyrics;
    const QVariantList lines = lyrics.parseLrc(
        QStringLiteral("[00:xx]broken\n[ar:artist]\n[00:02]valid\n[bad:tag]plain\n"));
    QCOMPARE(lines.size(), 2);
    QCOMPARE(lines.at(0).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("valid"));
    QCOMPARE(lines.at(1).toMap().value(QStringLiteral("text")).toString(), QStringLiteral("[bad:tag]plain"));
}

void LyricsTest::mapsTimelineAndOffset()
{
    Lyrics lyrics;
    lyrics.setOffsetMs(250.0);
    FixtureNetworkAccessManager manager;
    manager.autoFinish = false;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("title"));
    waitForRequests(manager, 1);
    manager.replyAt(0)->complete(QByteArrayLiteral(R"({"syncedLyrics":"[00:01.00]one\n[00:03.00]two"})"));
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1000);
    QCOMPARE(lyrics.indexForTime(1.24), -1);
    QCOMPARE(lyrics.indexForTime(1.25), 0);
    QCOMPARE(lyrics.indexForTime(4.0), 1);
    QCOMPARE(lyrics.timeForIndex(1), 3.25);
    QCOMPARE(lyrics.timeForIndex(4), -1.0);
}

void LyricsTest::localLyricsUseReadableFilename()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment localDirectory("CLAVIS_LYRICS_DIR");
    configureTemporaryPaths(temporary.path(), cacheHome, dataHome, localDirectory);

    const QString path = QDir(temporary.path() + QStringLiteral("/local"))
                             .filePath(QStringLiteral("Artist - Title.lrc"));
    QFile local(path);
    QVERIFY(local.open(QIODevice::WriteOnly));
    local.write("[00:01.00]local line\n");
    local.close();

    FixtureNetworkAccessManager manager;
    Lyrics lyrics;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("Artist"), QStringLiteral("Title"));
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1000);
    QCOMPARE(manager.requests, 0);
    QCOMPARE(lyrics.provider(), QStringLiteral("Local"));
    QCOMPARE(lyrics.lyrics().first().toMap().value(QStringLiteral("text")).toString(),
             QStringLiteral("local line"));
}

void LyricsTest::cacheUsesProviderIdentityAndDuration()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment localDirectory("CLAVIS_LYRICS_DIR");
    configureTemporaryPaths(temporary.path(), cacheHome, dataHome, localDirectory);

    FixtureNetworkAccessManager firstManager;
    firstManager.responder = [](const QUrl &, int) {
        return lrclibResponse(QStringLiteral("42"), QStringLiteral("[00:01.00]cached"));
    };
    Lyrics first;
    first.setNetworkAccessManager(&firstManager);
    first.setTrack(QStringLiteral("artist"), QStringLiteral("title"), QStringLiteral("album"), 120.0);
    QTRY_VERIFY_WITH_TIMEOUT(first.hasLyrics(), 1000);
    QCOMPARE(first.selectedCandidate().value(QStringLiteral("id")).toString(), QStringLiteral("42"));

    FixtureNetworkAccessManager cacheManager;
    Lyrics cached;
    cached.setNetworkAccessManager(&cacheManager);
    cached.setTrack(QStringLiteral("artist"), QStringLiteral("title"), QStringLiteral("album"), 120.0);
    QTRY_VERIFY_WITH_TIMEOUT(cached.hasLyrics(), 1000);
    QCOMPARE(cacheManager.requests, 0);
    QCOMPARE(cached.provider(), QStringLiteral("LRCLIB"));
    QCOMPARE(cached.selectedCandidate().value(QStringLiteral("id")).toString(), QStringLiteral("42"));

    cacheManager.responder = [](const QUrl &, int) {
        return lrclibResponse(QStringLiteral("43"), QStringLiteral("[00:02.00]refreshed"));
    };
    cached.refresh();
    waitForRequests(cacheManager, 1);
    QTRY_COMPARE_WITH_TIMEOUT(cached.selectedCandidate().value(QStringLiteral("id")).toString(),
                              QStringLiteral("43"), 1000);

    FixtureNetworkAccessManager differentDurationManager;
    Lyrics differentDuration;
    differentDuration.setNetworkAccessManager(&differentDurationManager);
    differentDuration.setTrack(QStringLiteral("artist"), QStringLiteral("title"), QStringLiteral("album"), 121.0);
    waitForRequests(differentDurationManager, 1);
}

void LyricsTest::fallsBackToNetEaseWithScoring()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment localDirectory("CLAVIS_LYRICS_DIR");
    configureTemporaryPaths(temporary.path(), cacheHome, dataHome, localDirectory);

    FixtureNetworkAccessManager manager;
    manager.responder = [](const QUrl &url, int) {
        if (url.host() == QStringLiteral("lrclib.net"))
            return QByteArrayLiteral(R"({"syncedLyrics":""})");
        if (url.path().contains(QStringLiteral("/search/"))) {
            return QByteArray(R"JSON({"result":{"songs":[
                {"id":1,"name":"Title (Remix)","artists":[{"name":"artist"}],"album":{"name":"album"},"dt":120000},
                {"id":2,"name":"Title","artists":[{"name":"artist"}],"album":{"name":"album"},"dt":120000}
            ]}})JSON");
        }
        QUrlQuery query(url);
        if (query.queryItemValue(QStringLiteral("id")) == QStringLiteral("2"))
            return QByteArrayLiteral(R"({"lrc":{"lyric":"[00:02.00]best match"}})");
        return QByteArrayLiteral(R"({"lrc":{"lyric":""}})");
    };

    Lyrics lyrics;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("Title"), QStringLiteral("album"), 120.0);
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1500);
    QCOMPARE(lyrics.provider(), QStringLiteral("NetEase"));
    QCOMPARE(lyrics.selectedCandidate().value(QStringLiteral("id")).toString(), QStringLiteral("2"));
    QVERIFY(lyrics.candidates().size() >= 2);
    QCOMPARE(lyrics.lyrics().first().toMap().value(QStringLiteral("text")).toString(),
             QStringLiteral("best match"));
}

void LyricsTest::plainLyricsAreUnsynced()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment localDirectory("CLAVIS_LYRICS_DIR");
    configureTemporaryPaths(temporary.path(), cacheHome, dataHome, localDirectory);

    FixtureNetworkAccessManager manager;
    manager.responder = [](const QUrl &, int) {
        return QByteArrayLiteral(R"({"plainLyrics":"first line\nsecond line"})");
    };
    Lyrics lyrics;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("title"));
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1000);
    QVERIFY(!lyrics.hasSynchronizedLyrics());
    QCOMPARE(lyrics.indexForTime(10.0), -1);
    QCOMPARE(lyrics.timeForIndex(0), -1.0);
    QCOMPARE(lyrics.status(), QStringLiteral("ready"));
}

void LyricsTest::reportsEmptyAndErrorStates()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment localDirectory("CLAVIS_LYRICS_DIR");
    configureTemporaryPaths(temporary.path(), cacheHome, dataHome, localDirectory);

    FixtureNetworkAccessManager emptyManager;
    emptyManager.responder = [](const QUrl &url, int) {
        if (url.host() == QStringLiteral("lrclib.net"))
            return QByteArrayLiteral(R"({"syncedLyrics":""})");
        return QByteArrayLiteral(R"({"result":{"songs":[]}})");
    };
    Lyrics emptyLyrics;
    emptyLyrics.setNetworkAccessManager(&emptyManager);
    emptyLyrics.setTrack(QStringLiteral("artist"), QStringLiteral("missing"));
    QTRY_COMPARE_WITH_TIMEOUT(emptyLyrics.status(), QStringLiteral("empty"), 1500);
    QVERIFY(!emptyLyrics.loading());
    QVERIFY(!emptyLyrics.hasLyrics());

    FixtureNetworkAccessManager errorManager;
    errorManager.responder = [](const QUrl &, int) {
        return QByteArrayLiteral("not json");
    };
    Lyrics errorLyrics;
    errorLyrics.setNetworkAccessManager(&errorManager);
    errorLyrics.setTrack(QStringLiteral("artist"), QStringLiteral("broken"));
    QTRY_COMPARE_WITH_TIMEOUT(errorLyrics.status(), QStringLiteral("error"), 1500);
    QVERIFY(!errorLyrics.loading());
    QVERIFY(!errorLyrics.error().isEmpty());
}

void LyricsTest::deduplicatesSameTrackButRefreshes()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment localDirectory("CLAVIS_LYRICS_DIR");
    configureTemporaryPaths(temporary.path(), cacheHome, dataHome, localDirectory);

    FixtureNetworkAccessManager manager;
    manager.autoFinish = false;
    Lyrics lyrics;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("title"));
    waitForRequests(manager, 1);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("title"));
    QTest::qWait(120);
    QCOMPARE(manager.requests, 1);
    manager.replyAt(0)->complete(QByteArrayLiteral(R"({"syncedLyrics":"[00:01.00]first"})"));
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1000);

    lyrics.refresh();
    waitForRequests(manager, 2);
    QVERIFY(lyrics.loading());
    manager.replyAt(1)->complete(QByteArrayLiteral(R"({"syncedLyrics":"[00:02.00]refreshed"})"));
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1000);
    QCOMPARE(lyrics.lyrics().first().toMap().value(QStringLiteral("text")).toString(),
             QStringLiteral("refreshed"));
    QCOMPARE(manager.requests, 2);
}

void LyricsTest::staleReplyCannotReplaceTrack()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment localDirectory("CLAVIS_LYRICS_DIR");
    configureTemporaryPaths(temporary.path(), cacheHome, dataHome, localDirectory);

    FixtureNetworkAccessManager manager;
    manager.autoFinish = false;
    Lyrics lyrics;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("first"));
    waitForRequests(manager, 1);
    FixtureReply *firstReply = manager.replyAt(0);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("second"));
    firstReply->complete(QByteArrayLiteral(R"({"syncedLyrics":"[00:01.00]stale first"})"));
    waitForRequests(manager, 2);
    QVERIFY(manager.firstRequestAborted);
    manager.replyAt(1)->complete(QByteArrayLiteral(R"({"syncedLyrics":"[00:02.00]second"})"));
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1000);
    QCOMPARE(lyrics.trackTitle(), QStringLiteral("second"));
    QCOMPARE(lyrics.lyrics().first().toMap().value(QStringLiteral("text")).toString(),
             QStringLiteral("second"));
}

void LyricsTest::rapidSwitchingAndClearTrackInvalidateReplies()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    ScopedEnvironment cacheHome("XDG_CACHE_HOME");
    ScopedEnvironment dataHome("XDG_DATA_HOME");
    ScopedEnvironment localDirectory("CLAVIS_LYRICS_DIR");
    configureTemporaryPaths(temporary.path(), cacheHome, dataHome, localDirectory);

    FixtureNetworkAccessManager manager;
    manager.autoFinish = false;
    Lyrics lyrics;
    lyrics.setNetworkAccessManager(&manager);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("A"));
    waitForRequests(manager, 1);
    FixtureReply *firstReply = manager.replyAt(0);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("B"));
    firstReply->complete(QByteArrayLiteral(R"({"syncedLyrics":"[00:01.00]stale A"})"));
    waitForRequests(manager, 2);
    FixtureReply *secondReply = manager.replyAt(1);
    lyrics.setTrack(QStringLiteral("artist"), QStringLiteral("C"));
    secondReply->complete(QByteArrayLiteral(R"({"syncedLyrics":"[00:02.00]stale B"})"));
    waitForRequests(manager, 3);
    manager.replyAt(2)->complete(QByteArrayLiteral(R"({"syncedLyrics":"[00:03.00]C"})"));
    QTRY_VERIFY_WITH_TIMEOUT(lyrics.hasLyrics(), 1000);
    QCOMPARE(lyrics.trackTitle(), QStringLiteral("C"));
    QCOMPARE(lyrics.lyrics().first().toMap().value(QStringLiteral("text")).toString(), QStringLiteral("C"));

    lyrics.clearTrack();
    QCOMPARE(lyrics.status(), QStringLiteral("idle"));
    QVERIFY(!lyrics.loading());
    QVERIFY(!lyrics.hasLyrics());
    QVERIFY(lyrics.lyrics().isEmpty());
}

QTEST_MAIN(LyricsTest)

#include "lyrics_test.moc"
