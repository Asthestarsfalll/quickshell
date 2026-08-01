#pragma once

#include <QString>

#include <optional>

namespace Clavis::Runtime {

struct RaplHelperSnapshot {
    QString status;
    std::optional<qint64> energyMicroJoules;
    std::optional<qint64> rangeMicroJoules;
};

class RaplHelperClient {
public:
    static constexpr int ProtocolVersion = 1;
    static RaplHelperSnapshot query(const QString &socketPath = {});
    static QString defaultSocketPath();
};

} // namespace Clavis::Runtime
