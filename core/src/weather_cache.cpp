#include "weather_cache.h"
#include "runtime/clavis_paths.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>

QString WeatherCache::defaultPath() {
    const QString cacheDir =
        Clavis::Runtime::ClavisPaths::fromEnvironment().cacheHome()
        + QStringLiteral("/weather");
    QDir().mkpath(cacheDir);
    return cacheDir + QStringLiteral("/forecast.json");
}

WeatherSnapshot WeatherCache::load(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    const auto document = QJsonDocument::fromJson(file.readAll());
    if (!document.isObject()) return {};
    auto snapshot = WeatherSnapshot::fromVariantMap(document.object().toVariantMap());
    if (snapshot.valid) snapshot.status = "cache";
    return snapshot;
}

bool WeatherCache::save(const QString &path, const WeatherSnapshot &snapshot) {
    QFile file(path);
    QDir().mkpath(QFileInfo(path).absolutePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    const QJsonDocument document = QJsonDocument::fromVariant(snapshot.toVariantMap());
    file.write(document.toJson(QJsonDocument::Compact));
    return true;
}
