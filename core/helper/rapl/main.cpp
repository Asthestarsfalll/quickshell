#include <algorithm>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <fstream>
#include <iostream>
#include <optional>
#include <string>
#include <string_view>
#include <sys/socket.h>
#include <unistd.h>
#include <vector>

namespace {

constexpr int ProtocolVersion = 1;
constexpr std::string_view PowercapRoot = "/sys/class/powercap";

std::string jsonEscape(std::string_view value)
{
    std::string result;
    for (const char character : value) {
        if (character == '"' || character == '\\')
            result.push_back('\\');
        if (character == '\n') {
            result += "\\n";
            continue;
        }
        result.push_back(character);
    }
    return result;
}

std::optional<std::string> readText(const std::string &path)
{
    errno = 0;
    std::ifstream input(path);
    if (!input)
        return std::nullopt;
    std::string value;
    std::getline(input, value);
    return value;
}

std::optional<long long> readInteger(const std::string &path)
{
    const auto text = readText(path);
    if (!text)
        return std::nullopt;
    try {
        std::size_t consumed = 0;
        const long long value = std::stoll(*text, &consumed, 10);
        if (consumed != text->size() || value < 0)
            return std::nullopt;
        return value;
    } catch (...) {
        return std::nullopt;
    }
}

std::vector<std::string> raplPackages()
{
    std::vector<std::string> result;
    DIR *directory = ::opendir(PowercapRoot.data());
    if (!directory)
        return result;
    while (dirent *entry = ::readdir(directory)) {
        const std::string name(entry->d_name);
        if (name == "." || name == "..")
            continue;
        if (name.rfind("intel-rapl:", 0) != 0)
            continue;
        if (std::count(name.begin(), name.end(), ':') != 1)
            continue;
        result.push_back(std::string(PowercapRoot) + "/" + name);
    }
    ::closedir(directory);
    std::sort(result.begin(), result.end());
    return result;
}

std::string snapshot()
{
    const std::vector<std::string> packages = raplPackages();
    if (packages.empty()) {
        return "{\"protocol\":1,\"ok\":false,\"status\":\"unsupported\"}\n";
    }

    std::string selected = packages.front();
    for (const std::string &candidate : packages) {
        const auto name = readText(candidate + "/name");
        if (name && name->find("package") != std::string::npos) {
            selected = candidate;
            break;
        }
    }
    const auto energy = readInteger(selected + "/energy_uj");
    const int energyError = errno;
    if (!energy) {
        const std::string status = energyError == EACCES || energyError == EPERM
            ? "permission_denied"
            : "read_failed";
        return "{\"protocol\":1,\"ok\":false,\"status\":\"" + status
            + "\",\"error\":\"" + jsonEscape(std::strerror(energyError)) + "\"}\n";
    }
    const auto range = readInteger(selected + "/max_energy_range_uj");

    const auto now = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
    return "{\"protocol\":1,\"ok\":true,\"status\":\"readable\","
        "\"energyUj\":" + std::to_string(*energy)
        + ",\"maxEnergyRangeUj\":" + std::to_string(range.value_or(0))
        + ",\"monotonicNs\":" + std::to_string(now) + "}\n";
}

bool writeAll(int descriptor, std::string_view data)
{
    std::size_t offset = 0;
    while (offset < data.size()) {
        const ssize_t written = ::write(
            descriptor, data.data() + offset, data.size() - offset);
        if (written < 0 && errno == EINTR)
            continue;
        if (written <= 0)
            return false;
        offset += static_cast<std::size_t>(written);
    }
    return true;
}

int serve()
{
    const char *listenPid = std::getenv("LISTEN_PID");
    const char *listenFds = std::getenv("LISTEN_FDS");
    if (!listenPid || !listenFds
        || std::strtol(listenPid, nullptr, 10) != static_cast<long>(::getpid())
        || std::strtol(listenFds, nullptr, 10) != 1) {
        std::cerr << "clavis-rapl-helper: exactly one systemd socket is required\n";
        return 78;
    }

    constexpr int socketDescriptor = 3;
    std::signal(SIGPIPE, SIG_IGN);
    for (;;) {
        const int client = ::accept4(socketDescriptor, nullptr, nullptr, SOCK_CLOEXEC);
        if (client < 0) {
            if (errno == EINTR)
                continue;
            std::cerr << "clavis-rapl-helper: accept failed: "
                      << std::strerror(errno) << '\n';
            return 1;
        }
        const std::string response = snapshot();
        writeAll(client, response);
        ::close(client);
    }
}

void usage()
{
    std::cerr << "Usage: clavis-rapl-helper --version|--once|--serve\n";
}

} // namespace

int main(int argc, char **argv)
{
    if (argc != 2) {
        usage();
        return 2;
    }
    const std::string_view command(argv[1]);
    if (command == "--version") {
        std::cout << "{\"product\":\"clavis-rapl-helper\",\"protocol\":"
                  << ProtocolVersion << "}\n";
        return 0;
    }
    if (command == "--once") {
        const std::string response = snapshot();
        std::cout << response;
        return response.find("\"ok\":true") == std::string::npos ? 1 : 0;
    }
    if (command == "--serve")
        return serve();
    usage();
    return 2;
}
