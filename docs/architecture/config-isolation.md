# 配置与启动所有权

Clavis 设置数据库位于 `$XDG_CONFIG_HOME/clavis/config.json`，它只保存 Shell 自身
设置。Niri 的输出、布局与快捷键配置由用户直接管理，不属于 Clavis 设置中心。

| 路径或机制 | 所有者 | 职责 |
| --- | --- | --- |
| `$XDG_CONFIG_HOME/niri/config.kdl` | 用户 | 主配置与 include 顺序 |
| 用户自己的其他 `.kdl` | 用户 | Niri 输出、布局、快捷键与其他配置 |
| `$XDG_CONFIG_HOME/niri/clavis/colors.kdl` | Clavis | Matugen 生成的 Niri 配色 |
| `$XDG_CONFIG_HOME/niri/clavis/effects.kdl` | Clavis | Shell 背景模糊集成 |
| `$XDG_CONFIG_HOME/clavis/config.json` | Clavis | 设置中心持久化 |
| 两个 `clavis-*.service` | systemd user | 与 `niri.service` 同生命周期的进程 |
| `$XDG_CONFIG_HOME/autostart/*.desktop` | 用户/XDG | 普通桌面应用启动 |

Clavis 不扫描、编辑或持久化 Niri 的输出、布局与快捷键设置，也不把这些字段写入
Shell 配置数据库。

会话由 `niri-session` 启动，`key session` 已删除。Shell 与剪贴板 watcher 的 unit
通过 `WantedBy=niri.service` 安装，且声明 `PartOf=`、`Requisite=` 和 `After=`；安装只
enable，不使用 `--now`。Fcitx5、nm-applet、blueman-applet 由 XDG Autostart 管理，
Polkit 代理仍由用户 `startup.kdl` 启动。

Matugen 颜色写入 `niri/clavis/colors.kdl`，背景效果写入
`niri/clavis/effects.kdl`。外部应用仍读取自己的配置。
