# Clavis Shell

Clavis 是基于 QML/Quickshell 的 Wayland 桌面 Shell。这个仓库只负责长期运行的
响应式状态、QML UI、高频原生 plugin 和实时音频可视化；离散外部命令由独立的
`key-cli` 处理，系统监测由独立的 `keytop` 处理。

## 运行关系

```text
niri.service
├── clavis-shell.service
│      └── key shell
│             └── qs -c clavis -n
└── clavis-clipboard.service
       └── key clipboard watch
              └── wl-paste
                     └── key clipboard store
                            └── cliphist

Quickshell
├── ClipboardService   → key clipboard ...
├── RecordingService   → key record ...
└── AudioRecordingService → key audio ...
```

`key shell` 不探测源码、构建、安装、切换或回滚版本。用户级配置目录优先于系统
目录：

```text
~/.config/quickshell/clavis     用户源码/开发配置
/etc/xdg/quickshell/clavis      系统安装回退配置
```

开发者可以建立源码入口：

```bash
mkdir -p ~/.config/quickshell
ln -sfn ~/Projects/clavis ~/.config/quickshell/clavis
```

## 开发构建

依赖包括 Qt 6、Quickshell、Ninja、PipeWire/libcava 和 Qt Keychain。配置与构建不需要
sudo：

```bash
cmake -S . -B build \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug

cmake --build build

QML_IMPORT_PATH="$PWD/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
  key shell
```

QML 文件保存后由源码 Shell 热重载；修改 C++ plugin 后运行
`cmake --build build`，再重启或重新加载 Shell。`build/qml` 是开发 import tree，
不会写入系统 Qt import 根。

`key shell` 会把它自身解析到的绝对可执行路径放进 `CLAVIS_KEY`，再启动
Quickshell。`ClipboardService`、`RecordingService` 和 `AudioRecordingService`
都通过 `Common/Paths.qml` 的 `Paths.stableKey` 使用这个值；没有该环境变量时才
回退到 PATH 中的 `key`。

## 正式构建

```bash
cmake -S . -B build \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/

cmake --build build
sudo cmake --install build
```

CMake 支持 `DESTDIR="$pkgdir" cmake --install build`，安装器本身不调用 sudo。默认
布局为 `/etc/xdg/quickshell/clavis`、`/lib/qt6/qml/Clavis`、`/lib/qt6/qml/M3Shapes`
以及 Clavis 自己的 `/usr/lib/systemd/user/clavis-shell.service`。systemd 用户单元
使用 `${CMAKE_INSTALL_LIBDIR}/systemd/user`；在 Arch 的合并 `/usr` 布局中，
`/lib/systemd/user` 即 `/usr/lib/systemd/user`。Clavis 不再安装
`clavis-clipboard.service`。

## 安装与更新分工

首次安装需要先安装 `key-cli` wheel。它同时提供 `/usr/bin/key`、Python package
和 `/usr/lib/systemd/user/clavis-clipboard.service`；安装后由用户执行：

```bash
systemctl --user daemon-reload
systemctl --user enable --now clavis-clipboard.service
```

这使 clipboard watcher 在当前 Niri 会话立即运行，并在之后随 `niri.service` 启动。
Shell 不创建、托管或重启这个 watcher，也不要把 `key clipboard watch` 重复加入
Niri 的 `spawn-at-startup`。

首次安装 Clavis Shell 时，配置、构建并安装本仓库，然后让 user systemd manager
重新读取它提供的 `clavis-shell.service`；是否启用 shell unit 由用户的 Niri session
策略决定。普通 QML/C++ 更新只需重新 `cmake --build build`、安装并重启 Shell，
不需要重新安装 clipboard backend。

日常更新 `key-cli` 时重新构建/安装它的 wheel，然后执行
`systemctl --user daemon-reload` 和
`systemctl --user restart clavis-clipboard.service`；更新 Clavis Shell 时重新构建/安装
Clavis 并重启 `key shell`。

如果目标系统已经安装过同版本 wheel，`python -m installer` 默认拒绝覆盖；更新
key-cli 时使用 `sudo python -m installer --overwrite-existing <wheel>`。

## 原生 QML modules

```text
Clavis.Niri
Clavis.Weather
Clavis.WeatherMap
Clavis.Cava
Clavis.Lyrics
Clavis.Media
Clavis.Keyboard
Clavis.I18n
Clavis.Runtime
M3Shapes
```

所有自制 module 使用无版本 import，例如 `import Clavis.Cava`。天气在 Shell 进程内
使用 Open-Meteo、TTL 缓存、逐小时/每日预报和 WeatherMapProvider；`Clavis.Cava`
只负责 PipeWire 实时电平、RMS/Peak、频谱和动画，不录制音频文件；`Clavis.Lyrics`
负责异步歌词 provider、LRC 时间轴和 MPRIS seek 映射。

## 外部命令

`key-cli` 的安装、升级和卸载由发行版/AUR/pacman 负责。常用命令：

```bash
key shell
key shell --daemon
key shell --kill
key shell --log
key ipc show
key ipc call TARGET METHOD [ARGUMENTS...]
key record start|status|pause|resume|stop --json
key audio start --source mic|system --json
key audio status|stop --json
key clipboard status --format json
key clipboard list --format json --limit 5
key clipboard inspect|restore|delete ID --format json
key clipboard clear --format json
keytop value stream --format jsonl --interval 1000 \
  --modules system,cpu,memory,gpu,disk,network,battery
```

录屏、录音状态只写入 `$XDG_RUNTIME_DIR/key/`，剪贴板后端使用 cliphist、wl-copy 和
wl-paste。录屏、GIF 后处理、音频文件写入、pactl/ffmpeg/ffprobe、PID/session 管理均属于
`key-cli`；`Clavis.Cava` 只负责实时频谱、电平和可视化。GIF 在停止后完成处理，
结束通知不会早于处理完成。Shell 通过参数数组消费这些机器 JSON，不拼接 shell
字符串。

排查 clipboard 时使用：

```bash
systemctl --user status clavis-clipboard.service
pgrep -af 'wl-paste.*--watch'
key clipboard status --format json
```

预期 watcher 运行时 `watcherRunning=true`、`available=true`、`ok=true`。如果
`clavis-clipboard.service` 不存在，说明 key-cli wheel 尚未重新安装到标准 user-unit
目录；不要从旧的非标准共享目录复制 unit，也不要启动第二个 watcher。

## 验证

```bash
cmake --build build
ctest --test-dir build --output-on-failure
```

开发任务默认只修改源码和构建目录，不自动安装、重启运行中的 Shell、提交或推送。
