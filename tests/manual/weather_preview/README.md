# 天气侧边栏手动预览

## 测试文件

主要入口是 `tests/manual/weather_preview/WeatherPreview.qml`。它创建全屏
LayerShell overlay，并在其中装配与正式版相同尺寸、相同组件链的
`LeftSidebarWindow`、`WeatherView` 和 `WeatherBackground`。根目录的
`weather-preview.qml` 只是 Quickshell 必须直接加载的极薄入口。

天气数据来自同目录的 `MockWeatherSource.qml`，不访问网络。启动脚本把 Clavis 的
配置、数据、状态和缓存全部指向临时目录，退出后删除，因此不会修改用户配置或 release。

## 使用方法

从仓库根目录运行：

```bash
just weather-preview
```

点击侧边栏之外的暗色空白区域，或点击右上角醒目的红色“关闭天气测试”按钮，即可关闭
overlay 和测试进程。

## 修改测试字段

直接编辑 `tests/manual/weather_preview/WeatherPreview.qml` 顶部
“Manual test values”区域并保存。该区域的每个字段旁都有注释：

- `previewWeatherCode`、`previewIconName`、`previewWeatherText`：天气场景；
- `previewNight`：昼夜；
- `previewWindSpeedMs`、`previewWindGustsMs`：持续风和阵风；
- `previewTemperatureC`、`previewFeelsLikeC`、`previewHighC`、`previewLowC`：温度；
- `previewKeepSidebarsLoaded`：页面是否保留；
- `previewInitialView`：初始 `info`、`sys` 或 `weather` 标签；
- `previewScreenName`：留空使用第一个输出，或填写精确输出名称。

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

慢速云层场景目标为 15 FPS / 66 ms；雨、雷暴、雪和大风落叶目标为
30 FPS / 33 ms。用正式侧边栏顶部标签切换页面；关闭时点击侧边栏外的空白区域或红色
按钮。退出前可在 QML 调试器中观察 `weatherAnimationActive`：关闭请求发出后，它会在
侧边栏退场阶段继续为 true，并在退场完成时变为 false；
`previewKeepSidebarsLoaded=false` 时页面实例随后卸载，为 true 时对象保留但视觉动画停止。
