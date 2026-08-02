# 配置与启动所有权

Clavis 设置数据库位于 `$XDG_CONFIG_HOME/clavis/config.json`，它是 Clavis 管理项的
source of truth。Niri KDL 是派生结果，Niri IPC 是当前运行事实；三者不能互相替代。

| 路径或机制 | 所有者 | 职责 |
| --- | --- | --- |
| `$XDG_CONFIG_HOME/niri/config.kdl` | 用户 | 主配置与 include 顺序 |
| 用户自己的其他 `.kdl` | 用户 | 未交给 Clavis 的 Niri 配置 |
| `$XDG_CONFIG_HOME/niri/clavis/*.kdl` | Clavis | 已明确启用的派生域 |
| `$XDG_CONFIG_HOME/clavis/config.json` | Clavis | 设置中心持久化 |
| 两个 `clavis-*.service` | systemd user | 与 `niri.service` 同生命周期的进程 |
| `$XDG_CONFIG_HOME/autostart/*.desktop` | 用户/XDG | 普通桌面应用启动 |

Clavis 不解析后重排整份 `config.kdl`，不删除未知注释，也不把未接管字段写成默认值。
片段写入采用候选树、`niri validate`、原子替换、`.last-good` 和 `ConfigLoaded` 确认。

会话由 `niri-session` 启动，`key session` 已删除。Shell 与剪贴板 watcher 的 unit
通过 `WantedBy=niri.service` 安装，且声明 `PartOf=`、`Requisite=` 和 `After=`；安装只
enable，不使用 `--now`。Fcitx5、nm-applet、blueman-applet 由 XDG Autostart 管理，
Polkit 代理仍由用户 `startup.kdl` 启动。

Matugen 颜色写入 `niri/clavis/colors.kdl`，背景效果写入
`niri/clavis/effects.kdl`。外部应用仍读取自己的配置。详细迁移与回滚见
[Niri 配置管理](../niri-configuration.md)。
