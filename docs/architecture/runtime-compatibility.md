# 运行时版本、协议与能力

每个 release 的 `release.json` 和 `key version --json` 都提供 release、commit、UTC
build time、channel、协议、feature 列表、mutable data schema 和 dependency manifest
版本。当前协议为：

```json
{
  "core": 1,
  "clipboard": 2,
  "sysmon": 1,
  "raplHelper": 1
}
```

release 日期用于运维与展示，不作为协议兼容判断。`RuntimeCompatibilityService.qml`
是 QML 的唯一握手入口，提供 `keyAvailable`、`release`、`commit`、
`protocolCompatible()`、`hasFeature()`、`clipboardCompatible` 和
`sysmonCompatible`。

处理规则：

- key 不存在或 JSON 无效：明确错误并禁用依赖 backend 的模块；
- core 或必需子协议不同：禁用对应模块；
- 必需 feature 缺失：禁用该功能；可选 feature 缺失只降级；
- Shell 与 key 日期或 commit 不同但协议兼容：显示 stale-service 警告；
- `Clavis.Runtime` plugin 导出编译时 release/commit；它与 Shell 不同视为安装损坏；
- Clipboard 的 inspect、MIME restore 与 MIME-aware store 检查保留，但从中央服务读取；
- SystemMonitor 在 sysmon 握手完成前不启动 stream。

`key shell` 同时设置 `CLAVIS_SHELL_RELEASE`/`CLAVIS_SHELL_COMMIT`，并且私有 plugin、
QML 与 key 都从同一 current release 解析。这是正常安装中避免“新 QML + 系统旧
plugin”的主要保证。

兼容性升级约定：向后兼容的新能力添加 feature；破坏命令或 JSON 语义时提升相应
子协议；改变所有管理命令共同语义时提升 core。QML 必须按协议和 feature 判断，
不得按日期硬编码功能可用性。
