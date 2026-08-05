# IPC

用户命令统一经过 `key-cli`：

```bash
key shell
key ipc show
key ipc call TARGET METHOD [ARGUMENTS...]
```

对应的 Quickshell 调用为：

```text
key shell                 → qs -c clavis -n
key shell --daemon        → qs -c clavis -n -d
key shell --kill          → qs -c clavis kill
key shell --log           → qs -c clavis log
key ipc show              → qs -c clavis ipc show
key ipc call A B ...      → qs -c clavis ipc call A B ...
```

Niri 快捷键和脚本不写裸 `quickshell ipc`，也不写用户源码路径。Shell 内部直接使用
Quickshell API 的地方不需要机械地经过 CLI。
