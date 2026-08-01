#include "management_command.h"

#include "clavis_release.h"
#include "runtime/clavis_paths.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QProcess>

using Clavis::Runtime::ClavisPaths;

namespace {

QString currentReleaseRoot()
{
    const QString configured = QString::fromLocal8Bit(
        qgetenv("CLAVIS_RELEASE_ROOT")).trimmed();
    if (!configured.isEmpty() && QDir::isAbsolutePath(configured))
        return QDir::cleanPath(configured);

    QDir executableDir(QCoreApplication::applicationDirPath());
    if (executableDir.dirName() == QStringLiteral("bin")) {
        executableDir.cdUp();
        if (QFileInfo::exists(executableDir.filePath(QStringLiteral("release.json"))))
            return executableDir.absolutePath();
    }
    return {};
}

QString managerPath(const QString &releaseRoot)
{
    const QString overridePath = QString::fromLocal8Bit(
        qgetenv("CLAVIS_MANAGER")).trimmed();
    if (!overridePath.isEmpty() && QDir::isAbsolutePath(overridePath))
        return QDir::cleanPath(overridePath);

    if (!releaseRoot.isEmpty()) {
        const QString installed = QDir(releaseRoot).filePath(
            QStringLiteral("share/clavis/libexec/clavis-manager.py"));
        return installed;
    }
    return {};
}

} // namespace

CommandResult ManagementCommand::run(const QString &command,
                                     const QStringList &arguments) const
{
    const QString releaseRoot = currentReleaseRoot();
    const QString manager = managerPath(releaseRoot);
    if (manager.isEmpty() || !QFileInfo(manager).isFile()) {
        return {
            1,
            false,
            {},
            manager.isEmpty()
                ? QStringLiteral(
                    "key: release management requires an installed Clavis "
                    "release (or an absolute CLAVIS_MANAGER override)")
                : QStringLiteral("key: Clavis manager is missing: %1").arg(manager),
            true,
        };
    }

    QProcess process;
    process.setProgram(QStringLiteral("python3"));
    process.setArguments(QStringList{manager, command} + arguments);
    process.setProcessEnvironment(
        ClavisPaths::fromEnvironment().processEnvironment(releaseRoot));
    process.setProcessChannelMode(QProcess::ForwardedChannels);
    process.start();
    if (!process.waitForStarted()) {
        return {
            1,
            false,
            {},
            QStringLiteral("key: unable to start Clavis manager: %1")
                .arg(process.errorString()),
            true,
        };
    }
    process.waitForFinished(-1);
    if (process.exitStatus() != QProcess::NormalExit)
        return {128, false, {}, {}, true, true};
    return {process.exitCode(), false, {}, {}, process.exitCode() != 0, true};
}
