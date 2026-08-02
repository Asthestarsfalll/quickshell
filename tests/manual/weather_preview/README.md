# 开发天气侧边栏预览

该测试直接使用源码 Shell 中的正式 `SidebarHostWindow`、`LeftSidebarWindow`、
`WeatherView` 和 `WeatherBackground`，不再创建独立 Window 或 Layer。天气数据来自
同目录的 `MockWeatherSource.qml`，不会访问天气网络，也不会修改用户配置。

## 启动

从仓库根目录启动 development Shell：

```bash
key shell --dev --replace
key ipc call sidebar previewWeather
```

development-native 同样可用：

```bash
key shell --dev --native --replace
key ipc call sidebar previewWeather
```

如果当前运行的是 release Shell，该 IPC 命令会返回非零并提示必须先启动 development
Shell。不要使用裸 `qs ipc`，稳定的 `key ipc` 会验证当前活动实例的运行模式。

使用正式侧边栏顶部标签切换 info/sys/weather。点击侧边栏之外的空白区域、按 Escape，
或运行以下命令关闭：

```bash
key ipc call sidebar close left
```

Mock 会一直保持到关闭动画完成，随后自动解除；下次通过普通按钮或 `sidebar open left`
打开天气页时会恢复正式 WeatherPlugin。

## 修改天气字段

直接编辑 `tests/manual/weather_preview/MockWeatherSource.qml` 顶部属性并保存，然后重新调用
`key ipc call sidebar previewWeather`。常用字段包括：

- `currentWeatherCode`、`currentIconName`、`currentWeatherText`；
- `night`；
- `currentWindSpeedMs`、`currentWindGustsMs`；
- 当前、体感、最高和最低温度；
- 湿度、能见度、气压、UV 和空气质量。

常用场景：

| 场景 | weatherCode | iconName | night | 风速/阵风 |
| --- | ---: | --- | --- | --- |
| 晴天 | 0 | `clear_day` | false | 2 / 4 |
| 晴夜 | 0 | `clear_night` | true | 2 / 4 |
| 局部多云 | 2 | `partly_cloudy_day` | false | 3 / 5 |
| 阴天/雾 | 45 | `fog_day` | false | 2 / 3 |
| 雨 | 63 | `rain` | false | 5 / 8 |
| 雷暴/闪电 | 95 | `thunderstorms_day` | false | 7 / 12 |
| 雪 | 73 | `snow` | false | 4 / 7 |
| 大风落叶 | 1 | `mostly_clear_day` | false | 10 / 15 |

慢速云层场景目标为 15 FPS / 66 ms；雨、雷暴、雪和大风落叶目标为 30 FPS /
33 ms。关闭期间动画继续运行，退场完成后视觉 Timer 停止。
