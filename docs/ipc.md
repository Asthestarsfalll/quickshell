# Clavis IPC 命令

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

keystone cancelRecord
keystone closeAllOthers
keystone currentStyle
keystone dashboard
keystone hub
keystone tools
```

底层 Quickshell 的 `wait`、`listen` 和 `prop` 子命令仍由 `key ipc` 原样转发；
当前 Clavis handlers 没有额外公开 signal 或 property。
