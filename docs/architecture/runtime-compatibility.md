# 运行时版本与协议

Clavis 的版本兼容检查集中在 `key-cli` 的 Shell 启动和 release metadata 中。页面不再
逐个执行 `key --version`，也不因为外部命令短暂不可用而替换成醒目的整页红色错误。
数值、图表和列表分别降级为空状态；启动失败写日志并按服务自身策略退避重试。

## Release metadata

每个 Shell release 的 `release.json` 至少包含：

```json
{
  "component": "quickshell",
  "release": "2026.08.03",
  "commit": "…",
  "channel": "stable",
  "sourceFingerprint": "…",
  "buildTime": "…",
  "minimumKeyCli": "0.1.0",
  "minimumKeytop": "0.1.0",
  "shellProtocol": 1,
  "paths": {"qml": "share/clavis/qml", "plugins": "lib/qml", "assets": "share/clavis/assets"},
  "protocols": {"core": 1, "clipboard": 2},
  "dataSchemas": {"config": 1, "manifest": 1, "profile": 1}
}
```

`key shell` 在启动前检查 release 组件、最小 CLI/Keytop 版本、Shell protocol、相对
路径和 plugin 根；不兼容时拒绝启动该 release，并保留当前可用 release。`key release`
负责列出、激活、回滚和移除经过校验的 release。

## 外部命令协议

- 系统监测由 `keytop value`/`keytop stream` 提供，Shell 直接启动 `keytop`，不经过
  `key top` 兼容转发。
- 结构化天气由 `key weather --json` 提供；天气地图的图像 provider 是 Quickshell
  内嵌的 `Clavis.WeatherMap`，两条链路不共享短进程接口。
- 音量、录音、投屏和剪贴板使用稳定的 `key audio`、`key record`、`key cast`、
  `key clipboard` 命令；高频音频可视化仍由内嵌 native plugin 完成。

协议破坏时提升相应的 `protocols` 或 `dataSchemas` 版本，并同步 key-cli、Shell
消费者、协议文档和集成测试。新增可选字段应保持旧消费者可解析；缺失的数值使用
`—`、缺失的图表停在空轨道或占位、缺失的列表使用普通空状态。

## 开发模式

`key shell --dev` 使用当前源码 QML 与稳定 native plugin；`--native` 改用
`.build/dev/lib/qml` 的当前增量 plugin。两种模式的启动、日志和实例注册仍由
`key-cli` 负责，Quickshell 不内置第二份 `key`，也不创建 Key daemon 或常驻 Key socket。
