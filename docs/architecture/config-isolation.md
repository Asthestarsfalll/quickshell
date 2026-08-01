# 配置隔离与主题导出

## XDG 边界

Clavis 只在自己的 namespace 中写入：

```text
$XDG_CONFIG_HOME/clavis/             用户可编辑设置与 overrides
$XDG_CONFIG_HOME/clavis/profiles/    profile 专属应用与 Matugen 配置
$XDG_DATA_HOME/clavis/               profile、壁纸和持久数据
$XDG_STATE_HOME/clavis/              manifest、历史、迁移报告和备份
$XDG_CACHE_HOME/clavis/              可安全删除的缓存
$XDG_RUNTIME_DIR/clavis/             本次登录会话的临时文件、锁和 socket
```

如果 `XDG_RUNTIME_DIR` 不可用，短期 runtime 数据退化到 Clavis 自己的 cache namespace，
不会写回 release 或源码树。release 是只读程序资产，Git checkout 不是运行时配置目录。

## Shell、Session 与应用 adapter

`key shell` 在当前 compositor 中启动 Quickshell，只给该进程树提供 Clavis 路径与私有
QML import 路径，不修改用户的 niri 或应用配置。

`key session` 使用 `niri --session --config <generated-session.kdl>`。配置按顺序包含：

1. release 中只读的完整 Niri 默认配置；
2. profile `generated/niri` 中的颜色、光标和效果；
3. 兼容覆盖 `$XDG_CONFIG_HOME/clavis/overrides/niri.kdl`；
4. profile 覆盖 `$XDG_CONFIG_HOME/clavis/profiles/<profile>/niri/override.kdl`。

它不会把 Clavis 的 `XDG_CONFIG_HOME` 传播给整个桌面，也拒绝在现有 niri 会话中嵌套。

`key run kitty|btop|cava|yazi|fcitx5` 分别使用应用支持的 `--config`、
`--themes-dir`、`-p`、`YAZI_CONFIG_HOME` 或进程级 XDG 环境。运行时合成文件写入
profile `generated/runtime`，层次为完整 release base、generated、用户 override。
Kitty 中的 Zsh 使用 profile 专属 `ZDOTDIR`；Fcitx5 隔离自己的配置和可写数据根，
只继续查找标准系统 data dirs，不读取旧用户 data home 中的 Rime 数据库。

## Matugen 三层

第一层始终生成 Clavis 内部 `colors.json`。第二层只在设置中心明确打开对应模板后生成。
每个 profile 的原生 Matugen 配置位于
`$XDG_CONFIG_HOME/clavis/profiles/<profile>/matugen/config.toml`；用户可以修改
`output_path`，Clavis 根据开关过滤模板并拒绝执行 post-hook。

旧版本的第三层是逐 adapter 外部导出。支持 Kitty、btop、Cava、niri、Yazi、Zsh prompt、
Fcitx5 和桌面 gsettings。每次导出会：

- 检测目标程序、源资源和准确目标；
- 默认拒绝已有或已被修改的目标；
- `--replace` 时先在 Clavis state 中备份；
- 通过同目录临时文件、fsync 和 `os.replace` 原子写入；
- 在 manifest 记录源/目标校验和、原始状态与备份；
- 禁用时只删除未修改的 Clavis 文件，或恢复校验通过的原文件；
- 只热重载相关应用。

桌面 gsettings adapter 记录原始 GVariant 与实际 applied 值。禁用/卸载时只有当前值仍
等于 applied 值才恢复；用户后续修改会被保留。QML 不再直接写 gsettings 或
`~/.Xresources`。

旧导出机制曾把 Fcitx5 作为共享会话服务处理；当前设置中心不再创建新的第三层
export，`key export` 仅为已有 manifest 的兼容清理保留。

## 迁移与兼容

旧设置只由 `key migrate legacy` 的已知文件映射复制；目标存在时报告冲突，不覆盖。
不会复制整个旧 checkout，不会自动删除旧 Matugen 输出或外部配置。详细操作见
`docs/migration/from-legacy-layout.md`。
