# CPU 功耗读取边界

RAPL 属于独立的 `keytop` 能力，不属于 `key-cli`、Quickshell release 或任何 Key
daemon。`keytop` 以普通用户尝试读取固定的 Linux powercap 接口；不可读时报告
unsupported、permission denied 或 read failed，并继续提供其他系统指标。

```bash
keytop value --modules cpu --format json
keytop value --modules cpu,system,memory --format json
```

本次拆分不新增常驻 `key.service`、Key socket、setcap 或自动 sudo 流程。若发行版未来
需要独立的 RAPL 权限集成，应作为 `keytop` 的明确可选打包/系统组件单独设计、审核和
卸载；普通 `key install`、Shell release 安装、更新和回滚不得改变系统权限。
