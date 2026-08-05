#include "lyrics.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QPointer>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrlQuery>
#include <algorithm>

namespace {
QString normalized(const QString &value)
{
    return value.normalized(QString::NormalizationForm_KC).simplified().toLower();
}

double fractionalSeconds(const QString &fraction)
{
    if (fraction.isEmpty())
        return 0.0;
    bool ok = false;
    const int value = fraction.toInt(&ok);
    if (!ok)
        return 0.0;
    if (fraction.size() == 1)
        return value / 10.0;
    if (fraction.size() == 2)
        return value / 100.0;
    return value / 1000.0;
}

QString firstString(const QJsonObject &object, const QStringList &keys)
{
    for (const QString &key : keys) {
        const QString value = object.value(key).toString();
        if (!value.isEmpty())
            return value;
    }
    return {};
}
}

Lyrics::Lyrics(QObject *parent)
    : QObject(parent)
{
}

void Lyrics::setNetworkAccessManager(QNetworkAccessManager *manager)
{
    if (m_reply)
        cancel();
    m_manager = manager ? manager : &m_defaultManager;
}

void Lyrics::setOffsetMs(double offsetMs)
{
    if (qFuzzyCompare(m_offsetMs + 1.0, offsetMs + 1.0))
        return;
    m_offsetMs = offsetMs;
    emit offsetMsChanged();
}

void Lyrics::setTrack(const QString &artist, const QString &title,
                      const QString &album, double duration)
{
    const QString nextArtist = artist.trimmed();
    const QString nextTitle = title.trimmed();
    const QString nextAlbum = album.trimmed();
    if (m_artist == nextArtist && m_title == nextTitle
        && m_album == nextAlbum && qFuzzyCompare(m_duration + 1.0, duration + 1.0)) {
        return;
    }

    cancel();
    ++m_generation;
    m_artist = nextArtist;
    m_title = nextTitle;
    m_album = nextAlbum;
    m_duration = duration > 0.0 ? duration : 0.0;
    m_autoFallback = true;
    m_candidates.clear();
    emit candidatesChanged();
    clearLyrics();
    setError({});
    setProvider({});

    if (m_title.isEmpty())
        return;

    if (loadLocalLyrics() || loadCachedLyrics())
        return;

    startTrackRequest();
}

void Lyrics::cancel()
{
    ++m_generation;
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    setLoading(false);
}

void Lyrics::requestCandidates()
{
    if (m_title.isEmpty() || m_loading)
        return;
    cancel();
    m_autoFallback = false;
    setError({});
    startSearchRequest();
}

void Lyrics::selectCandidate(int index)
{
    if (index < 0 || index >= m_candidates.size())
        return;
    const QVariantMap candidate = m_candidates.at(index).toMap();
    const QString synced = candidate.value("syncedLyrics").toString();
    const QString plain = candidate.value("plainLyrics").toString();
    const QString providerName = candidate.value("provider", "LRCLIB").toString();
    if (!synced.isEmpty() || !plain.isEmpty()) {
        finishLyrics(synced.isEmpty() ? parseLrc(plain, m_offsetMs)
                                      : parseLrc(synced, m_offsetMs),
                     providerName, synced.isEmpty() ? plain : synced);
        cacheLyrics(providerName, synced, plain);
        return;
    }
    startNetEaseLyric(candidate);
}

QVariantList Lyrics::parseLrc(const QString &text, double offsetMs) const
{
    QVariantList result;
    if (text.trimmed().isEmpty())
        return result;

    double fileOffsetMs = 0.0;
    const QRegularExpression offsetExpression(
        QStringLiteral(R"(\[offset\s*:\s*(-?\d+(?:\.\d+)?)\])"),
        QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch offsetMatch = offsetExpression.match(text);
    if (offsetMatch.hasMatch())
        fileOffsetMs = offsetMatch.captured(1).toDouble();

    const QRegularExpression timestampExpression(
        QStringLiteral(R"(\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\])"));
    const QStringList lines = text.split(QRegularExpression(QStringLiteral("\\r?\\n")));
    for (const QString &line : lines) {
        QRegularExpressionMatchIterator iterator = timestampExpression.globalMatch(line);
        QString lyricText = line;
        QList<double> timestamps;
        while (iterator.hasNext()) {
            const QRegularExpressionMatch match = iterator.next();
            const double seconds = match.captured(1).toDouble() * 60.0
                + match.captured(2).toDouble()
                + fractionalSeconds(match.captured(3));
            timestamps.append(seconds + (fileOffsetMs + offsetMs) / 1000.0);
            lyricText.remove(match.capturedStart(), match.capturedLength());
        }

        lyricText = lyricText.trimmed();
        if (!timestamps.isEmpty()) {
            for (const double time : timestamps) {
                if (!lyricText.isEmpty())
                    result.append(QVariantMap{{"time", time}, {"text", lyricText}});
            }
        } else if (!lyricText.isEmpty()
                   && !line.trimmed().startsWith("[ar:")
                   && !line.trimmed().startsWith("[ti:")
                   && !line.trimmed().startsWith("[al:")
                   && !line.trimmed().startsWith("[by:")
                   && !line.trimmed().startsWith("[re:")
                   && !line.trimmed().startsWith("[ve:")
                   && !line.trimmed().startsWith("[offset:")) {
            result.append(QVariantMap{{"time", -1.0}, {"text", lyricText}});
        }
    }

    std::sort(result.begin(), result.end(), [](const QVariant &left, const QVariant &right) {
        const double leftTime = left.toMap().value("time").toDouble();
        const double rightTime = right.toMap().value("time").toDouble();
        if (leftTime < 0.0 || rightTime < 0.0)
            return leftTime >= 0.0 && rightTime < 0.0;
        return leftTime < rightTime;
    });
    return result;
}

int Lyrics::indexForTime(double positionSeconds) const
{
    if (m_lyrics.isEmpty() || positionSeconds < 0.0)
        return -1;
    int index = -1;
    for (int i = 0; i < m_lyrics.size(); ++i) {
        const double time = m_lyrics.at(i).toMap().value("time", -1.0).toDouble();
        if (time < 0.0)
            continue;
        if (time <= positionSeconds)
            index = i;
        else
            break;
    }
    return index;
}

double Lyrics::timeForIndex(int index) const
{
    if (index < 0 || index >= m_lyrics.size())
        return -1.0;
    return m_lyrics.at(index).toMap().value("time", -1.0).toDouble();
}

void Lyrics::setLoading(bool loading)
{
    if (m_loading == loading)
        return;
    m_loading = loading;
    emit loadingChanged();
}

void Lyrics::setProvider(const QString &provider)
{
    if (m_provider == provider)
        return;
    m_provider = provider;
    emit providerChanged();
}

void Lyrics::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}

void Lyrics::clearLyrics()
{
    if (m_lyrics.isEmpty())
        return;
    m_lyrics.clear();
    emit lyricsChanged();
}

void Lyrics::finishLyrics(const QVariantList &lines, const QString &provider,
                          const QString &cachePayload)
{
    m_lyrics = lines;
    setProvider(provider);
    setError({});
    setLoading(false);
    emit lyricsChanged();
    Q_UNUSED(cachePayload)
}

void Lyrics::startTrackRequest()
{
    setLoading(true);
    startReply(lrclibUrl(false), ReplyKind::Track);
}

void Lyrics::startSearchRequest()
{
    setLoading(true);
    startReply(lrclibUrl(true), ReplyKind::Search);
}

void Lyrics::startNetEaseSearch()
{
    QUrl url(QStringLiteral("https://music.163.com/api/search/get/web"));
    QUrlQuery query;
    query.addQueryItem("s", m_artist + " " + m_title);
    query.addQueryItem("type", "1");
    query.addQueryItem("offset", "0");
    query.addQueryItem("total", "true");
    query.addQueryItem("limit", "10");
    url.setQuery(query);
    setLoading(true);
    startReply(url, ReplyKind::NetEaseSearch);
}

void Lyrics::startNetEaseLyric(const QVariantMap &candidate)
{
    const QString id = candidate.value("id").toString();
    if (id.isEmpty()) {
        setError(QStringLiteral("歌词候选缺少歌曲 ID"));
        return;
    }
    QUrl url(QStringLiteral("https://music.163.com/api/song/lyric"));
    QUrlQuery query;
    query.addQueryItem("id", id);
    query.addQueryItem("lv", "-1");
    query.addQueryItem("kv", "-1");
    query.addQueryItem("tv", "-1");
    url.setQuery(query);
    setLoading(true);
    startReply(url, ReplyKind::NetEaseLyric);
}

void Lyrics::startReply(const QUrl &url, ReplyKind kind)
{
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
    }
    m_replyKind = kind;
    const quint64 generation = m_generation;
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Clavis/lyrics"));
    m_reply = m_manager->get(request);
    QPointer<QNetworkReply> guardedReply = m_reply;
    connect(m_reply, &QNetworkReply::finished, this, [this, guardedReply, kind, generation]() {
        if (guardedReply)
            handleReply(guardedReply, kind, generation);
    });
}

void Lyrics::handleReply(QNetworkReply *reply, ReplyKind kind, quint64 generation)
{
    if (generation != m_generation) {
        reply->deleteLater();
        return;
    }
    if (m_reply == reply)
        m_reply = nullptr;

    const QByteArray body = reply->readAll();
    const bool requestFailed = reply->error() != QNetworkReply::NoError;
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
    const bool validJson = parseError.error == QJsonParseError::NoError;

    if (kind == ReplyKind::Track) {
        if (!requestFailed && validJson && document.isObject()) {
            handleTrackJson(document.object(), QStringLiteral("LRCLIB"));
            if (hasLyrics())
                return;
        }
        startNetEaseSearch();
        return;
    }
    if (kind == ReplyKind::Search) {
        if (!requestFailed && validJson)
            handleSearchJson(document, QStringLiteral("LRCLIB"));
        if (!m_candidates.isEmpty()) {
            setLoading(false);
            return;
        }
        startNetEaseSearch();
        return;
    }
    if (kind == ReplyKind::NetEaseSearch) {
        if (!requestFailed && validJson)
            handleSearchJson(document, QStringLiteral("NetEase"));
        if (m_autoFallback && !m_candidates.isEmpty()) {
            m_autoFallback = false;
            startNetEaseLyric(m_candidates.first().toMap());
            return;
        }
        setLoading(false);
        if (m_candidates.isEmpty())
            setError(status > 0 ? QStringLiteral("歌词服务返回 HTTP %1").arg(status)
                                : QStringLiteral("没有找到歌词"));
        else if (m_provider.isEmpty())
            setProvider(QStringLiteral("候选: LRCLIB / NetEase"));
        return;
    }
    if (kind == ReplyKind::NetEaseLyric) {
        if (!requestFailed && validJson && document.isObject()) {
            const QJsonObject lrc = document.object().value("lrc").toObject();
            const QJsonObject tlyric = document.object().value("tlyric").toObject();
            const QString synced = firstString(lrc, {"lyric"});
            const QString plain = firstString(tlyric, {"lyric"});
            if (!synced.isEmpty() || !plain.isEmpty()) {
                finishLyrics(synced.isEmpty() ? parseLrc(plain, m_offsetMs)
                                              : parseLrc(synced, m_offsetMs),
                             QStringLiteral("NetEase"));
                cacheLyrics(QStringLiteral("NetEase"), synced, plain);
                return;
            }
        }
        setLoading(false);
        setError(QStringLiteral("歌词内容不可用"));
    }
}

void Lyrics::handleTrackJson(const QJsonObject &json, const QString &providerName)
{
    const QString synced = firstString(json, {"syncedLyrics", "synced_lyrics"});
    const QString plain = firstString(json, {"plainLyrics", "plain_lyrics"});
    if (synced.isEmpty() && plain.isEmpty())
        return;
    finishLyrics(synced.isEmpty() ? parseLrc(plain, m_offsetMs)
                                  : parseLrc(synced, m_offsetMs),
                 providerName);
    cacheLyrics(providerName, synced, plain);
}

void Lyrics::handleSearchJson(const QJsonDocument &document, const QString &providerName)
{
    QVariantList next;
    if (providerName == QStringLiteral("LRCLIB")) {
        const QJsonArray array = document.array();
        for (const QJsonValue &value : array) {
            const QJsonObject item = value.toObject();
            next.append(QVariantMap{
                {"provider", providerName},
                {"id", item.value("id").toVariant()},
                {"title", firstString(item, {"trackName", "name"})},
                {"artist", firstString(item, {"artistName", "artist"})},
                {"album", firstString(item, {"albumName", "album"})},
                {"duration", item.value("duration").toVariant()},
                {"syncedLyrics", firstString(item, {"syncedLyrics", "synced_lyrics"})},
                {"plainLyrics", firstString(item, {"plainLyrics", "plain_lyrics"})},
            });
        }
    } else {
        const QJsonArray songs = document.object().value("result").toObject().value("songs").toArray();
        for (const QJsonValue &value : songs) {
            const QJsonObject item = value.toObject();
            const QJsonArray artists = item.value("artists").toArray();
            const QJsonObject firstArtist = artists.isEmpty() ? QJsonObject() : artists.first().toObject();
            next.append(QVariantMap{
                {"provider", providerName},
                {"id", QString::number(item.value("id").toVariant().toLongLong())},
                {"title", item.value("name").toString()},
                {"artist", firstArtist.value("name").toString()},
                {"album", item.value("album").toObject().value("name").toString()},
            });
        }
    }
    m_candidates = next;
    emit candidatesChanged();
}

void Lyrics::cacheLyrics(const QString &providerName, const QString &synced, const QString &plain)
{
    if (synced.isEmpty() && plain.isEmpty())
        return;
    const QString directory = cacheDirectory();
    if (directory.isEmpty() || !QDir().mkpath(directory))
        return;
    QFile file(directory + "/" + cacheKey() + ".json");
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    const QJsonObject object{
        {"artist", m_artist},
        {"title", m_title},
        {"album", m_album},
        {"provider", providerName},
        {"syncedLyrics", synced},
        {"plainLyrics", plain},
    };
    file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
}

bool Lyrics::loadCachedLyrics()
{
    QFile file(cacheDirectory() + "/" + cacheKey() + ".json");
    if (!file.open(QIODevice::ReadOnly))
        return false;
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !document.isObject())
        return false;
    const QJsonObject object = document.object();
    const QString synced = object.value("syncedLyrics").toString();
    const QString plain = object.value("plainLyrics").toString();
    if (synced.isEmpty() && plain.isEmpty())
        return false;
    finishLyrics(synced.isEmpty() ? parseLrc(plain, m_offsetMs)
                                  : parseLrc(synced, m_offsetMs),
                 object.value("provider").toString("cache"));
    return true;
}

bool Lyrics::loadLocalLyrics()
{
    const QString path = localDirectory() + "/" + cacheKey() + ".lrc";
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QString text = QString::fromUtf8(file.readAll());
    const QVariantList lines = parseLrc(text, m_offsetMs);
    if (lines.isEmpty())
        return false;
    finishLyrics(lines, QStringLiteral("Local"));
    return true;
}

QString Lyrics::cacheKey() const
{
    const QByteArray data = (normalized(m_artist) + "\n" + normalized(m_title)
                             + "\n" + normalized(m_album)).toUtf8();
    return QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
}

QString Lyrics::cacheDirectory() const
{
    const QByteArray configured = qgetenv("XDG_CACHE_HOME");
    const QString base = configured.isEmpty()
        ? QDir::homePath() + "/.cache"
        : QString::fromUtf8(configured);
    return base + "/clavis/lyrics";
}

QString Lyrics::localDirectory() const
{
    const QByteArray configured = qgetenv("CLAVIS_LYRICS_DIR");
    if (!configured.isEmpty())
        return QString::fromUtf8(configured);
    const QByteArray dataHome = qgetenv("XDG_DATA_HOME");
    const QString base = dataHome.isEmpty()
        ? QDir::homePath() + "/.local/share"
        : QString::fromUtf8(dataHome);
    return base + "/clavis/lyrics";
}

QUrl Lyrics::lrclibUrl(bool search) const
{
    const QUrl urlBase(QStringLiteral("https://lrclib.net/api/")
                       + (search ? QStringLiteral("search") : QStringLiteral("get")));
    QUrl url(urlBase);
    QUrlQuery query;
    if (search) {
        query.addQueryItem("q", m_artist + " " + m_title);
    } else {
        query.addQueryItem("artist_name", m_artist);
        query.addQueryItem("track_name", m_title);
        if (!m_album.isEmpty())
            query.addQueryItem("album_name", m_album);
        if (m_duration > 0.0)
            query.addQueryItem("duration", QString::number(m_duration, 'f', 3));
    }
    url.setQuery(query);
    return url;
}
