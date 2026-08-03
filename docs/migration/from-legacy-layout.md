# 从旧源码运行布局迁移

旧布局可能同时把 `~/.config/quickshell` 当作 Git checkout、运行时 QML 根和设置来源，
并把 key/plugin 复制到 `/usr/local` 与系统 Qt 目录。新安装不会自动删除这些内容。

## 1. 只读审计

先完成各仓库的用户级安装，再生成报告：

```bash
./setup.sh install
~/.local/bin/key doctor legacy --json
```

若 `command -v key` 仍显示 `/usr/local/bin/key`，先把 `$HOME/.local/bin` 放到
`PATH` 前部并执行 `hash -r`。确认新入口和 `current` 正常后，再依据 legacy report
单独清理旧的 root-owned `key`；不要让用户服务继续通过 PATH 命中旧二进制。

报告检测旧 checkout、`/usr/local/bin/key`、`/usr/lib{,64}/qt6/qml/{Clavis,M3Shapes}`、
旧 user unit、Quickshell cache/settings、Matugen 输出以及已知外部应用主题。检测到路径
不代表 Clavis 拥有它；命令不做修改。

## 2. 设置迁移

先 dry-run：

```bash
key migrate legacy --dry-run
key migrate legacy
```

迁移器只复制能够确认语义的 personalization、UI preference、quick toggle、tray 和
idle policy 文件到 `$XDG_CONFIG_HOME/clavis`。目标已存在时报告 conflict，不覆盖。
报告保存在 `$XDG_STATE_HOME/clavis/migrations`。它不会复制整个 Git checkout，也不会
删除旧文件。

## 3. 验证新运行时

```bash
key version --json
key shell
keytop
keytop value --format json
```

确认 `key` 来自 `~/.local/bin`，Shell 能加载 current release 的私有 plugin，且系统
监测直接由独立 `keytop` 提供。新安装会替换旧 unit，并启用绑定 `niri.service` 的 Shell 与剪贴板
service；不会在安装时立即启动。Niri 主配置迁移见 [配置管理](../niri-configuration.md)。

旧 root-owned 文件只应在审计其来源后手动清理；普通安装和迁移不会请求 sudo。示例
路径必须以 doctor 实际报告为准，不要盲目复制命令：

```text
/usr/local/bin/key
/usr/lib64/qt6/qml/Clavis
/usr/lib64/qt6/qml/M3Shapes
```

## 4. 移动源码（本轮会话结束后）

不要在仍以旧目录为 cwd 的工具会话中移动。确认 Git 状态后手动执行：

```bash
git -C ~/.config/quickshell status
mkdir -p ~/Projects
mv ~/.config/quickshell ~/Projects/clavis
cd ~/Projects/clavis
codex resume --all
```

`AGENTS.md` 在仓库根目录，会随仓库移动。Codex 会话数据库不在仓库中，不需要复制或
修改；恢复旧会话时选择新 cwd。新会话通常更少携带旧绝对路径。移动完成并验证
`git -C ~/Projects/clavis status` 前，不要删除任何看似重复的目录。

## 5. 旧外部主题

旧 Matugen 输出仍由 legacy doctor 报告，不会自动删除。新系统根据设置中心开关直接
更新各应用的标准主题文件；它不会复制或托管这些应用的完整配置。
