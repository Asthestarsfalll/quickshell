# Quickshell 源码开发工作流

## 三个入口的职责

```text
key session
    从 TTY 启动 Niri，并使用 Clavis 托管的 Niri 配置

key shell
    从 current 指向的不可变 release 启动正式 Quickshell

key shell --dev
    在现有 Niri 会话内直接运行当前 Git 工作区的 Quickshell 源码
```

`key shell --dev` 不重启 Niri、不改写 generated `session.kdl`，也不创建 release、
切换 `current` 或修改 manifest。因此正式 release 始终可作为开发失败后的回退。
恢复正式版使用 `key shell --replace`。

## 普通 QML 与资源开发

在仓库根目录或任意子目录执行：

```bash
key shell --dev
```

命令从当前工作目录逐级向上查找同时含有 `.git`、`shell.qml`、`core/` 和
`packaging/` 的目录。仓库外、IDE 或多 worktree 自动化可以明确指定：

```bash
key shell --dev --source /absolute/path/to/clavis
```

此模式的来源关系为：

```text
QML、JavaScript、shell 脚本、SVG、shader、图片和其他资源
    -> 当前 Git 源码树

key 后端、Clavis.* 与 M3Shapes 原生 QML 模块
    -> current 指向的已安装 release
```

Quickshell 以源码目录作为 `--path` 启动，其原生配置监视与 reload 会直接加载 QML
及可监视资源的修改。脚本路径也解析到源码树，下一次调用读取修改后的脚本。无需为了
查看每次 QML 修改而运行 `./setup.sh install --allow-dirty`。

启动日志会列出 runtime mode、source/QML root、backend key、native import root、
Git commit 和 dirty 状态，便于确认没有混用来源。

源码模式不接受 Quickshell `--daemonize`：短生命周期 IPC 记录需要由前台 launcher
在进程退出时清理。正式 `key shell` 仍可透传该选项，但常规 Niri 会话由
`startup.kdl` 管理，不需要 daemonize。

## C++ 与原生 QML 开发

修改 `core/src/`、`core/cli/`、`core/plugin/`、`core/helper/` 或其他 CMake 构件后运行：

```bash
key shell --dev --native
```

该命令调用 `./setup.sh dev-build --build-dir .build/dev`。CMake 每次增量配置并执行
`cmake --build`，不会删除 `.build/dev`；Ninja/Make 只重新构建受变更影响的目标。
开发 Shell 使用 `.build/dev/bin/key`、`.build/dev/Clavis/` 和
`.build/dev/M3Shapes/`，而 QML 与资源仍直接来自源码。

共享库不能在已经载入它的进程中可靠热替换。已有 Shell 时应明确重启开发实例：

```bash
key shell --dev --native --replace
```

构建失败只会留下可继续增量构建的 `.build/dev`，不会写入 release、系统 Qt import
目录或 `current`。正常开发不应清理这个构建树。

## 实例切换与 IPC

完整的正式和开发 Shell 默认不能并行运行。发现另一实例时，命令会拒绝并提示使用
`--replace`。替换通过 Quickshell 的精确 `--pid` 选择完成，不调用 `pkill qs` 或
`pkill quickshell`，也不影响 Control Center 等其他 Quickshell 配置。

启动器原子写入 `$XDG_RUNTIME_DIR/clavis/active-shell.json`，其中包含模式、PID、
Linux 进程启动时刻和当前 QML/import 来源。该文件权限为 `0600`，Shell 正常退出时
删除；崩溃遗留的记录会通过 PID、启动时刻和进程身份校验自动清理。

`key ipc` 在记录有效时按 PID 路由，因此 Niri 中固定的 `$CLAVIS_KEY ipc ...` 快捷键
无需为开发模式生成另一份配置。没有有效记录时，它回退到 `current` release 的 QML
实例。剪贴板 watcher 继续由 `startup.kdl` 启动，既不依赖开发源码位置，也不随 Shell
切换而重复创建。

## 可选 just 工作流

`just` 只编排已有的 `key` 和 `setup.sh`，不是运行时依赖。默认帮助只显示英文：

```bash
just
just --list
```

需要纯中文说明时执行：

```bash
just help-zh
```

公开 recipes：

| recipe | 说明 |
| --- | --- |
| `default` | 显示英文工作流，不执行操作 |
| `help-zh` | 显示中文工作流，不执行操作 |
| `dev` | 启动普通源码开发模式 |
| `dev-replace` | 停止当前 Shell 并切换到源码模式 |
| `dev-native` | 增量编译原生构件并启动源码 Shell |
| `dev-native-replace` | 编译后替换当前 Shell |
| `build` | 通过 setup.sh 构建，不安装 |
| `test` | 构建并运行完整 CTest |
| `doctor` | 只读检查依赖 |
| `install` | 构建、测试并创建正式 release |
| `releases` | 查看当前版本和 release 列表 |

完成开发后先运行 `just test`（或 `./setup.sh test`）。只有准备让正式桌面使用新快照时
才运行 `just install`（或 `./setup.sh install`）。安装成功后，`key shell --replace`
切换回新的正式 release。
