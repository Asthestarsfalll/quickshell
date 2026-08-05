# Clavis Shell 工作约定

本仓库是正式的 CMake/Ninja + QML/Quickshell 项目。`shell.qml` 是入口，`AppShell.qml`
负责顶层装配；`Modules/` 放业务模块，`Services/` 放长期状态和系统交互，`Widgets/`
只放展示控件，`Common/` 放主题、尺寸、路径和纯工具，`core/` 放原生 backend 与 QML
plugin。

## 职责边界

- Clavis Shell 负责 Niri IPC、窗口/工作区/输出、天气、WeatherMapProvider、M3Shapes、
  MediaPalette、Caps/Num Lock、实时 Cava、MPRIS 歌词与同步时间轴。
- `key-cli` 负责 Quickshell 生命周期/IPC 包装、屏幕录制、音频文件录制和剪贴板后端。
- `keytop` 是唯一系统监测实现；QML 直接消费 `keytop value stream --format jsonl`，
  禁止重新引入 `QML → key → keytop`。

不得恢复 `cast`、`key top`、`key sysmon`、Clavis.Sysmon、天气 CLI 中转、Python 歌词
脚本、内嵌 C++ key CLI、release manager、rollback、`current` 软链接、`releases/`、
`setup.sh`、`justfile` 或 Makefile。参考仓库只读，不能修改。

## 构建与 XDG 配置

顶层 `CMakeLists.txt` 统一构建原生 module 和 QML 源码安装，不调用 sudo：

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

开发入口是 `~/.config/quickshell/clavis` 指向当前源码；没有用户目录时，Quickshell
回退到 `/etc/xdg/quickshell/clavis`。开发原生 module 使用：

```bash
QML_IMPORT_PATH="$PWD/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" key shell
```

不能把仓库绝对路径或构建路径写入用户 Niri 配置。稳定外部入口使用 `$CLAVIS_KEY`
（未设置时为 `key`），IPC 文档和快捷键使用 `key ipc ...`，不使用裸 `quickshell ipc`。

## QML 与 plugin

自制 import 必须无版本号：`import Clavis.Weather`、`import Clavis.WeatherMap`、
`import Clavis.Cava`、`import Clavis.Lyrics`。CMake 的 `qt_add_qml_module` 不添加无
意义的 `VERSION 1.0`。展示组件不得创建 `Process` 或执行系统命令；录屏、录音和剪贴板
通过 `Process.command` 参数数组调用 `key`，机器响应必须校验 `schemaVersion` 和错误。

实时音频采集只用于 Cava、电平、频谱和动画；FFmpeg、pactl、ffprobe、录音 PID、临时
音频文件及 finalizer 属于 `key audio`。歌词获取、缓存、LRC 解析和 MPRIS seek 属于
`Clavis.Lyrics`。

## 测试与协作

按改动范围运行：

```bash
git diff --check
cmake --build build
ctest --test-dir build --output-on-failure
```

QML 改动运行 `qmllint -I .`（使用原生 module 时额外加入 `-I build/qml`）；Shell/Python
改动运行对应语法检查和测试。不要编辑 `build/`、用户 Niri 配置、系统 Qt import 根或
已安装文件来修复源码。默认不安装、不重启进程、不提交；只有用户明确要求时才执行这些
外部操作。
