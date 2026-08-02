# 配置边界

## Clavis 自有数据

Clavis 的设置、状态、缓存和生成文件使用自己的 XDG namespace：

```text
$XDG_CONFIG_HOME/clavis/
$XDG_DATA_HOME/clavis/
$XDG_STATE_HOME/clavis/
$XDG_CACHE_HOME/clavis/
$XDG_RUNTIME_DIR/clavis/
```

release 是只读程序资产，Git checkout 不是运行时配置目录。

## Shell 与 Niri Session

`key shell` 只给 Quickshell 进程树注入当前 release 的 QML import 路径。默认后台模式
也只改变该子进程的环境；不会向登录会话导出变量。保存的 stdout/stderr 位于
`$XDG_STATE_HOME/clavis/logs/`。

`key session` 保持调用者真实的 `HOME` 与 XDG 环境，并生成一个很薄的 Niri 入口，
按顺序包含：

1. release 内完整的正式 Niri 默认配置；
2. profile 中生成的 Niri 颜色、光标和效果；
3. Clavis 设置中心生成的 `generated/niri/outputs.kdl`（可选 include）；
4. `$XDG_CONFIG_HOME/clavis/overrides/niri.kdl`；
5. `$XDG_CONFIG_HOME/clavis/profiles/<profile>/niri/override.kdl`。

`outputs.kdl` 只包含以输出名为键的 `scale`，不会生成 mode、刷新率、position 或
transform。设置中心先用临时候选文件替换 session 中的该 include 并执行
`niri validate -c`；验证通过后才原子替换 fragment。旧 fragment 会保存为
`outputs.kdl.last-good`。当前会话若不是 Clavis 生成的 session，或不支持项目默认配置
已经依赖的 KDL include，页面会禁用写入，不会退回到改写用户完整配置。

正式配置的 `startup.kdl` 直接启动 Fcitx5、nm-applet、blueman-applet、
`key shell --no-duplicate` 和 `key clipboard watch`。Clavis 不安装 session supervisor
或 user systemd unit；前者在后台实例完成注册后返回，后者继续作为独立长期进程运行。

除 Niri 外，Kitty、Zsh、Fcitx5、btop、Cava、Yazi 等应用全部读取用户默认配置。
Clavis 不提供 `key run`，不替换 `HOME`、`XDG_CONFIG_HOME` 或 `ZDOTDIR`。

## Matugen

Quickshell 与 Niri 的生成主题保存在 Clavis profile 的 generated 目录。设置中心启用的
外部模板直接写到程序的标准主题位置：btop、Cava、Kitty、Yazi 位于 `~/.config`，
Fcitx5 位于 `~/.local/share/fcitx5/themes/Matugen`。这些只是主题生成结果，不是应用
配置快照。项目不再提供可编辑输出映射或 `key export`。

旧设置只由 `key migrate legacy` 的已知文件映射迁移；目标存在时不会覆盖。
