# 开发流程

源码开发使用 Quickshell 的 XDG 配置优先级和 CMake 生成的 import tree：

```bash
mkdir -p ~/.config/quickshell
ln -sfn ~/Projects/clavis ~/.config/quickshell/clavis

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build

QML_IMPORT_PATH="$PWD/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" key shell
```

源码目录优先于 `/etc/xdg/quickshell/clavis`。QML 保存后可热重载；C++ plugin 需要
重新构建并重新加载 Shell。Shell/CLI 日志由各自工具负责，不在文档或脚本中使用
`nohup`、`disown` 或丢弃到 `/dev/null`。

正式安装由发行版打包流程负责；本仓库默认只构建和测试源码，不创建运行时版本快照。
