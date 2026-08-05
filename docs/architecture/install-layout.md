# CMake 安装布局

Clavis Shell 使用标准 CMake 安装，不维护应用内版本管理器：

```text
/etc/xdg/quickshell/clavis/       QML 源码、assets、scripts、matugen
/lib/qt6/qml/Clavis/              Clavis 原生 QML modules
/lib/qt6/qml/M3Shapes/            Material 3 shapes module
/usr/share/clavis/systemd/user/  可选用户 unit 模板
```

路径通过 `CMAKE_INSTALL_PREFIX`、`CMAKE_INSTALL_LIBDIR`、
`CLAVIS_QML_BUILD_DIR`、`CLAVIS_QML_INSTALL_DIR` 和
`CLAVIS_CONFIG_INSTALL_DIR` 覆盖；安装支持 `DESTDIR`，CMake 文件不调用 sudo。

用户 XDG 配置目录由 Quickshell 自己选择：`~/.config/quickshell/clavis` 存在时优先，
否则回退到 `/etc/xdg/quickshell/clavis`。开发 import tree 位于 `build/qml`，不复制
到系统 Qt import 根。
