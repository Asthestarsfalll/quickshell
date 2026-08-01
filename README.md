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
key ipc list
key ipc call keystone dashboard
key session
key run kitty
key run btop
key run cava
key run yazi
key run fcitx5
key top
key doctor
key doctor services
key doctor legacy
key rollback
key release list
```

`key shell` 在现有 niri 会话中运行 Shell。`key session` 启动 Clavis 管理的独立
niri profile，并拒绝在已有 niri 会话中递归启动。`key run` 只给目标应用传入其
官方支持的配置参数或精确环境变量，不会替换整个桌面会话的
`XDG_CONFIG_HOME`。

完整 IPC target 与 method 清单见 [docs/ipc.md](docs/ipc.md)。每个 profile 的
Matugen 输出路径可在
`$XDG_CONFIG_HOME/clavis/profiles/<profile>/matugen/config.toml` 中编辑。

Niri 快捷键应调用稳定入口，例如
`spawn-sh "$HOME/.local/bin/key ipc call keystone dashboard"`，不要调用裸
`quickshell ipc`。后者按配置绝对路径选择实例，源码迁移或 release 更新后容易命中
错误实例；`key ipc` 始终解析当前 release，并和 `key shell` 使用同一个 QML 根。

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
~/.cache/clavis/
$XDG_RUNTIME_DIR/clavis/
```

原生 `Clavis.*` 与 `M3Shapes` plugin 位于每个 release 的 `lib/qml/`，import
路径只注入 Clavis 子进程。详细布局见
[安装布局](docs/architecture/install-layout.md) 与
[配置隔离](docs/architecture/config-isolation.md)。

## 主题与 Matugen 配置

Matugen 默认只生成 Clavis 内部配色；在个性化设置中启用 Kitty、btop、Cava、
Yazi、niri、Fcitx5 或 Zsh prompt 后，对应模板会按当前 profile 的
`matugen/config.toml` 写入用户可编辑的绝对输出路径。设置中心“高级”页可以直接
打开该配置，并在修改后重新生成配色。Clavis 管理的应用通过 `key run` 消费这些
文件，不会覆盖原有的 `~/.config/<application>`。

以下 `key export` 命令只为清理旧版已经写入外部应用目录的 manifest 记录而保留，
不再出现在设置中心，也不是新 profile 的主题配置方式：

```bash
key export kitty --status
key export kitty --dry-run
key export kitty
key export kitty --replace   # 冲突时明确备份并替换
key export kitty --disable
```

旧导出会记录目标、备份与校验和；用户修改过的文件不会在禁用或卸载时被删除。
Fcitx5 在 Clavis 会话中由 `key run fcitx5` 使用 profile 专属配置和数据根启动；
系统词库仍通过标准系统数据路径可见，但不会读取或复制旧用户目录中的 Rime
数据库、缓存或同步 ID。

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
./setup.sh configure
./setup.sh build
./setup.sh test
qmllint -I . Common/Paths.qml Services/RuntimeCompatibilityService.qml
bash tests/test_matugen_templates.sh
```

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
