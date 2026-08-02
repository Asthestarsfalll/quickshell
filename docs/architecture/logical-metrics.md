# 统一逻辑尺寸

`Common/Metrics.qml` 保存跨组件复用的逻辑像素 token，包括 spacing、icon、control
height、touch target、corner、card/page padding、sidebar、bar 和头像尺寸。
`Metrics.uiScale` 是仅 Clavis UI 的密度设置，与 Niri output scale 和 Qt/Wayland
surface scale 相互独立。

组件使用 `Metrics.controlHeightM` 等逻辑尺寸。禁止把 token 乘以 Niri scale 或
`devicePixelRatio`；Qt/Wayland 已负责逻辑像素到 buffer 像素的转换。DPR 只可用于必要
的一像素边缘对齐。

迁移按通用 Widgets、设置中心控件、bar/sidebar/弹窗与高频模块渐进进行。shader 常量、
单一特殊视觉值、动画曲线和内容计算尺寸保持局部，不为消灭数字制造无语义 token。
