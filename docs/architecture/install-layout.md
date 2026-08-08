# CMake 安装布局

Clavis Shell 使用标准 CMake 安装，不维护应用内版本管理器：

```text
/etc/xdg/quickshell/clavis/       QML 源码、assets、scripts、matugen
/lib/qt6/qml/Clavis/              Clavis 原生 QML modules
/lib/qt6/qml/M3Shapes/            Material 3 shapes module
/usr/lib/systemd/user/            Clavis 自己的 clavis-shell.service
```

路径通过 `CMAKE_INSTALL_PREFIX`、`CMAKE_INSTALL_LIBDIR`、
`CLAVIS_QML_BUILD_DIR`、`CLAVIS_QML_INSTALL_DIR`、
`CLAVIS_CONFIG_INSTALL_DIR` 和 `CLAVIS_SYSTEMD_USER_INSTALL_DIR` 覆盖；安装支持
`DESTDIR`，CMake 文件不调用 sudo。`clavis-clipboard.service` 不属于这个仓库，
由 key-cli wheel 安装到同一个标准 systemd user-unit 目录。

用户 XDG 配置目录由 Quickshell 自己选择：`~/.config/quickshell/clavis` 存在时优先，
否则回退到 `/etc/xdg/quickshell/clavis`。开发 import tree 位于 `build/qml`，不复制
到系统 Qt import 根。
