# CPU 功耗读取安全边界

## 默认行为

主 `key` 不安装 file capability，不执行 setcap。sysmon 首先以普通用户读取固定的
`/sys/class/powercap/intel-rapl:*/energy_uj`。不可用时 CPU 功耗为空，并报告
unsupported、permission denied 或 read failed；CPU、内存、磁盘、网络、进程等其余
指标继续工作。

`key doctor cpu-power --json` 同时报告硬件暴露、直接访问、helper 安装和 helper
协议状态。普通安装、更新和回滚从不请求提权。

## 可选 helper

只有用户执行 `key setup cpu-power` 才会先打印所有命令，再运行一次 `sudo -v`。
`--dry-run` 永不调用 sudo。系统集成由以下固定文件组成：

```text
/usr/local/libexec/clavis-rapl-helper
/etc/systemd/system/clavis-rapl-helper.service
/etc/systemd/system/clavis-rapl-helper.socket
/run/clavis-rapl/rapl.sock
```

helper 不接受路径或请求体，不执行 shell，不读取用户文件，只枚举一层固定
`intel-rapl:<package>` 并返回严格 JSON。客户端限制响应大小、校验 JSON、协议、ok 和
非负整数。未知参数退出，缺少恰好一个 systemd socket 时拒绝启动。

服务使用 DynamicUser、NoNewPrivileges、只读系统、ProtectHome/Kernel/Tmp/Devices、
AF_UNIX-only、namespace/realtime 限制和 system-service syscall filter。只在该小进程
的 bounding/ambient set 中保留 `CAP_DAC_READ_SEARCH`；主 key 永不继承。虽然该
capability 本身宽于单一 RAPL 文件，固定代码路径和 mount/service sandbox 将其约束在
不接触用户数据的独立进程中。相比给多功能 key setcap，这个边界可审计且可单独撤销。

socket 为本机所有用户提供只读聚合计数，不提供任意文件代理或控制动作。多用户系统
若认为 package energy 是敏感侧信道，可把 `SocketMode` 收紧并用 systemd group 管理；
默认选择允许普通本地用户读取，是为了替代常见的全局 sysfs ACL，同时保持零命令面。

`key setup cpu-power --disable` 显示并删除系统 unit/helper，再 daemon-reload。普通
release 更新不会重装 helper，因此不会重复授权；协议不同会 fail closed 并由 doctor
报告 `helper_protocol_incompatible`。
