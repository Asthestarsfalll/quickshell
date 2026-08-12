#pragma once

#include <QHash>
#include <QMutex>
#include <QObject>
#include <QSharedPointer>
#include <QString>
#include <QThreadPool>
#include <QVector>
#include <QtQml/qqmlregistration.h>

struct WallpaperAnalysisData;

class WallpaperAnalysisResult : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("WallpaperAnalysisResult is produced by WallpaperAnalyzer")

    Q_PROPERTY(bool valid READ valid CONSTANT)
    Q_PROPERTY(int analysisWidth READ analysisWidth CONSTANT)
    Q_PROPERTY(int analysisHeight READ analysisHeight CONSTANT)
    Q_PROPERTY(double canvasWidth READ canvasWidth CONSTANT)
    Q_PROPERTY(double canvasHeight READ canvasHeight CONSTANT)
    Q_PROPERTY(double minBusyScore READ minBusyScore CONSTANT)
    Q_PROPERTY(double maxBusyScore READ maxBusyScore CONSTANT)
    Q_PROPERTY(QString errorString READ errorString CONSTANT)

  public:
    explicit WallpaperAnalysisResult(const QSharedPointer<const WallpaperAnalysisData> &data,
                                     QObject *parent = nullptr);

    bool valid() const;
    int analysisWidth() const;
    int analysisHeight() const;
    double canvasWidth() const;
    double canvasHeight() const;
    double minBusyScore() const;
    double maxBusyScore() const;
    QString errorString() const;

    Q_INVOKABLE double busyScore(double x, double y, double width, double height) const;

  private:
    QSharedPointer<const WallpaperAnalysisData> m_data;
};

class WallpaperAnalyzer : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingCountChanged)

  public:
    explicit WallpaperAnalyzer(QObject *parent = nullptr);
    ~WallpaperAnalyzer() override;

    int pendingCount() const;

    Q_INVOKABLE void request(const QString &requestKey, int generation, const QString &sourcePath,
                             int canvasWidth, int canvasHeight, const QString &fillMode, int imageWidth,
                             int imageHeight);

  signals:
    void pendingCountChanged();
    void analysisReady(const QString &requestKey, int generation, WallpaperAnalysisResult *result);

  private:
    struct AnalysisWaiter {
        QString requestKey;
        int generation = 0;
    };

    QString cacheKey(const QString &sourcePath, int canvasWidth, int canvasHeight, const QString &fillMode,
                     int imageWidth, int imageHeight) const;

  public:
    void finish(const QString &key, const QSharedPointer<const WallpaperAnalysisData> &data);

  private:
    mutable QMutex m_mutex;
    QThreadPool m_threadPool;
    QHash<QString, QSharedPointer<const WallpaperAnalysisData>> m_cache;
    QHash<QString, QVector<AnalysisWaiter>> m_inFlight;
    QHash<QString, int> m_latestGeneration;
    int m_pendingCount = 0;
};
