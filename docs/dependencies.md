# 依赖清单

权威机器可读清单位于 `packaging/dependencies.toml`。Arch Linux 是当前优先支持且用于
包名映射的平台；其他发行版只视为 experimental，不声明未验证的包名。

## 构建必需

- CMake、C++17 compiler、pkg-config、Python 3；
- Qt 6 Core/Gui/Network/QML/Quick、ShaderTools、Tools；
- QtKeychain 6、PipeWire headers、ncursesw、libcava；
- 用于 runtime QML import 的 Qt 6 5Compat 与 Lottie 模块。

`./setup.sh doctor` 逐项检测 CMake/pkg-config 条目并打印 Arch 安装命令，但不执行。
`./setup.sh deps --install` 是唯一允许安装系统依赖的 setup 操作，且必须由用户明确
选择。目前自动包管理仅实现 Arch/pacman。

## Runtime 核心

Quickshell、Python 3、Bash/coreutils、`which`、Qt runtime 模块与 systemd user 工具是核心。
niri 是主要 compositor 集成和设置中心 Niri 页所需，作为推荐依赖，以便 `key shell`
仍能在诊断场景下独立处理。

## 可降级功能

清单按功能记录检测方式、用途和 `degradable=true`：

- clipboard：cliphist、wl-clipboard；
- wallpaper/power menu：awww、wlogout、ImageMagick、gettext；
- recording/audio：gpu-screen-recorder、FFmpeg、PipeWire/Pulse tools、pavucontrol、
  wlsunset 与 procps-ng；
- theming：matugen、gsettings；
- network/Bluetooth：NetworkManager、BlueZ；
- display/tools：brightnessctl、ddcutil、hyprpicker、grim、wlsunset；
- external UI/cloud：xdg-utils、gnome-system-monitor、rclone、freedesktop sound theme；
- package updates：pacman 与 Paru；
- profile apps：Kitty、btop、Cava、Yazi；
- CPU power：kernel powercap，及用户显式选择的独立 helper。

缺少可降级依赖时应只禁用对应功能并显示诊断，不应导致整个 Shell 或 `key top` 失败。
新增 QML `Process`、C++ `QProcess`、脚本命令、QML import 或 link dependency 时，必须
同时更新 TOML 与本文档分类。

## 开发工具

Git 用于 commit metadata；qmllint 用于 QML 静态检查；CTest/QtTest 和仓库中的 Python
与 shell 测试覆盖 backend、路径、release manager、Matugen 与 CLI。模板完整测试还会
使用已安装的 matugen、Yazi、Zsh，并在可用时调用 niri 配置验证器。
