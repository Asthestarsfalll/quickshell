# 依赖清单

`quickshell`、`key-cli`、`keytop` 和两个主题仓库各自检查自己的依赖。Shell 构建不再
因为 Keytop、ncurses、RAPL helper 或普通天气网络客户端缺失而失败。

## Quickshell 构建依赖

- CMake、C++17 compiler、pkg-config、Python 3；
- Qt 6 Core/Gui/Network/QML/Quick、ShaderTools、Tools；
- Qt 6 5Compat 与 Lottie（运行时 QML import）；
- PipeWire/Cava headers 与 libraries（仅用于内嵌音频可视化）；
- 项目仍保留的 Niri、MediaPalette、WeatherMap 和 M3Shapes native plugin 所需开发包。

`./setup.sh doctor` 分开显示 Build、Runtime 和 Optional runtime 依赖，不安装任何
软件。`./setup.sh deps --install` 仅在用户明确执行时通过 pacman 请求安装。

## key-cli 运行依赖

`key-cli` 是普通 CLI，不是 daemon。构建需要 CMake、C++17、Qt 6 Core/Gui/Network 和
Python 3；运行 Shell/IPC 时需要稳定的 Quickshell、systemd user 工具、`keytop`（仅
系统监测页面）以及相应功能的外部工具。天气请求由 `key weather` 的 Python provider
处理，使用 Open-Meteo/IP location 时才需要网络。

录屏、投屏、音量和剪贴板工具属于可降级运行依赖：gpu-screen-recorder、FFmpeg、
PipeWire/Pulse tools、wl-clipboard、cliphist、NetworkManager 等缺失时只禁用对应
控制，不应阻止无关的 Shell 启动。

## keytop 依赖

`keytop` 独立构建，需要 CMake、C++17、ncursesw 和 Linux `/proc`、`/sys` 接口；Qt
仅用于其现有运行时路径。它不链接 `key-cli` 或 Quickshell C++ target。RAPL 是可选
硬件/权限能力，读取失败时 CPU、内存、网络、磁盘和进程采样仍可用。

## 主题包依赖

`clavis-zsh-theme` 需要 CMake、C++17 和 zsh；Matugen 是 apply/hook 时的可选生成器。
`clavis-fcitx5-theme` 需要 Python 3；Matugen 与 Fcitx5 Classic UI 的 user bus reload
是可选运行依赖。两个主题包都支持临时 `HOME`、`XDG_*`、`CMAKE_INSTALL_PREFIX` 和
`DESTDIR`，测试不修改真实用户配置。

## 打包

未来 AUR 可分别以 `CMAKE_INSTALL_PREFIX=/usr DESTDIR="$pkgdir"` 打包各仓库。不要把
`keytop`、主题包或 Quickshell 的私有 QML plugin复制到系统 Qt import 根；Shell plugin
只安装到 release 私有的 `lib/qml/`。
