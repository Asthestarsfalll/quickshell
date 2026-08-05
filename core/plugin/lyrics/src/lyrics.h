#pragma once

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class Lyrics : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Lyrics)
    QML_SINGLETON

    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY lyricsChanged)
    Q_PROPERTY(QVariantList lyrics READ lyrics NOTIFY lyricsChanged)
    Q_PROPERTY(QVariantList candidates READ candidates NOTIFY candidatesChanged)
    Q_PROPERTY(QString provider READ provider NOTIFY providerChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(double offsetMs READ offsetMs WRITE setOffsetMs NOTIFY offsetMsChanged)

public:
    explicit Lyrics(QObject *parent = nullptr);

    // Tests and embedders may provide a deterministic HTTP transport before
    // starting a request. The QML singleton keeps the default manager.
    void setNetworkAccessManager(QNetworkAccessManager *manager);

    bool loading() const { return m_loading; }
    bool hasLyrics() const { return !m_lyrics.isEmpty(); }
    QVariantList lyrics() const { return m_lyrics; }
    QVariantList candidates() const { return m_candidates; }
    QString provider() const { return m_provider; }
    QString error() const { return m_error; }
    double offsetMs() const { return m_offsetMs; }
    void setOffsetMs(double offsetMs);

    Q_INVOKABLE void setTrack(const QString &artist, const QString &title,
                              const QString &album = {}, double duration = 0.0);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void requestCandidates();
    Q_INVOKABLE void selectCandidate(int index);
    Q_INVOKABLE QVariantList parseLrc(const QString &text, double offsetMs = 0.0) const;
    Q_INVOKABLE int indexForTime(double positionSeconds) const;
    Q_INVOKABLE double timeForIndex(int index) const;

signals:
    void loadingChanged();
    void lyricsChanged();
    void candidatesChanged();
    void providerChanged();
    void errorChanged();
    void offsetMsChanged();

private:
    enum class ReplyKind {
        Track,
        Search,
        NetEaseSearch,
        NetEaseLyric,
    };

    QNetworkAccessManager m_defaultManager;
    QNetworkAccessManager *m_manager = &m_defaultManager;
    QNetworkReply *m_reply = nullptr;
    ReplyKind m_replyKind = ReplyKind::Track;
    quint64 m_generation = 0;
    bool m_loading = false;
    bool m_autoFallback = false;
    QVariantList m_lyrics;
    QVariantList m_candidates;
    QString m_provider;
    QString m_error;
    QString m_artist;
    QString m_title;
    QString m_album;
    double m_duration = 0.0;
    double m_offsetMs = 0.0;
    QString m_pendingCandidateProvider;

    void setLoading(bool loading);
    void setProvider(const QString &provider);
    void setError(const QString &error);
    void clearLyrics();
    void finishLyrics(const QVariantList &lines, const QString &provider,
                      const QString &cachePayload = {});
    void startTrackRequest();
    void startSearchRequest();
    void startNetEaseSearch();
    void startNetEaseLyric(const QVariantMap &candidate);
    void startReply(const QUrl &url, ReplyKind kind);
    void handleReply(QNetworkReply *reply, ReplyKind kind, quint64 generation);
    void handleTrackJson(const QJsonObject &json, const QString &provider);
    void handleSearchJson(const QJsonDocument &document, const QString &provider);
    void cacheLyrics(const QString &provider, const QString &synced, const QString &plain);
    bool loadCachedLyrics();
    bool loadLocalLyrics();
    QString cacheKey() const;
    QString cacheDirectory() const;
    QString localDirectory() const;
    QUrl lrclibUrl(bool search) const;
};
