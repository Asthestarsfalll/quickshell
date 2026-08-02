# Clavis Shell

Clavis 是以 QML/Quickshell 构建的 Wayland 桌面 Shell，原生 backend、`key`
CLI、M3 shapes 与系统监测核心位于 `core/`。源码工作区与运行时安装完全分离；
仓库可放在任意绝对路径，推荐 `~/Projects/clavis`。

## 安装

Arch Linux 是当前优先支持的平台。先查看依赖，不会安装任何包：

```bash
./setup.sh doctor
./setup.sh deps
```

只有明确执行 `./setup.sh deps --install` 才会通过 pacman 请求 `sudo`。Clavis
本身的配置、构建、测试与安装始终是用户级操作：

```bash
./setup.sh install
```

也可以指定日期 release：

```bash
./setup.sh install --release 2026.07.31
./setup.sh install --release 2026.07.31.1
```

正式 release 默认拒绝未提交工作树，避免同一 commit 隐藏不同产物。仅本地验证
可明确使用 `--allow-dirty`；release metadata 会记录 dirty 状态与内容指纹。

安装会先构建并运行 CTest，再暂存到 `releases/<version>.partial`；验证版本握手后
原子发布并切换 `current`。不会向系统 Qt QML 目录复制 plugin，也不会覆盖当前正在
运行的 release。完整依赖见 [docs/dependencies.md](docs/dependencies.md)。

确保用户级命令目录排在旧系统安装之前，并刷新 shell 的命令缓存：

```bash
export PATH="$HOME/.local/bin:$PATH"
hash -r
command -v key
```

最后一条应输出 `$HOME/.local/bin/key`，而不是旧的 `/usr/local/bin/key`。

## 使用

`key` 是唯一用户 CLI，稳定入口默认安装为 `~/.local/bin/key`：

```bash
key version --json
key shell
key shell --dev
key shell --dev --native
key shell --foreground
key shell logs
key ipc list
key ipc call keystone dashboard
key session
key top
key doctor
key doctor legacy
key rollback
key release list
```

`key shell` 从 `current` 指向的不可变 release 运行 Shell；源码工作区中的未提交修改
不会影响它。`key shell --dev` 则从当前目录向上寻找 Clavis 仓库，直接加载源码中的
QML、JavaScript、脚本与资源。三种 Shell 模式默认都在完成实例注册后转入后台并返回
终端；加 `--foreground` 可在前台观察实时输出并用 `Ctrl+C` 结束。后台日志可通过
`key shell logs` 或 `key shell logs --follow` 查看。

`key session` 使用 release 内完整的
Niri 默认配置启动会话，并拒绝在已有 niri 会话中递归启动。它保持真实 `HOME` 和
用户的 XDG 路径；Kitty、Zsh、Fcitx5、btop、Yazi 等程序读取用户自己的配置。

完整 IPC target 与 method 清单见 [docs/ipc.md](docs/ipc.md)。

Niri 快捷键应调用稳定入口，例如
`spawn-sh "$HOME/.local/bin/key ipc call keystone dashboard"`，不要调用裸
`quickshell ipc`。后者按配置绝对路径选择实例，源码迁移或 release 更新后容易命中
错误实例；`key ipc` 优先验证 `$XDG_RUNTIME_DIR/clavis/active-shell.json` 并按精确 PID
路由到当前正式或开发实例，陈旧记录会被清理，随后安全回退到 `current`。

从 TTY 或显示管理器启动完整 Clavis 管理会话时运行
`exec "$HOME/.local/bin/key" session`。如果已经位于 Niri 会话中，只运行
`$HOME/.local/bin/key shell`，不要嵌套第二个 compositor。

## 目录边界

默认路径如下；所有 XDG 根目录和 `CLAVIS_*_HOME` 均可覆盖：

```text
~/.local/bin/key
~/.local/lib/clavis/current -> releases/<date-release>
~/.local/lib/clavis/releases/<date-release>/
~/.config/clavis/
~/.config/clavis/profiles/default/
~/.local/share/clavis/profiles/default/
~/.local/state/clavis/
~/.local/state/clavis/logs/
~/.cache/clavis/
$XDG_RUNTIME_DIR/clavis/
```

原生 `Clavis.*` 与 `M3Shapes` plugin 位于每个 release 的 `lib/qml/`，import
路径只注入 Clavis 子进程。详细布局见
[安装布局](docs/architecture/install-layout.md) 与
[配置隔离](docs/architecture/config-isolation.md)。

## 主题与 Matugen 配置

Matugen 始终生成 Clavis/Quickshell 配色。设置中心“高级”页可分别启用 btop、Cava、
Kitty、Fcitx5、Niri 与 Yazi 模板。Niri 配色写入 Clavis profile 的 generated 目录；
其他程序的主题文件直接写入它们在 `~/.config` 或 `~/.local/share` 下的标准位置，
与重构用户级 release 架构之前的行为一致。Clavis 不托管这些程序的完整配置。

## 更新、回滚与卸载

当前可靠入口是本地源码 release。在线 `key update` 在没有签名 artifact provider
前会明确拒绝，不会伪装成安全下载器。

```bash
key rollback [RELEASE]
key release remove OLD_RELEASE --dry-run
key release remove OLD_RELEASE
key uninstall --dry-run
key uninstall
key uninstall --purge-cache
```

回滚会先验证 manifest 中的 release 文件，再原子切换并重启运行中的 Shell 与用户
服务。普通卸载保留配置、数据和个人壁纸；清除配置或数据必须显式使用相应 purge
参数。系统级 CPU helper 是独立集成，不属于普通卸载范围。
如果已经启用 helper，应先执行 `key setup cpu-power --disable`，再卸载用户程序。

## CPU 功耗（可选）

普通 `key` 没有 capability，RAPL 不可读时 `key top` 的其余指标继续工作：

```bash
key doctor cpu-power --json
key setup cpu-power --dry-run
key setup cpu-power
key setup cpu-power --disable
```

只有最后两个非 dry-run 命令会清楚列出操作并请求一次 `sudo`。安全边界和取舍见
[CPU 功耗安全](docs/architecture/cpu-power-security.md)。

## 开发与验证

```bash
key shell --dev
key shell --dev --native
key shell --dev --foreground --replace
key shell logs --mode dev
key shell logs --follow
./setup.sh configure
./setup.sh build
./setup.sh test
qmllint -I . Common/Paths.qml Services/RuntimeCompatibilityService.qml
bash tests/test_matugen_templates.sh
```

普通开发模式直接监视源码，QML 与资源修改由 Quickshell 原生 reload 立即加载；它仍
使用 `current` release 的 `bin/key` 和 `lib/qml` 原生模块。修改 `core/` 时使用
`--native`：命令会在 `.build/dev` 做增量 CMake 构建，并以新进程加载更新后的共享库，
不会创建 release 或切换 `current`。另一套完整 Shell 正在运行时必须显式加
`--replace`，该选项只停止记录到的 Clavis 实例。新实例启动失败时不会改变 `current`，
但已停止的旧实例不会自动恢复；运行 `key shell --replace` 回到正式版。

后台启动将 stdout/stderr 分模式写入 `$XDG_STATE_HOME/clavis/logs/`，单个日志到达
2 MiB 后轮转并保留 3 份备份。启动器在最多 8 秒内按 Quickshell 实例 PID 验证注册，
失败时返回非零并打印最近 50 行。前台模式不写这些后台日志，而是保留真实退出码并
将 `SIGINT`、`SIGTERM` 和 `SIGHUP` 转发给 Quickshell。

`just` 是可选的开发工作流缩写，不是 Clavis 运行依赖。安装了 `just` 时，从仓库任意
子目录执行 `just` 或 `just --list` 可查看英文命令说明；执行 `just help-zh` 只显示
中文命令说明。`just shell`、`just dev`、`just dev-native` 是后台切换入口；`just sf`、
`just df`、`just dnf` 分别以前台方式启动并显示实时日志。未安装时上述 `key` 与
`setup.sh` 命令照常可用。详细说明见
[开发工作流](docs/development.md)。

不要编辑生成的 build 目录。涉及 `core/` 的改动需重新构建；纯 QML 改动至少运行
一次 `qmllint`。协议与能力模型见
[运行时兼容](docs/architecture/runtime-compatibility.md)。旧安装迁移见
[迁移指南](docs/migration/from-legacy-layout.md)。

## 移动源码仓库

确认工作区状态后，可在本次开发会话结束时手动移动：

```bash
git -C ~/.config/quickshell status
mkdir -p ~/Projects
mv ~/.config/quickshell ~/Projects/clavis
cd ~/Projects/clavis
codex resume --all
```

`AGENTS.md` 会随 Git 仓库一起移动；不需要复制 Codex 会话数据库。恢复旧会话时选择
新的工作目录。通常新会话比携带大量旧绝对路径历史更干净。确认迁移成功前，不要
删除或覆盖任何旧目录。
