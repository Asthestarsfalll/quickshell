# 安装布局与 release 生命周期

## 三个互不混用的根

源码工作区只用于编辑和构建，推荐位于 `~/Projects/clavis`。构建树默认位于源码根的
`.build/<name>`，也可以用 `--build-dir` 放到其他位置。Shell release 由
`quickshell` 构建，注册、切换和回滚由同级 `key-cli` 管理；release 内不再复制一份
`key`。

用户级运行时根默认为 `$HOME/.local/lib/clavis`：

```text
clavis/
├── current -> releases/2026.08.03
└── releases/
    └── 2026.08.03/
        ├── lib/qml/Clavis/*
        ├── lib/qml/M3Shapes/*
        ├── share/clavis/qml/*
        ├── share/clavis/assets/*
        ├── share/clavis/scripts/*
        ├── share/clavis/defaults/*
        ├── share/clavis/libexec/clavis_paths.py
        └── release.json
```

`$HOME/.local/bin/key` 是 `key-cli` 的稳定入口，实际程序来自 `key-cli` 自己的安装
位置；`$HOME/.local/lib/clavis/current` 只指向 Shell runtime。Keytop、Zsh 主题和
Fcitx5 主题是独立组件，不进入上述 release。`key shell` 只把当前 release 的
`lib/qml` 注入 Shell 子进程，不向系统 Qt QML import 根复制 plugin。

## 统一路径解析

运行时路径由 `key-cli` 的 `packaging/clavis_paths.py` 与 Quickshell 的
`core/src/runtime/clavis_paths.*` 对齐；QML 和 shell 侧分别使用
`Common/Paths.qml`、`scripts/lib/clavis-paths.sh`。路径覆盖值必须是绝对路径，内部
协议不使用 `~` 展开。`CMAKE_INSTALL_PREFIX`/`DESTDIR` 只影响组件的系统安装，不能
改变已经安装的用户级 release 根。

## 发布事务

`quickshell/setup.sh install` 的职责是：

1. 检查构建和运行依赖；
2. 增量构建 Shell；
3. 把 CMake 产物安装到 `releases/<release>.partial`；
4. 检查 `release.json`、Shell 入口、plugin、assets 和相对路径；
5. 调用外部 `key release install-finalize RELEASE --partial PATH`。

最后一步由 `key-cli` 完成 release 注册、manifest、`current` 的原子切换以及用户
unit 的渲染。失败时保留原有 `current`，并清理未激活的 `.partial`。安装器不会隐式
运行 CTest、smoke 或全量 qmllint；开发者需要显式运行：

```bash
./setup.sh test
./setup.sh smoke
./setup.sh install
```

正式安装默认拒绝 dirty 工作树；只有明确的本地临时验证才使用 `--allow-dirty`。

## Manifest 与所有权

release manifest 由 `key-cli` 生成，记录组件、版本、commit、source fingerprint、
协议、依赖版本和每个安装文件的校验值。`key release list`、`key rollback` 和
`key release remove` 只操作精确的 release 目录，不执行宽泛递归删除；卸载时保留被
用户修改或未被 manifest 记录的文件并报告原因。

稳定 CLI、Keytop 和主题包各自使用自己的安装 manifest。组件 provider 只允许明确
registry 中的官方组件，更新前检查 Git 工作树并使用 `git pull --ff-only`，不会执行
`git reset --hard`、`git clean` 或任意 URL 脚本。

## 会话与开发模式

安装可以部署 `clavis-shell.service` 和 `clavis-clipboard.service` 模板；它们由
`key-cli` 使用稳定 `key` 路径渲染，只 enable，不在安装时立即启动。后台 Shell 日志
写入 `$XDG_STATE_HOME/clavis/logs/`，活动实例记录写入 `$XDG_RUNTIME_DIR/clavis/`。

`key shell --dev` 使用当前源码 QML 与稳定 release 的原生 plugin；
`key shell --dev --native` 使用 `quickshell/.build/dev/lib/qml` 中的增量 plugin。
两者都不把 `current` 指向源码，也不创建临时 release。

## 在线更新边界

本地 source provider 可管理 `keytop`、`clavis-zsh-theme` 和
`clavis-fcitx5-theme`。没有签名 artifact provider 前，`key update` 不下载未知内容，
也不伪装成 pacman 或 AUR helper。
