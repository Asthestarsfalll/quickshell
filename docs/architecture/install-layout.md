# 安装布局与 release 生命周期

## 三个互不混用的根

源码工作区只用于编辑和构建，推荐位于 `~/Projects/clavis`。构建树默认位于源码根的
`.build/<release>`，可以用 `CLAVIS_BUILD_ROOT` 或 `--build-dir` 改到源码树外。
运行时从不要求源码位于特定目录。

用户程序安装前缀默认为 `$HOME/.local/lib/clavis`：

```text
clavis/
├── current -> releases/2026.07.31.1
└── releases/
    └── 2026.07.31.1/
        ├── bin/key
        ├── lib/qml/Clavis/*
        ├── lib/qml/M3Shapes/*
        ├── share/clavis/qml/*
        ├── share/clavis/assets/*
        ├── share/clavis/scripts/*
        ├── share/clavis/defaults/*
        └── release.json
```

`$HOME/.local/bin/key` 是稳定 launcher，只解析同一 HOME 下的 `current/bin/key`。
它不搜索 `/usr/local/bin`，也不会递归调用自己。`key shell` 才把当前 release 的
`lib/qml` 注入 Clavis 子进程的 `QML_IMPORT_PATH`/`QML2_IMPORT_PATH`；登录环境和
普通 Qt 应用不会看到私有 plugin。

`key ipc` 使用和 `key shell` 完全相同的物理 release QML 根定位 Quickshell 实例。
桌面快捷键不得调用未指定配置的裸 `quickshell ipc`，因为 Quickshell 的实例身份包含
配置绝对路径，移动源码后该身份会发生变化。

## 统一路径解析

同一组语义由以下薄实现映射到各运行环境：

- C++：`core/src/runtime/clavis_paths.*`；
- QML：`Common/Paths.qml`；
- 安装管理器：`packaging/clavis_paths.py`；
- shell：`scripts/lib/clavis-paths.sh`。

支持 `CLAVIS_INSTALL_PREFIX`、`CLAVIS_BIN_HOME`、`CLAVIS_CONFIG_HOME`、
`CLAVIS_DATA_HOME`、`CLAVIS_STATE_HOME`、`CLAVIS_CACHE_HOME`、
`CLAVIS_RUNTIME_HOME`、`CLAVIS_PROFILE`、`CLAVIS_PROFILE_HOME`、
`CLAVIS_GENERATED_HOME` 与 `CLAVIS_QML_IMPORT_HOME`。未设置时按 XDG Base
Directory 解析。路径覆盖值必须是绝对路径；内部协议不使用 `~` 展开。

## 发布事务

日期 release 只接受 `YYYY.MM.DD` 或 `YYYY.MM.DD.N`，比较时解析成年、月、日和
修订号，不进行字符串猜测。`./setup.sh install` 的事务顺序是：

1. 在独立 build 目录配置并构建；
2. 运行完整 CTest；
3. CMake 安装到 `releases/<release>.partial`；
4. 检查必要文件、`release.json`、协议和可执行权限；
5. 执行暂存 `key version --json` smoke test；
6. 原子重命名为不可变 release；
7. 冲突预检后更新稳定 launcher、user units、active-release 与 manifest；
8. 最后原子替换 `current` symlink；
9. 任一步失败时恢复上述可变文件，并移除尚未激活的新 release。

发布事务在切换前保存可变文件快照，因此多文件更新失败不会留下互相矛盾的
launcher、unit、manifest 与 `current`。失败会清理 `.partial`，不会覆盖当前 release。正式安装默认拒绝 dirty
工作树；本地测试需明确 `--allow-dirty`。metadata 记录 source fingerprint，相同
内容的重复安装是幂等的；不同 commit 或内容不得复用同一 release 名称。
同日第二个发布应使用 `.1`。

## Manifest 与所有权

`$XDG_STATE_HOME/clavis/install-manifest.json` 记录 release 中每个文件的相对路径、
SHA-256 与模式，以及 launcher、user units、profile、外部导出、备份、协议和可选
系统集成。release 在发布后去掉 owner write bit。

`key rollback` 只切换通过 metadata 与所有文件校验的 release；随后重启活跃的
`clavis-shell.service`、`clavis-cliphist.service` 和手工启动的 Shell。
`key release remove` 拒绝删除 active release，并拒绝删除含未记录文件的目录。

`key uninstall` 按 manifest 删除。默认保留配置、profile、壁纸、缓存和用户修改过的
导出；`--purge-cache`、`--purge-config`、`--purge-data` 必须显式选择。CPU helper
位于独立系统安全边界，只由 `key setup cpu-power --disable` 撤销；若仍处于已安装状态，
程序卸载会要求先完成该独立撤销步骤。purge 拒绝 `/`、HOME、安装前缀、符号链接或
其他过宽目标，即使这些路径来自显式环境覆盖。若 release 或导出文件已被用户修改，
或 release 中出现未登记文件，卸载会保留它并把原因、原始校验和及恢复动作写入
`preservedItems`；后续卸载可以在内容恢复为已知版本后安全重试，而不会丢失残留来源。

## systemd user units

unit 安装到 `$XDG_CONFIG_HOME/systemd/user`，`ExecStart` 使用稳定 key 的绝对路径。
`ExecStartPre=... key version` 把 release/commit 写入 journal。更新和回滚只对原本活跃
的服务执行 restart，不向用户会话永久导出 QML 路径。`key doctor services` 检查 unit
是否仍引用 `/usr/local/bin/key` 或固定旧 release，并用 `/proc/<pid>/environ` 检查
运行中 Shell 的 `CLAVIS_RELEASE_ROOT`。

## 在线更新边界

本地源码 release、原子 current、rollback 与 artifact 参数接口已经存在。由于当前
没有发布签名与经过验证的 artifact provider，`key update` 不下载任何内容，并在
不改变 current 的前提下明确报错。启用在线更新前必须同时实现签名校验、archive
路径穿越防护、临时下载清理和与本地 release 相同的发布验证。
