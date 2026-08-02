# Clavis IPC 命令

`key ipc` 不要求调用者知道 Quickshell 的配置绝对路径。它先校验
`$XDG_RUNTIME_DIR/clavis/active-shell.json` 并按精确 PID 路由到当前正式或源码开发
实例；记录陈旧或不存在时回退到 `current` release。Niri 快捷键和脚本因此在
`key shell` 与 `key shell --dev` 之间切换时保持不变。

后台启动只有在 `qs list` 返回新进程的精确 PID 后才原子写入活动记录。后台监视器或
下一次 IPC 读取会清理由正常退出、崩溃或 PID 复用留下的陈旧记录；启动日志路径也只
允许指向 `$XDG_STATE_HOME/clavis/logs/` 下三个固定的模式日志。

Clavis IPC 始终通过当前 release 的稳定入口调用：

```bash
key ipc list
key ipc show
key ipc call TARGET METHOD [ARGUMENTS...]
```

`list` 是便于从 DMS 迁移的 `show` 别名。不要在快捷键或独立窗口中调用裸
`qs ipc` 或 `quickshell ipc`，因为 Quickshell 使用配置绝对路径识别实例。

## Targets

```text
lock open
lock isLocked

spotlight toggle
spotlight open
spotlight close
spotlight web
spotlight openMode MODE

wallpaper set PATH
wallpaper setForScreen PATH SCREEN
wallpaper clear
wallpaper clearForScreen SCREEN
wallpaper previous
wallpaper next
wallpaper random
wallpaper setFolder PATH

weather-map reloadCredentials
weather-map mapTilerStatus

sidebar open left|right
sidebar close left|right
sidebar toggle left|right

keystone cancelRecord
keystone closeAllOthers
keystone currentStyle
keystone dashboard
keystone hub
keystone tools
```

底层 Quickshell 的 `wait`、`listen` 和 `prop` 子命令仍由 `key ipc` 原样转发；
当前 Clavis handlers 没有额外公开 signal 或 property。
