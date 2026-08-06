# Niri 配置管理、迁移与回滚

## 所有权

`~/.config/niri/config.kdl` 及用户 include 树归用户。Clavis 只管理
`~/.config/niri/clavis/` 中实际启用的 `colors.kdl`、`effects.kdl`、`outputs.kdl`、
`layout.kdl`、`binds.kdl` 等片段。设置中心未接管的域不会输出默认值；生成文件不是
设置数据库。

迁移以现有 `config.kdl` include 树为基线。官方 `default-config.kdl` 仅用于核对语法
与清除机器专属默认值，不覆盖主配置。迁移前完整备份目录为
`~/.config/niri.backup-YYYYMMDD-HHMMSS/`，保留权限、目录和符号链接。

## 写入事务

1. 在同一文件系统的临时目录生成候选片段和候选主配置。
2. 对完整候选主配置运行 `niri validate -c`。
3. 验证成功后用临时文件、`fsync` 和 `rename` 原子替换，并保存 `.last-good`。
4. 输出预览先走 Niri JSON IPC，再读取实际 outputs 确认。
5. 持久化后等待 `ConfigLoaded`；失败恢复最近有效片段，不用固定延时猜测。
6. 同一域连续调整只保留最新 revision，不能让旧请求覆盖新请求。

设置中心 Niri 页显示主配置、Clavis 目录、版本、socket、validate/include 状态和错误；
可管理 output scale、mode、刷新率、transform、逻辑位置、启停、VRR、启动聚焦，以及
选择性的 layout 与 Clavis 快捷键 override。output scale 是 compositor scale，QML
不会再乘一次。

## 启动项

用户 `startup.kdl` 只保留：

```kdl
// Polkit authentication agent
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
```

`clavis-shell.service` 和 `clavis-clipboard.service` 与 `niri.service` 绑定，分别运行
`key shell --foreground --no-duplicate` 和 `key clipboard watch`。查看日志：

```bash
journalctl --user -u clavis-shell.service
journalctl --user -u clavis-clipboard.service
```

Fcitx5、NetworkManager applet 和 Blueman 使用 `/etc/xdg/autostart` 中发行版条目。
设置中心“开机启动”只读取和管理 `$XDG_CONFIG_HOME/autostart/*.desktop`，不扫描、覆盖或修改系统 Desktop Entry。

## 回滚

片段应用失败会自动恢复 `.last-good`。整次迁移回滚时，先验证备份路径，再将完整备份
恢复为 Niri 配置目录并运行：

```bash
niri validate -c ~/.config/niri/config.kdl
systemctl --user disable clavis-shell.service clavis-clipboard.service
systemctl --user daemon-reload
```

安装不会立即启动新服务，完整启动链路在下一次登录 Niri 后验证。
