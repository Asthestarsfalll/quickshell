# Clavis 外部 Matugen provider

壁纸或主题颜色改变时，`scripts/theme/generate_matugen_colors.sh` 先生成 Shell 自己
拥有的颜色，再按高级设置逐个处理独立组件：

```text
目标 matugen.conf
        │ Matugen 临时配置
        ▼
目标 colors.conf（同目录原子替换）
        │
        ├─ Zsh Prompt：下一次 prompt 绘制自动读取
        ├─ Keytop：执行一次 `keytop reload`，不重启采样器
        └─ Fcitx5：先原子更新 colors.conf，再执行一次 `fcitx5-theme apply`，
                    事务发布完整主题后 reload
```

固定目标路径为：

```text
~/.config/clavis-zsh-theme/{config.conf,matugen.conf,colors.conf}
~/.config/keytop/{config.conf,matugen.conf,colors.conf}
~/.config/fcitx5-matugen-theme/{config.conf,matugen.conf,colors.conf}
```

`config.conf` 是用户静态设置，`matugen.conf` 是组件自己的模板，`colors.conf` 是
动态结果。Quickshell 只发现模板、运行 Matugen 和调用成功后的 post action，不解析
或维护这些文件，也不会因某个目标失败而阻塞其他目标。
