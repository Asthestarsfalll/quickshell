# Clavis Shell

Clavis 是基于 QML/Quickshell 的 Wayland 桌面 Shell。这个仓库只负责长期运行的
响应式状态、QML UI、高频原生 plugin 和实时音频可视化；离散外部命令由独立的
`key-cli` 处理，系统监测由独立的 `keytop` 处理。

## 运行关系

```text
QML UI ── Clavis.* native modules
       ├─ key record / key audio / key clipboard
       └─ keytop value stream

key shell ── qs -c clavis -n
key ipc   ── qs -c clavis ipc ...
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
以及必要的 `/usr/share/clavis` systemd 用户单元；Arch 的 `/lib` 合并布局由系统处理。

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
key clipboard list|inspect|restore|delete|clear --format json
keytop value stream --format jsonl --interval 1000 \
  --modules system,cpu,memory,gpu,disk,network,battery
```

录屏、录音状态只写入 `$XDG_RUNTIME_DIR/key/`，剪贴板后端使用 cliphist、wl-copy 和
wl-paste。Shell 通过参数数组消费这些机器 JSON，不拼接 shell 字符串。

## 验证

```bash
cmake --build build
ctest --test-dir build --output-on-failure
```

开发任务默认只修改源码和构建目录，不自动安装、重启运行中的 Shell、提交或推送。
