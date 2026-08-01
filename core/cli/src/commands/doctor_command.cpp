#include "doctor_command.h"

#include "recording/dependency_probe.h"
#include "runtime/rapl_helper_client.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>

using namespace Clavis::Recording;

namespace {

CommandResult cpuPowerDoctor(const QStringList &arguments)
{
    const bool jsonRequested = arguments.contains(QStringLiteral("--json"));
    for (const QString &argument : arguments) {
        if (argument != QStringLiteral("--json")) {
            return {
                2,
                jsonRequested,
                {},
                QStringLiteral("Unknown key doctor cpu-power option: %1")
                    .arg(argument),
                true,
            };
        }
    }

    QString energyPath;
    const QDir powercap(QStringLiteral("/sys/class/powercap"));
    const QStringList packages = powercap.entryList(
        QStringList{QStringLiteral("intel-rapl:*")},
        QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : packages) {
        if (entry.count(QLatin1Char(':')) != 1)
            continue;
        const QString candidate = powercap.absoluteFilePath(entry)
            + QStringLiteral("/energy_uj");
        if (QFileInfo::exists(candidate)) {
            energyPath = candidate;
            break;
        }
    }

    QString directStatus = QStringLiteral("unsupported");
    if (!energyPath.isEmpty()) {
        QFile energy(energyPath);
        if (!energy.open(QIODevice::ReadOnly)) {
            directStatus = !QFileInfo(energyPath).isReadable()
                ? QStringLiteral("permission_denied")
                : QStringLiteral("read_failed");
        } else {
            bool ok = false;
            energy.readAll().trimmed().toLongLong(&ok);
            directStatus = ok
                ? QStringLiteral("readable")
                : QStringLiteral("read_failed");
        }
    }

    const Clavis::Runtime::RaplHelperSnapshot helper =
        Clavis::Runtime::RaplHelperClient::query();
    const bool helperInstalled = QFileInfo::exists(
        QStringLiteral("/usr/local/libexec/clavis-rapl-helper"));
    QString helperStatus = helper.status;
    if (helperStatus == QStringLiteral("helper_missing") && !helperInstalled)
        helperStatus = QStringLiteral("helper_not_installed");

    QString status = directStatus == QStringLiteral("unsupported")
        ? QStringLiteral("unsupported")
        : directStatus == QStringLiteral("readable")
            ? QStringLiteral("supported_readable")
            : helper.energyMicroJoules
                ? QStringLiteral("supported_helper_readable")
                : directStatus == QStringLiteral("permission_denied")
                    ? QStringLiteral("supported_permission_denied")
                    : QStringLiteral("supported_read_failed");
    const bool available = directStatus == QStringLiteral("readable")
        || helper.energyMicroJoules.has_value();
    const QString message = status == QStringLiteral("unsupported")
        ? QStringLiteral("Intel RAPL is not exposed by this hardware or kernel.")
        : available
            ? QStringLiteral("CPU package power is readable.")
            : QStringLiteral(
                "CPU package power is unavailable, but all other key top metrics remain usable.");
    const QJsonObject object{
        {QStringLiteral("schemaVersion"), 1},
        {QStringLiteral("command"), QStringLiteral("doctor.cpu-power")},
        {QStringLiteral("ok"), available},
        {QStringLiteral("status"), status},
        {QStringLiteral("hardwareSupported"), !energyPath.isEmpty()},
        {QStringLiteral("energyPath"), energyPath},
        {QStringLiteral("directStatus"), directStatus},
        {QStringLiteral("helperInstalled"), helperInstalled},
        {QStringLiteral("helperStatus"), helperStatus},
        {QStringLiteral("helperProtocol"),
         Clavis::Runtime::RaplHelperClient::ProtocolVersion},
        {QStringLiteral("message"), message},
    };
    const QString text = QStringLiteral(
        "Clavis CPU power diagnostics:\n"
        "  status: %1\n"
        "  direct RAPL: %2\n"
        "  helper: %3\n"
        "  %4")
        .arg(status, directStatus, helperStatus, message);
    return {available ? 0 : 1, jsonRequested, object, text, !available};
}

} // namespace

CommandResult DoctorCommand::run(const QStringList &arguments) const
{
    if (!arguments.isEmpty()
        && arguments.first() == QStringLiteral("cpu-power")) {
        return cpuPowerDoctor(arguments.mid(1));
    }
    const bool jsonRequested = arguments.contains(QStringLiteral("--json"));
    QString outputDirectory;
    for (int index = 0; index < arguments.size(); ++index) {
        const QString argument = arguments.at(index);
        if (argument == QStringLiteral("--json"))
            continue;
        if (argument == QStringLiteral("--output") && index + 1 < arguments.size()) {
            outputDirectory = arguments.at(++index);
            continue;
        }
        const RecordingError error =
            makeError(QStringLiteral("usage_error"),
                      QStringLiteral("Unknown or incomplete doctor option: %1").arg(argument));
        return {
            UsageError,
            jsonRequested,
            {{QStringLiteral("schemaVersion"), SchemaVersion},
             {QStringLiteral("command"), QStringLiteral("doctor")},
             {QStringLiteral("ok"), false},
             {QStringLiteral("error"), error.toJson()}},
            error.message,
            true,
        };
    }
    if (outputDirectory.startsWith(QStringLiteral("~/")))
        outputDirectory.replace(0, 1, QDir::homePath());

    const QList<DependencyCheck> checks =
        DependencyProbe().run(outputDirectory, true);
    const bool ok = DependencyProbe::allPassed(checks);
    QJsonArray checksJson;
    QStringList lines;
    lines << QStringLiteral("Clavis Shell diagnostics:");
    for (const DependencyCheck &check : checks) {
        checksJson.append(check.toJson());
        lines << QStringLiteral("  [%1] %2: %3%4")
                     .arg(check.ok ? QStringLiteral("OK") : QStringLiteral("FAIL"),
                          check.name,
                          check.message,
                          check.path.isEmpty() ? QString()
                                               : QStringLiteral(" (%1)").arg(check.path));
    }

    const RecordingError error =
        ok ? RecordingError{}
           : makeError(QStringLiteral("doctor_failed"),
                       QStringLiteral("One or more required checks failed"));
    return {
        ok ? Success : DependencyFailure,
        jsonRequested,
        {{QStringLiteral("schemaVersion"), SchemaVersion},
         {QStringLiteral("command"), QStringLiteral("doctor")},
         {QStringLiteral("ok"), ok},
         {QStringLiteral("checks"), checksJson},
         {QStringLiteral("error"),
          error.isNull() ? QJsonValue(QJsonValue::Null) : QJsonValue(error.toJson())}},
        lines.join(QLatin1Char('\n')),
        !ok,
    };
}
