# Clavis repository split audit

审计日期：2026-08-03

审计源仓库：`/home/archirithm/Projects/clavis`，分支 `test/release`。请求中
给出的 `~/Projects/quickshell` 在本机不存在；该仓库的 Git remote 名称仍为
`quickshell`，因此本文将当前 `clavis` 作为目标 `quickshell` 源仓库处理。
审计时工作树干净，`~/Projects/key-cli`、`keytop`、`clavis-zsh-theme` 和
`clavis-fcitx5-theme` 均不存在。

本文先于文件移动生成，记录当前调用关系、拆分边界和 release 假设。后续实现以
实际源码调用关系为准，而不是以迁移请求中假设的文件名为准。

## 1. 当前 CMake target 和全局依赖

`core/CMakeLists.txt` 当前建立一个 `ClavisCore` 工程，并无顶层共享库 target，
但通过子目录生成下列 target：

| target | 当前位置 | 主要依赖 | 最终所有者 |
| --- | --- | --- | --- |
| `ClavisRuntimeCore` | `core/src` | Qt6 Core/Network，路径和 RAPL client | `key-cli`（路径）；RAPL client 随 Keytop；Shell 只保留必要 runtime adapter |
| `ClavisSysmonCore` | `core/src` | `ClavisRuntimeCore`、Qt6 Core | `keytop` |
| `ClavisWeatherCore` | `core/src` | Qt6 Core/Network、QtKeychain | `key-cli`（天气数据）；Shell 删除 |
| `ClavisWeatherMapCore` | `core/src` | Qt6 Core/Gui/Network、Qt6Keychain | `quickshell` |
| `ClavisNiriCore` | `core/src` | Qt6 Core/Network | `quickshell` |
| `ClavisRecordingCore` | `core/src` | `ClavisRuntimeCore`、Qt6 Core | `key-cli` |
| `ClavisAudioCore` | `core/src` | Qt6 Core、PipeWire | `quickshell` |
| `ClavisMediaCore` | `core/src` | Qt6 Core/Gui | `quickshell` |
| `M3ShapesCore` | `core/src/m3shapes` | Qt6 Core | `quickshell` |
| `M3ShapesMorph` | `core/src/m3shapes` | `M3ShapesCore` | `quickshell` |
| `M3ShapesGeometry` | `core/src/m3shapes` | `M3ShapesCore` | `quickshell` |
| `key` | `core/cli` | Runtime/Sysmon/Recording/Niri、Qt6、ncursesw | `key-cli`（拆除后不在 Shell） |
| `clavis-rapl-helper` | `core/helper/rapl` | C++17、Linux powercap/socket | `keytop` |
| `ClavisSysmon` | `core/plugin/sysmon` | `ClavisSysmonCore`、Qt6 Gui/Qml | 删除，QML 改消费 `keytop` |
| `ClavisWeather` | `core/plugin/weather` | `ClavisWeatherCore`、Qt6 Gui/Qml/Network | 删除，QML 改消费 `key weather` |
| `ClavisWeatherMap` | `core/plugin/weathermap` | `ClavisWeatherMapCore`、Qt6 Gui/Qml/Network | `quickshell` |
| `ClavisNiri` | `core/plugin/niri` | `ClavisNiriCore`、Qt6 Gui/Qml/Network | `quickshell` |
| `ClavisAudio` | `core/plugin/audio` | `ClavisAudioCore`、libcava、Qt6 | `quickshell` |
| `ClavisMedia` | `core/plugin/media` | `ClavisMediaCore`、Qt6 Gui/Qml | `quickshell` |
| `ClavisKeyboard` | `core/plugin/keyboard` | Qt6 Core/Qml | `quickshell` |
| `M3Shapes` | `core/plugin/m3shapes` | M3Shapes 三个 core、Qt6 Quick/Qml、shader | `quickshell` |
| `ClavisI18n` | `core/plugin/i18n` | Qt6 Core/Qml、Qt Linguist | `quickshell` |
| `ClavisRuntime` | `core/plugin/runtime` | Qt6 Core/Qml、generated release header | `quickshell`（最小 RuntimeInfo） |

当前全局 configure 还要求 Qt6 Core/Gui/Qml/Quick/Network/ShaderTools/
LinguistTools、Qt6Keychain、PipeWire、ncursesw 和 libcava/cava。拆分后：

- `quickshell` 只保留 Qt、PipeWire、cava、QtKeychain（地图凭据仍使用它）等真实
  plugin 依赖；不再配置 ncurses、Sysmon、RAPL 或 CLI。
- `keytop` 独立配置 Qt Core/Network/Test、ncursesw；如果保留 systemd RAPL helper，
  helper 与 `keytop` 共用协议但不要求 Shell 编译它。
- `key-cli` 不链接 quickshell 的 C++ target；初期可用独立复制/重组的 CLI core，
  但不能通过 CMake `add_subdirectory` 依赖 Shell。

## 2. 当前 CLI command surface

`core/cli/src/command_router.cpp` 当前注册：

| 当前命令 | 迁移后 |
| --- | --- |
| `key`, `--help`, `--version`, `version` | `key-cli` |
| `key shell`, `shell logs` | `key-cli` |
| `key ipc` | `key-cli` |
| `key doctor`, `doctor legacy`, `setup cpu-power` | `key-cli`；RAPL 诊断改为 Keytop/独立 helper 状态 |
| `key audio` | `key-cli`；高频可视化仍由 Shell plugin |
| `key record` | `key-cli` |
| `key cast` | `key-cli`；保留必要的 Niri cast parser/target 辅助 |
| `key clipboard` | `key-cli` |
| `key weather`（当前源码树中主要由 weather backend/脚本承担） | `key-cli` |
| `key sysmon` | 删除 CLI ownership，迁为 `keytop value` 等价接口 |
| `key top` | `key-cli` 仅保留 `exec keytop` 兼容转发 |
| `key rollback`, `release`, `update`, `uninstall`, `migrate`, `setup` | `key-cli` |
| `key install`, `key component status` | `key-cli` 新增受控官方 source provider |

当前 `sysmon` 支持 `snapshot`、`stream`、`system`、`cpu`、`memory`、`gpu`、
`disk`、`network`、`battery`、`processes` 和 `modules`；stream 默认 JSONL，
支持 `--interval`、`--modules`，processes 支持 `--sort`、`--limit`、`--filter`、
`--tree`。这些字段、单位、schema v1、cursor/序列语义迁移到 `keytop`，不由
`key-cli` 重写。

## 3. QML plugin、注册类型和消费者

| URI | 注册类型/能力 | QML 消费者 | 最终处理 |
| --- | --- | --- | --- |
| `Clavis.Sysmon 1.0` | `SysmonPlugin` singleton、`ProcessModel`，CPU/内存/网络/设备/身份和四级 timer | `Services/SystemIdentityService.qml`、`Services/SystemMonitorService.qml` 旁路身份、`Modules/Bar/SysMonitor`、`Modules/Lock/Cards/*`、Keystone UserCard | 删除 plugin；SystemMonitorService 直接启动 `keytop`，身份也由一次性 keytop value/snapshot 消费 |
| `Clavis.Weather 1.0` | `WeatherPlugin`、`WeatherListModel`，Open-Meteo 请求、缓存、计算、预报 model | `Modules/Sidebars/Left/Weather*`、`Modules/Keystone/WeatherContent/*`、`Modules/Lock/Cards/WeatherCard`、系统天气卡、设置页 | 删除 plugin/backend；由 `key weather` JSON 消费 |
| `Clavis.WeatherMap 1.0` | `WeatherMapPlugin` singleton，异步瓦片、QImage 解码、缓存、OpenWeather/MapTiler keychain 凭据 | `AppShell.qml`、`Modules/Keystone/WeatherContent/WeatherMap*`、`Modules/ControlCenter/*ApiSettings*` | 保留在 Shell |
| `Clavis.Niri 1.0` | Niri IPC、窗口/工作区/输出 model、icon lookup、workspace derivation | `Common/*`、`Services/Niri*`、`Modules/Bar/Workspaces`、Bar/ActiveWindow、Keystone、控制中心、锁屏等 | 保留在 Shell |
| `Clavis.Audio 1.0` | `CavaProvider`、`AudioLevelProvider`，PipeWire/libcava 和高频 analyzer | `Services/AudioSpectrum.qml`、`Services/AudioRecordingService.qml`、Keystone recording、sidebar audio | 保留在 Shell |
| `Clavis.Media 1.0` | `MediaPalettePlugin`，封面图像调色板 | `Services/MediaPalette.qml` 等媒体卡 | 保留在 Shell |
| `Clavis.Keyboard 1.0` | `KeyboardLockState` singleton，轮询 `/sys/class/leds` 的 Num/Caps 状态 | `Modules/Lock/LockContent.qml`，实际读取 `KeyboardLockState.capsLock/numLock` | 保留在 Shell；不是死模块 |
| `M3Shapes 1.0` | `MaterialShapeItem`、`SmoothShapeMaterial` 和 shaders | 多个天气图表、SystemView、Launcher、Keystone 等 | 保留在 Shell |
| `Clavis.I18n 1.0` | `I18nManager` | `Services/I18nService.qml` / `AppShell.qml` | 保留在 Shell |
| `Clavis.Runtime 1.0` | `ClavisBuildInfo`，构建 release、commit、buildTime | Runtime compatibility/service 与启动 smoke | 保留为最小 metadata adapter，删除旧系统能力握手 |

`Clavis.WeatherMap` 不是 `QQuickImageProvider`：源码没有继承该类，也没有调用
`addImageProvider`。它通过 `QImageReader`/`QImage::fromData` 校验网络图像，原子写
到 tile cache，再把 `file://` URL 交给 QML `Image`。因此它仍是强 QML/图像生命周期
耦合的 native layer，不能迁到一次性天气 CLI。

## 4. C++ 文件的最终唯一所有者

以下是 `rg --files core -g '*.cpp' -g '*.h' -g '*.hpp'` 的逐文件归属。文件移动时
保持许可证和第三方 `UPSTREAM.txt`/版权说明。

### `keytop`

```text
core/src/sysmon/types.h
core/src/sysmon/parsers.h
core/src/sysmon/parsers.cpp
core/src/sysmon/collector.h
core/src/sysmon/collector_system.cpp
core/src/sysmon/collector_devices.cpp
core/src/sysmon/collector_processes.cpp
core/src/sysmon/sampler.h
core/src/sysmon/sampler.cpp
core/src/sysmon/serialization.h
core/src/sysmon/serialization.cpp
core/src/sysmon_types.h
core/src/sysmon_backend.h
core/src/sysmon_backend.cpp
core/plugin/sysmon/src/process_model.h
core/plugin/sysmon/src/process_model.cpp
core/plugin/sysmon/src/sysmon_plugin.h
core/plugin/sysmon/src/sysmon_plugin.cpp       # 逻辑改为 keytop core/TUI，不再保留 plugin
core/src/runtime/rapl_helper_client.h
core/src/runtime/rapl_helper_client.cpp
core/helper/rapl/main.cpp
core/cli/src/tui/top_tui.h
core/cli/src/tui/top_tui.cpp
core/cli/src/tui/top_tui_helpers.h
core/cli/src/tui/top_tui_helpers.cpp
core/cli/src/commands/sysmon_command.h
core/cli/src/commands/sysmon_command.cpp
core/cli/src/commands/top_command.h
core/cli/src/commands/top_command.cpp
```

其中 `sysmon_plugin.*` 的 QML timer wrapper 不直接迁移；其仍有价值的 process
model/字段映射会在 keytop 的机器输出和 TUI 数据模型中重组。`keytop` 不复制采样
算法：TUI 和 `value/stream` 共用同一个 `Sampler`。

### `key-cli`

```text
core/cli/src/main.cpp
core/cli/src/command_result.h
core/cli/src/command_router.h
core/cli/src/command_router.cpp
core/cli/src/commands/audio_command.h
core/cli/src/commands/audio_command.cpp
core/cli/src/commands/cast_command.h
core/cli/src/commands/cast_command.cpp
core/cli/src/commands/clipboard_command.h
core/cli/src/commands/clipboard_command.cpp
core/cli/src/commands/doctor_command.h
core/cli/src/commands/doctor_command.cpp
core/cli/src/commands/management_command.h
core/cli/src/commands/management_command.cpp
core/cli/src/commands/record_command.h
core/cli/src/commands/record_command.cpp
core/cli/src/commands/version_command.h
core/cli/src/commands/version_command.cpp
core/src/recording/**/*.h
core/src/recording/**/*.cpp
core/src/niri_cast_parser.h
core/src/niri_cast_parser.cpp
core/src/niri_ipc_client.h
core/src/niri_ipc_client.cpp        # 只保留 cast/CLI 必需辅助；QML model 留 Shell
core/src/runtime/clavis_paths.h
core/src/runtime/clavis_paths.cpp
```

天气数据 backend（`openmeteo_client.*`、`weather_backend.*`、`weather_cache.*`、
`weather_calculator.*`、`weather_types.*`）属于 `key-cli` 的独立实现；迁移时不保留
Shell target 的副本。`key-cli` 自己的 `src/` 将把它们重组为 data provider，不能
依赖 quickshell 的 CMake target。

### `quickshell`

```text
core/src/niri_types.h
core/src/niri_icon_lookup.h/.cpp
core/src/niri_workspace_deriver.h/.cpp
core/src/niri_workspace_model.h/.cpp
core/src/niri_window_model.h/.cpp
core/src/niri_output_model.h/.cpp
core/plugin/niri/src/niri_plugin.h/.cpp
core/src/audio_collector.h/.cpp
core/src/audio_level_collector.h/.cpp
core/src/audio_visual_analyzer.h/.cpp
core/plugin/audio/src/audio_level_provider.h/.cpp
core/plugin/audio/src/cava_provider.h/.cpp
core/src/media_palette_backend.h/.cpp
core/plugin/media/src/media_palette_plugin.h/.cpp
core/src/weather_map_provider.h/.cpp
core/plugin/weathermap/src/weather_map_plugin.h/.cpp
core/plugin/keyboard/src/keyboard_lock_plugin.h/.cpp
core/plugin/m3shapes/src/MaterialShapeItem.hpp/.cpp
core/plugin/m3shapes/src/SmoothShapeMaterial.hpp/.cpp
core/src/m3shapes/**/*.hpp
core/src/m3shapes/**/*.cpp
core/plugin/i18n/src/i18n_manager.h/.cpp
core/plugin/runtime/src/clavis_build_info.h/.cpp
```

上表中的 `a/.b` 是审计简写，实际迁移按两个完整路径处理；没有隐含删除同目录中
其他文件。`runtime/clavis_paths.*` 在最终实现中按依赖拆出：Shell 可保留只读的
runtime/path adapter，CLI 维护自己的规范路径实现，避免共享一个跨仓库 C++ 库。

### 主题仓库

当前 core 下没有 Zsh prompt 或 Fcitx5 C++ 文件。两者的所有权来自 `my_zsh_prompt`
（需从用户/现有源码树进一步定位）及 `matugen/templates/fcitx5-*` 和
`scripts/theme/generate_matugen_colors.sh`：迁移到两个主题仓库，不复制到 Shell
release。

## 5. systemd、helper、脚本和 Matugen 调用关系

- `packaging/systemd/user/clavis-shell.service` 与 `clavis-clipboard.service` 由
  release manager 渲染到用户 systemd 目录，绑定 `niri.service`；安装时只 enable，
  不立即启动。最终仍由 `key-cli` 编排，服务执行稳定 `key shell`/`key clipboard`
  入口，release 内不再放 `key`。
- `packaging/systemd/system/clavis-rapl-helper.service/.socket` 当前由
  `key setup cpu-power` 以 sudo 安装并启用，socket 激活 `clavis-rapl-helper`。它随
  `keytop` 成为可选独立 helper；普通 Shell release 不包含它，也不由 AI 任务请求
  sudo。
- `packaging/clavis-manager.py` 当前同时负责 release manifest、current symlink、
  shell 启动/日志/IPC、Niri unit、legacy 清理和 RAPL 安装。最终拆分为 `key-cli`
  的 release/runtime manager；Shell 只安装 `.partial` runtime 并调用稳定的 Key
  finalize 接口。
- `packaging/clavis_paths.py` 和 `scripts/lib/clavis-paths.sh` 定义 XDG、profile、
  release、runtime、日志和 QML import 路径。规范会同步到 `key-cli`、Shell 的
  `Common/Paths.qml` 和组件脚本；不引入仓库绝对路径。
- `scripts/theme/generate_matugen_colors.sh` 读取固定 `matugen/config.toml` 和
  templates，当前输出 quickshell、Niri、btop、Cava、Kitty、Fcitx5、Yazi。最终
  Shell 只保留自己的配色输出和固定模板；Zsh/Fcitx5 输出由各自仓库负责。Fcitx5
  必须同时生成 `theme.conf`、`panel.svg`、`highlight.svg`，并在全部成功后只
  reload 一次 Classic UI。
- `scripts/system/manage-niri-config.py`、`manage-niri-effects.sh` 和
  `install-clavis-user-services.py` 属于 Clavis/Niri 配置所有权，暂留
  `quickshell`/由 `key-cli` 调用；组件安装不得重写用户主配置。
- `scripts/weather/weather.py` 是当前天气相关辅助脚本，需与 `openmeteo_client`
  和 QML 调用一起审计后并入 `key-cli` provider，不能成为 Shell release 中隐藏的
  第二天气实现。

## 6. 测试迁移矩阵

| 当前测试 | 最终仓库 | 备注 |
| --- | --- | --- |
| `core/tests/sysmon_core_test.cpp` | `keytop` | collector、采样率、单位/占用率 |
| `core/tests/key_sysmon_integration_test.cpp` | `keytop` | 改为执行 `keytop value/stream` |
| `core/tests/top_tui_helpers_test.cpp` | `keytop` | TUI 辅助数据 |
| `core/tests/rapl_helper_client_test.cpp` | `keytop` | helper socket/协议 |
| `core/cli/src/commands/sysmon*`, TUI 自测 | `keytop` | 同一 sampler |
| `core/tests/clavis_core_tests`, `recording_core_test.cpp` | `key-cli` | recording controller/state/parser |
| `core/tests/key_integration_test.cpp` | `key-cli` | audio/record/cast/clipboard，移除 sysmon 部分 |
| `tests/test_clavis_manager.py` | `key-cli` | release、manifest、shell/IPC、source provider |
| `core/tests/clavis_paths_test.cpp` | `key-cli` | 与 Python/shell 路径契约同步 |
| `tests/test_manage_niri_config.py`、`test_install_clavis_user_services.py` | `key-cli` | 配置部署编排 |
| weather cache/calculator tests（当前若无独立 test） | `key-cli` | 新增 JSON/cache/TTL 用例 |
| `core/tests/niri_workspace_deriver_test.cpp` | `quickshell` | Niri model |
| `core/tests/audio_visual_analyzer_test.cpp` | `quickshell` | 高频音频 |
| `core/tests/m3shapes_test.cpp` | `quickshell` | M3Shapes |
| `tests/qml/*` | `quickshell` | 删除 sysmon/weather compatibility 旧 fallback 用例，保留 Shell/QML |
| `tests/test_shader_assets.sh`, `test_awww_dedup.sh`, Matugen/Niri smoke | `quickshell` | 仅保留 Shell 所有权部分 |
| Zsh managed block/backup/卸载测试 | `clavis-zsh-theme` | 新增 shell sandbox |
| Fcitx5 三文件/atomic apply/reload 测试 | `clavis-fcitx5-theme` | mock matugen/fcitx5，断言一次 reload |

## 7. `plugin/keyboard` 和待删除死代码

`Clavis.Keyboard` 满足“有 QML import、类型实例化、有效运行职责”三项中的全部：
`Modules/Lock/LockContent.qml` import `Clavis.Keyboard 1.0`，读取
`KeyboardLockState.capsLock` 和 `numLock`，plugin 轮询 `/sys/class/leds`。因此不
删除，最终归 `quickshell`。

审计阶段确认的迁移后应删除代码/配置：

1. `core/plugin/sysmon/` 及 `ClavisSysmonCore`、`sysmon_backend.*` 的 Shell/QML
   adapter；QML 改为消费 `keytop` JSONL。
2. `core/cli/src/commands/sysmon*` 和 `top*`、`core/cli/src/tui/`；原命令在
   `keytop` 重组，`key top` 只在 `key-cli` 做 exec 兼容转发。
3. `core/helper/rapl/`、systemd RAPL 文件和 Shell release 安装路径；迁往 Keytop
   可选集成，不能留在 Shell release。
4. `core/plugin/weather/`、`ClavisWeatherCore`、普通 Open-Meteo backend/cache，迁
   到 `key-cli`；`ClavisWeatherMap` 和 `WeatherMapProvider` 不删除。
5. `key` target、release 中的 `bin/key`、release 内第二份 manager 和旧 launcher；
   稳定 `key` 只由 `key-cli` 提供。
6. 构建阶段对 ncurses、sysmon、RAPL、迁出天气后端的 include/install/test 定义。
7. 分散的 `key --version`/RuntimeCompatibility 红色整页 fallback；改为普通空
   状态、stale 数据或禁用按钮。协议检查集中到 Key shell/release metadata。
8. 只有在后续调用图确认无消费者的 generated/占位文件才删除；`KeyboardLockState`
   不属于此项。

## 8. 当前 release 的隐式假设

当前 `packaging/clavis-manager.py` 和 `setup.sh` 有下列必须打破或迁移的假设：

- release 必须包含 `share/clavis/qml/shell.qml`、`lib/qml` native modules、
  `share/clavis/libexec/clavis-manager.py`、`share/clavis/libexec/clavis-rapl-helper`
  和 `bin/key`；`validate_release()` 检查 key 可执行，`release.json` 还声明
  `sysmon`/`raplHelper` protocol。
- `key shell` 通过 current release 内的 `bin/key` 递归启动；dev-native 默认读取
  `.build/dev/bin/key`，再由 key 调用 manager。迁移后 key-cli 自身在
  `~/.local/bin/key` 或 `/usr/local/bin/key`，只协调 release，不从 release 递归取
  第二份 key。
- QML environment 将 release 的 `lib/qml` 注入 `QML_IMPORT_PATH`，release 的
  `share/clavis/qml` 作为 shell root；此路径语义保留，但 metadata 增加
  `component`、`minimumKeyCli`、`minimumKeytop`、`shellProtocol` 和相对路径字段。
- 当前 `setup.sh configure` 强制 `BUILD_TESTING=ON`，`build`/`install` 通过
  `test_release` 隐式运行 CTest；最终 configure/build 默认 OFF，test/smoke 必须
  显式执行，install 只做产物结构验证。
- `setup.sh install` 把 CMake install 输出直接当完整可运行 release，并会安装
  systemd/Niri/主题默认文件；最终只生成 `.partial` Shell runtime，稳定 Key CLI
  做注册、校验、current 原子切换和组件编排。
- manager 具有 legacy-home、旧 quickshell cache/profile、RAPL system install 和
  release 内 launcher 的清理/安装路径；这些需删去或变成明确的兼容命令，不能在
  拆分时偷偷覆盖真实用户配置。

## 9. 审计后的实施顺序

1. 先建立四个空独立 Git 仓库和明确安装/manifest 骨架。
2. 迁移 Keytop core/TUI/机器 JSON 接口及测试，先让 `keytop` 不依赖 `key`。
3. 迁移 Key CLI 和 release/runtime manager，建立组件 registry/source provider，
   再让 Shell setup 调用外部 Key finalize。
4. 迁移 Zsh/Fcitx5 模板和 apply/uninstall 流程，全部在临时 HOME 中测试。
5. 从 quickshell CMake 删除 CLI/Keytop/weather data/rapl，保留 Niri、音频、媒体、
   地图、M3Shapes、i18n、keyboard 和 Runtime adapter。
6. 改 QML 消费路径、移除红色 fallback，再验证 Shell source/dev-native 与 release
   runtime 的相对 import 路径。

## 10. 后续实现注记（2026-08-04）

初始审计中的“仓库不存在”和“尚待定位”描述是迁移前快照，不代表当前工作区状态。
本次主题修复使用的 Prompt 源码实际位于 `/home/archirithm/prompt_dev`；该工作树在
开始时已有用户未提交修改，本任务只读检查，没有覆盖或提交它。可安装的独立主题包是
同级 `/home/archirithm/Projects/clavis-zsh-theme`，其实现保留 Prompt renderer、
ZLE 集成和 managed block 接入，并把模板与配置所有权放在主题包内。

当前外部主题调用关系已收敛为：Quickshell 只运行 Matugen 并原子更新三个组件的
`colors.conf`；Keytop 用 `keytop reload` 重载已运行 TUI 的颜色；Fcitx5 用
`fcitx5-theme apply` 在完整临时主题目录中发布 `theme.conf`、`panel.svg`、
`highlight.svg` 及菜单 SVG 资源，然后只 reload 一次。
