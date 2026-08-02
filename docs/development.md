# Quickshell 源码开发工作流

## 三个入口的职责

```text
niri-session
    由显示管理器启动 Niri，并读取用户拥有的 config.kdl

key shell
    从 current 指向的不可变 release 后台启动正式 Quickshell

key shell --dev
    在现有 Niri 会话内从 Git 工作区后台启动 Quickshell

key shell --dev --native
    增量构建原生构件后，从源码后台启动 Quickshell
```

`key shell --dev` 不重启 Niri、不改写用户 Niri 配置，也不创建 release、
切换 `current` 或修改 manifest。因此正式 release 始终可作为开发失败后的回退。
恢复正式版使用 `key shell --replace`。以上入口默认都在确认 Quickshell 完成实例注册后
返回终端；加 `--foreground` 时保持前台运行并实时显示 stdout/stderr。

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

后台启动日志会列出 runtime mode、source/QML root、backend key、native import
root、Git commit、dirty 状态、PID 与最终命令，便于确认没有混用来源。`key` 自己管理
进程分离，因而不接受 Quickshell 的 `--daemonize`、配置路径或实例选择参数；只有 `--`
之后的其他 Quickshell 参数才会透传。

## C++ 与原生 QML 开发

修改 `core/src/`、`core/cli/`、`core/plugin/`、`core/helper/` 或其他 CMake 构件后运行：

```bash
key shell --dev --native
```

该命令调用 `./setup.sh dev-build --build-dir .build/dev`。CMake 每次增量配置并执行
`cmake --build`，不会删除 `.build/dev`；Ninja/Make 只重新构建受变更影响的目标。
开发 Shell 使用 `.build/dev/bin/key`、`.build/dev/Clavis/` 和
`.build/dev/M3Shapes/`，而 QML 与资源仍直接来自源码。

共享库不能在已经载入它的进程中可靠热替换。已有 Shell 时应明确替换开发实例：

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
Linux 进程启动时刻、日志和当前 QML/import 来源。该文件权限为 `0600`。后台实例由
独立的轻量日志监视进程在退出后清理；前台 launcher 在退出时清理。崩溃遗留的记录也
会通过 PID、启动时刻和进程身份校验自动修复。

`key ipc` 在记录有效时按 PID 路由，因此 Niri 中固定的 `$CLAVIS_KEY ipc ...` 快捷键
无需为开发模式生成另一份配置。没有有效记录时，它回退到 `current` release 的 QML
实例。剪贴板 watcher 由 `clavis-clipboard.service` 管理，不随 Shell 热重载重复创建。
显式使用 `key shell --dev --replace` 时，CLI 会停止生产 Shell service，避免其
`Restart=on-failure` 与开发实例竞争；重新登录 Niri 后恢复生产服务。

## 后台启动、前台调试与日志

默认后台模式以独立 session 启动 `qs`，stdin 接到 `/dev/null`，stdout/stderr 写入
`$XDG_STATE_HOME/clavis/logs/`。它不会依赖启动终端的 job control。启动器最多等待
8 秒，并以 `qs list` 返回的精确 PID 作为成功依据；进程提前退出、注册超时或 runtime
metadata 无法原子写入都会返回非零。失败时显示最近 50 行并保留完整日志。

三个模式分别使用：

```text
shell-release.log
shell-dev.log
shell-dev-native.log
```

单个文件达到 2 MiB 时轮转，保留 `.1` 到 `.3` 三份备份。日志目录权限为 `0700`，
文件为 `0600`。后台 native 增量构建的输出也写入 `shell-dev-native.log`，构建失败时
旧 Shell 尚未停止。查看当前活动实例或最近启动日志：

```bash
key shell logs
key shell logs --follow
key shell logs --mode release
key shell logs --mode dev
key shell logs --mode dev-native
```

需要实时调试时使用统一的 `--foreground`：

```bash
key shell --foreground --replace
key shell --dev --foreground --replace
key shell --dev --native --foreground --replace
```

前台模式不写后台主日志，信号会转发给 `qs`，命令返回 Quickshell 的真实退出状态。
`--replace` 会精确停止 active metadata 指向的 Clavis 实例。所有路径和原生构件会先
检查，native 构建也会先完成，再停止旧实例；若随后新实例仍启动失败，`current` 保持
不变，但旧进程不会自动恢复。此时执行 `key shell --replace` 恢复正式 Shell。

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
| `help-zh` | 显示中文工作流，不执行操作 |
| `shell` | 替换为已安装 release Shell，后台启动后返回 |
| `shell-foreground` / `sf` | 替换为 release Shell，在前台显示日志 |
| `dev` | 替换为普通源码开发 Shell，后台启动后返回 |
| `dev-foreground` / `df` | 替换为源码开发 Shell，在前台显示日志 |
| `dev-native` / `dn` | 增量编译、替换为原生开发 Shell，后台启动后返回 |
| `dev-native-foreground` / `dnf` | 增量编译并在前台运行原生开发 Shell |
| `build` | 通过 setup.sh 构建，不安装 |
| `test` | 构建并运行完整 CTest |
| `doctor` | 只读检查依赖 |
| `install` | 构建、测试并创建正式 release |
| `releases` | 查看当前版本和 release 列表 |

完成开发后先运行 `just test`（或 `./setup.sh test`）。只有准备让正式桌面使用新快照时
才运行 `just install`（或 `./setup.sh install`）。安装成功后，`just shell`（或
`key shell --replace`）切换回新的正式 release。
