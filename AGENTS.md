# Clavis 仓库工作约定

## 适用范围与当前状态

本文件适用于整个仓库。Clavis 已完成从旧源码运行布局到用户级 release 架构的迁移；
后续任务按正式产品仓库处理，不再执行迁移期的个人配置归档、伪 HOME 或兼容性拼装。

开始修改前先确认请求属于哪一类：

- **分析、审查、诊断**：只读检查并报告，不修改代码、不安装 release。
- **实现、修复、重构**：修改源码并按风险验证；默认不提交、不安装 release。
- **提交**：仅在用户明确要求提交时执行，提交信息遵循本文约定。
- **部署、安装 release**：仅在用户明确说“部署”“安装 release”或等价表述时执行。

不要把 Git commit、构建目录和已安装 release 混为一谈：Git 保存源码历史，`.build/`
保存可再生成的构建产物，release 保存实际运行快照。

## 产品与术语

Clavis 是以 QML/Quickshell 构建的 Wayland 桌面 Shell。`shell.qml` 是极薄入口，
`AppShell.qml` 装配 Bar、Keystone、Sidebars、Launcher、Lock 等顶层模块。

`Keystone` 是仿照 iOS Dynamic Island 的顶部交互区域。交流中的“灵动岛”、
“Dynamic Island”、“dynamic”、“daynamic”或“钥石”，没有额外说明时均指
`Modules/Keystone/`。

`key` 是唯一稳定 CLI；用户级入口为 `~/.local/bin/key`，实际程序来自
`~/.local/lib/clavis/current` 指向的 release。

## 目录与分层

```text
.
├── shell.qml / AppShell.qml     # Shell 入口与顶层装配
├── Common/                      # 主题、尺寸、路径、共享状态、纯函数
├── Components/                  # 极简无状态基础元素
├── Widgets/                     # 可复用展示控件
├── Services/                    # 系统状态、持久化和业务服务单例
├── Modules/                     # 独立业务模块与页面
├── assets/                      # 图标、图片、字体、shader 等静态资源
├── scripts/                     # 按用途分类的运行脚本
├── matugen/                     # 固定 Matugen 配置与模板
├── core/                        # C++ backend、QML plugin、key CLI 与测试
├── packaging/                   # release manager、默认 Niri 配置、依赖清单
├── tests/                       # QML、shell、Python 与集成测试
└── docs/                        # 架构、协议和使用文档
```

分层规则：

- `Modules/` 存放大型业务功能；侧边栏、Keystone、启动器、锁屏等放在这里。
- `Widgets/` 只放可复用展示控件，不直接创建 `Process`、调用
  `Quickshell.execDetached` 或执行系统命令。
- `Services/` 承担系统交互与数据逻辑；UI 通过服务暴露的属性和方法消费数据。
- `Common/` 提供全局 token、路径和纯工具。QML 引用资源或脚本时优先使用
  `Common/Paths.qml`。
- `Components/` 只放极简、无状态基础元素，例如 SVG 和 Material Symbol 包装。
- `scripts/` 必须按用途放入子目录，不在根目录散放新脚本。
- 不恢复旧的 `Widget/`、`config/`、`JS/` 或仓库内 `local/` 配置快照目录。
- 自动化与 smoke test 放在 `tests/`；根目录只保留测试框架必须直接加载的入口。

## 配置所有权与 Niri 会话

Clavis **只托管 Niri 的完整默认配置**，正式源位于：

```text
packaging/defaults/profiles/default/niri/
```

这里应保留完整的 `config.kdl`、`binds.kdl`、`output.kdl`、`startup.kdl`、
`windowrule.kdl`、`animations.kdl`、`theme.kdl` 等文件。不要放入个人输出、备份、
临时文件、DMS 目录或机器专属绝对路径。

`key session` 保持调用者真实的 `HOME` 和 XDG 环境，只生成一个薄的 Niri 会话入口，
按顺序叠加 release 默认配置、generated Niri 配色/光标/效果以及用户 override。

`startup.kdl` 是会话服务的唯一管理入口，直接启动 Fcitx5、nm-applet、
blueman-applet、`key shell --no-duplicate` 和 `key clipboard watch`。禁止重新引入：

- 伪 HOME、`legacy-home` 或全局替换 `XDG_CONFIG_HOME`；
- `key run`、应用 adapter、profile application sandbox；
- Kitty、Zsh、Fcitx5、btop、Cava、Yazi 等完整配置副本；
- Zsh prompt 程序或 prompt 配色模板；
- session supervisor；
- `clavis-shell.service`、`clavis-cliphist.service` 等会话 user systemd unit；
- 向 `/usr/lib{,64}/qt6/qml` 或其他系统 Qt import 根复制 plugin。

除 Niri 外，应用一律读取用户原本的配置。不得为了“让体验一致”复制或修改真实
`~/.config`、`~/.zshrc`、Fcitx5 词库或其他个人配置，除非用户明确要求修改这些
具体目标。

Niri 快捷键调用 Shell IPC 时使用稳定入口 `$CLAVIS_KEY ipc call ...`。不要调用裸
`quickshell ipc`，也不要把仓库路径或某个 release 的物理路径写入配置。

## Matugen 边界

Matugen 使用仓库内固定的 `matugen/config.toml` 和模板，不生成可编辑的 profile
输出映射。行为约定如下：

- Quickshell 和 Niri 配色写入 Clavis profile 的 `generated/` 目录；
- btop、Cava、Kitty、Yazi 主题写入用户标准 `~/.config` 位置；
- Fcitx5 主题写入 `~/.local/share/fcitx5/themes/Matugen`；
- 设置中心“高级”页只控制各程序是否继续生成主题；关闭开关不删除已有文件；
- Matugen 只管理主题生成结果，不取得外部应用完整配置的所有权；
- 不恢复 `key export`、自定义输出位置编辑器或 Zsh prompt 模板。

修改输出路径或模板集合时，同时更新脚本、设置模型、UI、测试和文档。

## C++、Plugin 与协议

Qt/C++ 代码统一位于 `core/`：通用 backend 在 `core/src/`，QML wrapper 在
`core/plugin/<name>/`，CLI 在 `core/cli/`。自制 plugin 使用 `qt_add_qml_module`
导出 URI，并只安装到 release 私有 `lib/qml/`。

系统监测以 `core/src/sysmon/` 为唯一数据核心。plugin、`key sysmon` 与 `key top`
必须复用 collector、sampler、类型和序列化，不得各自重新读取 `/proc`、`/sys` 或
重复计算采样差值。左侧系统页只通过 `Services/SystemMonitorService.qml` 消费
`key sysmon stream` JSONL；展示组件不得直接 import `Clavis.Sysmon` 或自行执行命令。

路径语义必须在以下实现中保持一致：

- `core/src/runtime/clavis_paths.*`
- `Common/Paths.qml`
- `packaging/clavis_paths.py`
- `scripts/lib/clavis-paths.sh`

不得引入仓库绝对路径。协议或稳定 JSON 字段发生变化时，必须同步协议文档和集成测试；
不能静默破坏现有消费者。

## 开发、构建与测试

所有命令默认从仓库根目录执行：

```bash
./setup.sh doctor      # 只检查依赖并显示建议
./setup.sh configure   # 配置独立构建目录
./setup.sh build       # 构建 backend、key 和私有 plugin
./setup.sh test        # 运行 CTest
./setup.sh install     # 构建、测试并安装新的用户级 release
```

测试要求按改动范围递增：

- 文档或纯数据变更：至少执行相关静态检查和 `git diff --check`。
- 纯 QML 变更：对修改文件执行 `qmllint -I .`；有对应测试时一并运行。
- shell/Python 变更：执行语法检查和对应 `tests/` 用例。
- `core/`、CLI 或 plugin 变更：执行 `./setup.sh build` 和 `./setup.sh test`。
- Niri 默认配置变更：执行 `niri validate -c
  packaging/defaults/profiles/default/niri/config.kdl`。
- Matugen 变更：执行 `bash tests/test_matugen_templates.sh`。
- 安装架构变更：在临时 HOME/XDG 中验证 fresh install、重复 install、rollback、
  release remove 和 uninstall dry-run。

界面开发优先使用 `key shell --dev`；验证已安装版本使用 `key shell`。不要编辑
`.build/`、生成的 `session.kdl` 或 release 内文件来“修复”源码问题。

正式 Shell、源码 Shell 与原生开发的标准入口分别是 `key shell`、`key shell --dev`
和 `key shell --dev --native`。源码模式从当前目录向上发现仓库；不要把 `current`
指向源码或为热重载创建 dirty release。普通源码模式复用 current release 的 key 与
原生 QML plugin；原生模式只在 `.build/dev` 增量构建。另一套完整 Shell 已运行时，
只有用户明确使用 `--replace` 才按实例 PID 替换；禁止 `pkill qs`/`pkill quickshell`。
`key ipc` 的 runtime 活动实例协议发生变化时，应同步管理器测试与开发文档。

仓库根 `justfile` 只提供可选工作流缩写，不能承载 `key shell --dev` 的核心环境或路径
逻辑。公开 recipe 的 doc comment 使用英文，使 `just` 和 `just --list` 默认只显示英文；
`just help-zh` 维护对应的纯中文命令帮助。新增或修改 recipe 时必须同步两种说明。

`key top` 依赖 `ncursesw`。普通 `key` 不得获得 capability；CPU 功耗 helper 只能由
用户明确执行 `key setup cpu-power` 安装，任何 AI 任务不得擅自请求 sudo。

## Release 与 vibe coding 工作流

默认实现任务只修改和验证源码，**不自动安装 release**。以下行为需要用户明确授权：

- 创建 Git commit；
- 执行 `./setup.sh install`；
- 使用 `--allow-dirty` 安装；
- rollback、删除旧 release 或卸载；
- 重启/结束当前 Niri、Quickshell 或其他用户进程。

只有用户明确说“部署”“安装 release”“让当前桌面使用这些修改”等表述时，AI 才执行
安装。安装前应完成相应测试；正式安装优先使用干净工作树。不要为了每个 commit
创建 release，也不要仅因改了 QML 就推断用户希望更新正在运行的桌面。

通常直接执行：

```bash
./setup.sh install
```

让安装器自动选择当天的 `YYYY.MM.DD[.N]`。只有用户指定版本号、需要复现特定构建或
测试 release 机制时才传 `--release`。`--allow-dirty` 仅用于用户明确授权的临时真实
会话验证，不能作为长期运行或可靠回滚点。

安装成功后用 `key version --json`、`key release list` 和相关运行检查验证。默认保留
旧 release 作为回滚点；没有明确要求时不得自动清空旧版本。用户要求清理时，先确认
新 release 正常，再使用 `key release remove` 删除精确版本。

## UI 与资源规范

- 主题颜色、动画、间距和尺寸优先使用 `Common/Appearance.qml`、`Common/Sizes.qml`
  等共享 token，避免组件内重复声明或硬编码。
- 常见控件优先使用 `QtQuick.Controls.Material`。仅在原生控件无法实现特殊动画、
  形状、LayerShell、Niri 或 ShaderEffect 需求时自定义，并遵循 Material Design 3。
- 尽量复用现有 SVG、矢量 path 和资源，不重复手绘已有图形。
- 中文和普通文本优先 `LXGW WenKai GB Screen`，数字优先
  `JetBrainsMono Nerd Font`；也可使用 `Maple Mono NF CN`。
- 图标优先使用 `ttf-material-symbols-variable` 的 Material Symbols，其次使用项目已有
  SVG 或 Nerd Font 图标。
- 可见 UI 改动应尽可能进行实际截图或录屏验证，并检查暗色/亮色、缩放与无障碍状态。

## Git、提交与文档

不要覆盖用户已有的未提交修改；先检查 `git status` 和相关 diff，只处理当前任务范围。

提交 subject 使用 `type: 描述`：

| type | 用途 |
| --- | --- |
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档 |
| `style` | 不改变逻辑的格式或样式整理 |
| `refactor` | 不新增功能的结构调整 |
| `perf` | 性能优化 |
| `test` | 测试 |
| `build` | 构建、依赖、打包与 release |
| `ci` | CI |
| `chore` | 其他维护 |
| `revert` | 回滚提交 |

示例：`feat: 新增 Keystone 样式切换`、`fix: 修复文件选择器导航失效`。

代码行为、CLI、IPC、路径、协议、依赖或 release 生命周期发生变化时，同步更新
`README.md` 和对应 `docs/`。Pull request 应说明影响模块、运行过的验证命令、任何新增
runtime dependency，并为可见 UI 改动附截图或录屏。

## 安全与清理

- 不提交 secret、token、私有路径、个人配置、词库、壁纸库、日志、数据库或缓存。
- 持久输出写入 Clavis XDG namespace；临时输出写入 Clavis runtime/cache 或安全的
  临时目录。
- 不使用 sudo 修改系统目录，除非用户明确请求某个已说明边界的系统集成。
- 不删除真实用户配置来解决 Clavis 问题。
- 清理前先精确解析目标；不得把 HOME、仓库根、安装前缀或未解析变量作为递归删除目标。
- `.build/<release>/` 是可再生成的构建产物，不提交；release 目录由安装器和
  `key release` 管理，不手工修改。
- 修改 `Modules/Lock/pam/`、权限、认证、录屏、剪贴板或 CPU helper 等敏感功能时，
  增加与风险相称的测试，并明确说明安全影响。
