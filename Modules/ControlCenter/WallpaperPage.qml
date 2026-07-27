import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 20

    property string selectedDesktopOutput: ""
    property string selectedOverviewOutput: ""
    readonly property bool desktopUsesAwww:
        PersonalizationConfig.desktopWallpaperBackend === "awww"
    readonly property bool awwwDurationSupported:
        !desktopUsesAwww
        || AwwwWallpaperService.supportsDuration(
            PersonalizationConfig.awwwDesktopTransitionType)
    readonly property bool awwwBezierSupported:
        !desktopUsesAwww
        || AwwwWallpaperService.supportsBezier(
            PersonalizationConfig.awwwDesktopTransitionType)
    readonly property var outputOptions: {
        const result = [
            ({ "value": "", "label": qsTr("全局") })
        ];
        for (let index = 0; index < Quickshell.screens.length;
                index += 1) {
            const name = String(Quickshell.screens[index].name);
            result.push({ "value": name, "label": name });
        }
        return result;
    }
    readonly property string currentWallpaperPath:
        WallpaperService.wallpaperForScreen(selectedDesktopOutput)
    readonly property string currentOverviewPath:
        WallpaperService.overviewWallpaperForScreen(
            selectedOverviewOutput)
    readonly property bool currentWallpaperIsColor: WallpaperService.isColorSource(currentWallpaperPath)
    readonly property bool currentWallpaperIsImage: currentWallpaperPath !== "" && !currentWallpaperIsColor
    readonly property real pageContentWidth: 600
    property real fillModeGroupRestingWidth: 0

    Component.onCompleted:
        WallpaperService.refreshOverviewBackdropRule()

    function chooseWallpaperFile() {
        const base = root.currentWallpaperIsImage ? WallpaperService.parentFolder(root.currentWallpaperPath) : PersonalizationConfig.wallpaperFolder;
        wallpaperFileBrowser.openAt(base || PersonalizationConfig.wallpaperFolder);
    }

    function chooseWallpaperColor() {
        wallpaperColorPicker.showWithColor(root.currentWallpaperIsColor ? root.currentWallpaperPath : Appearance.colors.colPrimary);
    }

    function chooseOverviewFile() {
        const source = root.currentOverviewPath;
        const base = source !== ""
            && !WallpaperService.isColorSource(source)
                ? WallpaperService.parentFolder(source)
                : PersonalizationConfig.wallpaperFolder;
        overviewFileBrowser.openAt(
            base || PersonalizationConfig.wallpaperFolder);
    }

    function chooseOverviewColor() {
        const source = root.currentOverviewPath;
        overviewColorPicker.showWithColor(
            WallpaperService.isColorSource(source)
                ? source : Appearance.colors.colPrimary);
    }

    component Section: ColumnLayout {
        id: section

        property string title: ""
        property string iconName: "settings"
        default property alias content: body.data

        Layout.fillWidth: true
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                text: section.iconName
                iconSize: 26
                fill: 1
                color: Appearance.colors.colOnSecondaryContainer
            }

            Text {
                Layout.fillWidth: true
                text: section.title
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Sizes.fontFamily
                font.pixelSize: 18
                font.weight: Font.Medium
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 12
        }
    }

    component ActionPillButton: Item {
        id: pill

        property string text: ""
        property string iconName: ""

        signal clicked

        implicitWidth: Math.max(78, label.implicitWidth + (iconName !== "" ? 42 : 28))
        implicitHeight: 34
        opacity: enabled ? 1 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: pillMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: pill.iconName
                iconSize: 18
                color: Appearance.colors.colOnLayer2
                visible: pill.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: label
                text: pill.text
                color: Appearance.colors.colOnLayer2
                font.family: Sizes.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            enabled: pill.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component HoverActionButton: Item {
        id: action

        property string iconName: ""
        property string tooltipText: ""

        signal clicked

        width: 32
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: actionMouse.containsMouse
                ? Appearance.colors.colSurfaceContainerHighest
                : Appearance.colors.colSurfaceContainerHigh
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: action.iconName
            iconSize: 18
            color: Appearance.colors.colOnSurface
            fill: 1
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }

        StyledToolTip {
            extraVisibleCondition: actionMouse.containsMouse && action.tooltipText !== ""
            text: action.tooltipText
        }
    }

    component EasingActionGroup: StyledButtonGroup {
        id: group

        property bool playing: false
        property bool flipEnabled: true

        signal playClicked
        signal replayClicked
        signal flipClicked

        iconOnly: true
        buttonHeight: 38
        buttonMinWidth: 44
        horizontalPadding: 23
        currentValue: group.playing ? "play" : ""
        model: [
            ({ "value": "play", "icon": group.playing ? "pause" : "play_arrow", "tooltip": group.playing ? qsTr("暂停") : qsTr("播放") }),
            ({ "value": "replay", "icon": "keyboard_double_arrow_left", "tooltip": qsTr("倒放") }),
            ({ "value": "flip", "icon": "swap_vert", "tooltip": qsTr("翻转"), "enabled": group.flipEnabled })
        ]
        onValueSelected: value => {
            if (value === "play")
                group.playClicked();
            else if (value === "replay")
                group.replayClicked();
            else if (value === "flip")
                group.flipClicked();
        }
    }

    ColumnLayout {
        id: contentColumn
        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 24
        spacing: 30

        Section {
            title: qsTr("桌面壁纸管理器")
            iconName: "display_settings"

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("桌面壁纸管理器")
                supportingText: qsTr(
                    "仅决定普通桌面壁纸由谁渲染；niri overview 背景始终由 Quickshell 独立管理。")

                MaterialRadioGroup {
                    Layout.fillWidth: true
                    accessibleName: qsTr("桌面壁纸管理器")
                    currentValue:
                        PersonalizationConfig.desktopWallpaperBackend
                    model: [
                        ({
                            "value": "quickshell",
                            "label": "Quickshell",
                            "supportingText": qsTr(
                                "使用当前 DMS shader 转场并支持桌面视差。"),
                            "enabled": true
                        }),
                        ({
                            "value": "awww",
                            "label": "awww",
                            "supportingText": qsTr(
                                "使用 clavis-desktop namespace 渲染普通桌面壁纸。"),
                            "enabled": AwwwWallpaperService.available,
                            "tooltip": AwwwWallpaperService.probeComplete
                                ? qsTr("缺少 awww 或 awww-daemon 命令")
                                : qsTr("正在检测 awww…")
                        })
                    ]
                    onValueSelected: value => {
                        if (value !== "awww"
                                || AwwwWallpaperService.available)
                            WallpaperService
                                .setDesktopWallpaperBackend(value);
                    }
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    tone: AwwwWallpaperService.lastError !== ""
                        ? "error" : "info"
                    message: {
                        const backend =
                            AwwwWallpaperService.effectiveBackend
                                === "awww" ? "awww" : "Quickshell";
                        const availability =
                            AwwwWallpaperService.available
                                ? qsTr("awww 可用")
                                : qsTr("awww 不可用");
                        const daemon =
                            AwwwWallpaperService.daemonRunning
                                ? qsTr("daemon 运行中")
                                : qsTr("daemon 未运行");
                        const status = qsTr("当前桌面后端：")
                            + backend + " · " + availability
                            + " · " + daemon;
                        return AwwwWallpaperService.lastError !== ""
                            ? status + "\n"
                                + AwwwWallpaperService.lastError
                            : status;
                    }
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible:
                        WallpaperService.lastDesktopError !== ""
                    tone: "error"
                    message:
                        WallpaperService.lastDesktopError
                }
            }
        }

        Section {
            title: qsTr("当前壁纸")
            iconName: "wallpaper"

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("多显示器桌面壁纸")
                supportingText: qsTr(
                    "选择“全局”或为某个实际输出保存独立壁纸与填充模式。")

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "splitscreen"
                    title: qsTr("每显示器使用不同桌面壁纸")
                    supportingText: qsTr(
                        "输出移除后会保留其持久化映射。")

                    trailing: StyledSwitch {
                        checked:
                            PersonalizationConfig.perMonitorWallpaper
                        Accessible.name:
                            qsTr("每显示器使用不同桌面壁纸")
                        onToggled:
                            PersonalizationConfig
                                .setPerMonitorWallpaper(checked)
                    }
                }

                SearchSelectMenuField {
                    Layout.fillWidth: true
                    options: root.outputOptions
                    value: root.selectedDesktopOutput
                    placeholder: qsTr("选择桌面壁纸输出")
                    Accessible.name: qsTr("桌面壁纸输出")
                    onAccepted: value =>
                        root.selectedDesktopOutput = value
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                Item {
                    id: wallpaperPreview

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 340
                    Layout.preferredHeight: 200

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: root.currentWallpaperIsColor ? root.currentWallpaperPath : Appearance.colors.colLayer2
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.currentWallpaperIsImage ? Paths.fileUrl(root.currentWallpaperPath) : ""
                        sourceSize: Qt.size(
                            Math.max(1, Math.ceil(
                                width * Screen.devicePixelRatio * 2)),
                            Math.max(1, Math.ceil(
                                height * Screen.devicePixelRatio * 2)))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: false
                        mipmap: false
                        visible: source !== ""
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: wallpaperMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                    }

                    Rectangle {
                        id: wallpaperMask
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Appearance.rounding.normal - 1
                        color: Appearance.m3colors.m3scrim
                        visible: false
                        layer.enabled: true
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "image"
                        iconSize: 34
                        color: Appearance.colors.colOnSurfaceVariant
                        visible: root.currentWallpaperPath === ""
                    }

                    HoverHandler {
                        id: previewHover
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.applyAlpha(
                            Appearance.m3colors.m3scrim, 0.7)
                        opacity: previewHover.hovered ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutSine
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            HoverActionButton {
                                iconName: "folder_open"
                                tooltipText: qsTr("选择文件夹")
                                onClicked: root.chooseWallpaperFile()
                            }

                            HoverActionButton {
                                iconName: "palette"
                                tooltipText: qsTr("选择颜色")
                                onClicked: root.chooseWallpaperColor()
                            }

                            HoverActionButton {
                                iconName: "clear"
                                tooltipText: qsTr("清除壁纸")
                                onClicked:
                                    WallpaperService.clearWallpaper(
                                        root.selectedDesktopOutput)
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Math.min(450, Math.max(330, root.width - 420))
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: root.currentWallpaperPath !== "" ? WallpaperService.basename(root.currentWallpaperPath) : qsTr("未选择壁纸")
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideMiddle
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentWallpaperPath
                        color: Appearance.colors.colSubtext
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideMiddle
                        visible: root.currentWallpaperPath !== ""
                    }

                    StyledButtonGroup {
                        Layout.alignment: Qt.AlignLeft
                        model: [
                            ({ "value": "previous", "label": qsTr("上一张") }),
                            ({ "value": "random", "label": qsTr("随机") }),
                            ({ "value": "next", "label": qsTr("下一张") })
                        ]
                        currentValue: ""
                        onValueSelected: value => {
                            if (value === "previous")
                                WallpaperService.cyclePrevious();
                            else if (value === "random")
                                WallpaperService.cycleRandom();
                            else
                                WallpaperService.cycleNext();
                        }
                    }
                }
            }

            StyledButtonGroup {
                id: fillModeButtonGroup

                Layout.alignment: Qt.AlignHCenter
                model: PersonalizationConfig.fillModes
                currentValue: root.selectedDesktopOutput !== ""
                    ? PersonalizationConfig.monitorFillMode(
                        root.selectedDesktopOutput)
                    : PersonalizationConfig.wallpaperFillMode
                Component.onCompleted: root.fillModeGroupRestingWidth = implicitWidth
                onValueSelected: value =>
                    WallpaperService.setWallpaperFillModeForScreen(
                        root.selectedDesktopOutput, value)
            }
        }

        Section {
            title: qsTr("过渡效果")
            iconName: "animation"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: root.desktopUsesAwww
                        ? qsTr("awww 转场类型")
                        : qsTr("Quickshell DMS 动画效果")
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.fillModeGroupRestingWidth > 0 ? root.fillModeGroupRestingWidth : implicitWidth
                    Layout.preferredHeight: transitionButtonColumn.implicitHeight

                    ColumnLayout {
                        id: transitionButtonColumn

                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        StyledButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            model: root.desktopUsesAwww
                                ? PersonalizationConfig
                                    .awwwTransitionTypes.slice(0, 5)
                                : PersonalizationConfig
                                    .transitionTypes.slice(0, 5)
                            currentValue: root.desktopUsesAwww
                                ? PersonalizationConfig
                                    .awwwDesktopTransitionType
                                : PersonalizationConfig
                                    .wallpaperTransitionType
                            horizontalPadding: 24
                            onValueSelected: value => {
                                if (root.desktopUsesAwww)
                                    PersonalizationConfig
                                        .setAwwwDesktopTransitionType(value);
                                else
                                    WallpaperService
                                        .setWallpaperTransitionType(value);
                            }
                        }

                        StyledButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            model: root.desktopUsesAwww
                                ? PersonalizationConfig
                                    .awwwTransitionTypes.slice(5, 10)
                                : PersonalizationConfig
                                    .transitionTypes.slice(5, 9)
                            currentValue: root.desktopUsesAwww
                                ? PersonalizationConfig
                                    .awwwDesktopTransitionType
                                : PersonalizationConfig
                                    .wallpaperTransitionType
                            horizontalPadding: 24
                            onValueSelected: value => {
                                if (root.desktopUsesAwww)
                                    PersonalizationConfig
                                        .setAwwwDesktopTransitionType(value);
                                else
                                    WallpaperService
                                        .setWallpaperTransitionType(value);
                            }
                        }

                        StyledButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.desktopUsesAwww
                            model: PersonalizationConfig
                                .awwwTransitionTypes.slice(10, 14)
                            currentValue: PersonalizationConfig
                                .awwwDesktopTransitionType
                            horizontalPadding: 24
                            onValueSelected: value =>
                                PersonalizationConfig
                                    .setAwwwDesktopTransitionType(value)
                        }
                    }
                }
            }

            ColumnLayout {
                id: fpsSetting

                Layout.fillWidth: true
                spacing: 6
                opacity: root.desktopUsesAwww ? 1 : 0.45

                HoverHandler {
                    id: fpsHover
                    acceptedDevices:
                        PointerDevice.Mouse | PointerDevice.TouchPad
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("awww FPS")
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                MaterialAccessibleSlider {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(
                        520, root.pageContentWidth - 60)
                    from: 10
                    to: 240
                    stepSize: 5
                    value: PersonalizationConfig.awwwTransitionFps
                    enabled: root.desktopUsesAwww
                    accessibleName: qsTr("awww 转场 FPS")
                    valueFormatter: sliderValue =>
                        Math.round(sliderValue) + " FPS"
                    onMoved: PersonalizationConfig
                        .setAwwwTransitionFps(Math.round(value))
                }

                StyledToolTip {
                    extraVisibleCondition:
                        fpsHover.hovered && !root.desktopUsesAwww
                    text: qsTr(
                        "Quickshell 壁纸动画由 Qt Quick 渲染循环驱动，不提供独立 FPS 参数。")
                }
            }

            ColumnLayout {
                id: durationSetting

                Layout.fillWidth: true
                spacing: 6

                HoverHandler {
                    id: durationHover
                    acceptedDevices:
                        PointerDevice.Mouse | PointerDevice.TouchPad
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("过渡时间")
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    MaterialAccessibleSlider {
                        id: transitionDurationSlider

                        Layout.preferredWidth: Math.min(460, Math.max(330, root.pageContentWidth - 140))
                        Layout.preferredHeight: 72
                        from: 0
                        to: 5000
                        stepSize: 50
                        value: PersonalizationConfig.transitionDurationMs
                        accessibleName: qsTr("壁纸过渡时间")
                        valueFormatter: sliderValue => Math.round(sliderValue).toString()
                        onMoved: WallpaperService.setTransitionDurationMs(Math.round(transitionDurationSlider.value))
                    }

                    Item {
                        id: transitionDurationEditor

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 92
                        Layout.preferredHeight: 36

                        property bool editing: false
                        property bool invalid: false
                        property string draft: ""

                        function startEdit() {
                            draft = String(PersonalizationConfig.transitionDurationMs);
                            invalid = false;
                            editing = true;
                        }

                        function applyEdit() {
                            if (!editing)
                                return;

                            const cleanDraft = draft.trim();
                            const value = Number(cleanDraft);
                            if (cleanDraft === "" || !isFinite(value)) {
                                invalid = true;
                                return;
                            }

                            WallpaperService.setTransitionDurationMs(Math.max(0, Math.min(5000, Math.round(value))));
                            invalid = false;
                            editing = false;
                        }

                        function cancelEdit() {
                            invalid = false;
                            editing = false;
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.extraSmall
                            color: transitionDurationEditor.editing
                                   ? Appearance.colors.colLayer2
                                   : durationValueMouse.containsMouse
                                     ? Appearance.colors.colLayer1Hover
                                     : "transparent"
                            border.width: transitionDurationEditor.editing ? 1 : 0
                            border.color: transitionDurationEditor.invalid ? Appearance.colors.colError : Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.28)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.expressiveEffects.duration
                                    easing.type: Appearance.animation.expressiveEffects.type
                                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !transitionDurationEditor.editing
                            text: PersonalizationConfig.transitionDurationMs + " ms"
                            color: durationValueMouse.containsMouse ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        TextField {
                            id: transitionDurationInput

                            anchors.fill: parent
                            visible: transitionDurationEditor.editing
                            text: transitionDurationEditor.draft
                            color: Appearance.colors.colOnSurface
                            selectedTextColor: Appearance.colors.colOnPrimary
                            selectionColor: Appearance.colors.colPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            selectByMouse: true
                            validator: IntValidator {
                                bottom: 0
                                top: 5000
                            }
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            padding: 0
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            Material.accent: Appearance.colors.colPrimary
                            background: Item {}
                            onTextChanged: {
                                if (transitionDurationEditor.editing) {
                                    transitionDurationEditor.draft = text;
                                    transitionDurationEditor.invalid = false;
                                }
                            }
                            onVisibleChanged: {
                                if (visible) {
                                    Qt.callLater(() => {
                                        transitionDurationInput.forceActiveFocus();
                                        transitionDurationInput.selectAll();
                                    });
                                }
                            }
                            onEditingFinished: transitionDurationEditor.applyEdit()
                            Keys.onReturnPressed: transitionDurationEditor.applyEdit()
                            Keys.onEnterPressed: transitionDurationEditor.applyEdit()
                            Keys.onEscapePressed: event => {
                                transitionDurationEditor.cancelEdit();
                                event.accepted = true;
                            }
                        }

                        MouseArea {
                            id: durationValueMouse

                            anchors.fill: parent
                            enabled: !transitionDurationEditor.editing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: transitionDurationEditor.startEdit()
                        }
                    }
                }

                StyledToolTip {
                    extraVisibleCondition:
                        durationHover.hovered
                        && !root.awwwDurationSupported
                    text: qsTr(
                        "当前 awww 转场不会使用持续时间，但该共享值仍会用于 overview 转场。")
                }
            }

            ColumnLayout {
                id: bezierSetting

                Layout.fillWidth: true
                spacing: 10

                HoverHandler {
                    id: bezierHover
                    acceptedDevices:
                        PointerDevice.Mouse | PointerDevice.TouchPad
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("缓动曲线")
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    property real controlsWidth: 172
                    property real chartSide: Math.min(420, Math.max(360, root.pageContentWidth - controlsWidth - spacing))

                    BezierCurveEditor {
                        id: easingCurveEditor

                        Layout.preferredWidth: parent.chartSide
                        Layout.preferredHeight: implicitHeight
                        chartSize: parent.chartSide
                        curve: PersonalizationConfig.transitionBezierCurve
                        easingMode: PersonalizationConfig.transitionEasingMode
                        playDurationMs: Math.max(200, PersonalizationConfig.transitionDurationMs)
                        onControlsEdited: nextCurve => WallpaperService.setTransitionBezierCurve(nextCurve)
                        onEditRequested: bezierCurveLayerEditor.openWithCurve(PersonalizationConfig.transitionBezierCurve)
                    }

                    ColumnLayout {
                        Layout.preferredWidth: parent.controlsWidth
                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        spacing: 12

                        EasingActionGroup {
                            Layout.alignment: Qt.AlignLeft
                            playing: easingCurveEditor.playing
                            flipEnabled: easingCurveEditor.editable
                            onPlayClicked: easingCurveEditor.togglePlayback()
                            onReplayClicked: easingCurveEditor.reversePlayback()
                            onFlipClicked: easingCurveEditor.flipCurve()
                        }

                        Rectangle {
                            id: editBezierButton

                            Layout.alignment: Qt.AlignLeft
                            Layout.preferredWidth: 154
                            Layout.preferredHeight: 44
                            enabled: easingCurveEditor.editable
                            opacity: enabled ? 1 : 0.45
                            radius: 13
                            clip: true
                            color: editBezierMouse.pressed
                                   ? Appearance.colors.colPrimaryContainerActive
                                   : editBezierMouse.containsMouse
                                     ? Appearance.colors.colPrimaryContainerHover
                                     : Appearance.colors.colPrimaryContainer

                            function startRipple(x, y) {
                                ripple.centerX = x;
                                ripple.centerY = y;
                                rippleAnimation.diameter = Math.sqrt(width * width + height * height) * 2.2;
                                rippleAnimation.restart();
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.expressiveEffects.duration
                                    easing.type: Appearance.animation.expressiveEffects.type
                                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                }
                            }

                            Rectangle {
                                id: ripple

                                property real centerX: editBezierButton.width / 2
                                property real centerY: editBezierButton.height / 2
                                property real diameter: 0

                                x: centerX - width / 2
                                y: centerY - height / 2
                                width: diameter
                                height: diameter
                                radius: width / 2
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0
                                visible: opacity > 0
                            }

                            ParallelAnimation {
                                id: rippleAnimation

                                property real diameter: 0

                                NumberAnimation {
                                    target: ripple
                                    property: "diameter"
                                    from: 0
                                    to: rippleAnimation.diameter
                                    duration: Appearance.animation.standardLarge.duration
                                    easing.type: Appearance.animation.standardDecel.type
                                    easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
                                }

                                NumberAnimation {
                                    target: ripple
                                    property: "opacity"
                                    from: 0.18
                                    to: 0
                                    duration: Appearance.animation.standardLarge.duration
                                    easing.type: Appearance.animation.standardDecel.type
                                    easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
                                }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                MaterialSymbol {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    text: "edit"
                                    iconSize: 19
                                    fill: 1
                                    color: Appearance.colors.colOnPrimaryContainer
                                }

                                Text {
                                    text: qsTr("编辑贝塞尔")
                                    color: Appearance.colors.colOnPrimaryContainer
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: editBezierMouse

                                anchors.fill: parent
                                enabled: editBezierButton.enabled
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => {
                                    if (mouse.button === Qt.LeftButton)
                                        editBezierButton.startRipple(mouse.x, mouse.y);
                                }
                                onClicked: easingCurveEditor.openCoordinateEditor()
                            }
                        }

                        SplitMenuButton {
                            Layout.alignment: Qt.AlignLeft
                            minimumWidth: 136
                            maximumWidth: 172
                            model: PersonalizationConfig.transitionEasingModes
                            currentValue: PersonalizationConfig.transitionEasingMode
                            onValueSelected: value => WallpaperService.setTransitionEasingMode(value)
                        }
                    }
                }

                StyledToolTip {
                    extraVisibleCondition:
                        bezierHover.hovered
                        && !root.awwwBezierSupported
                    text: qsTr(
                        "当前 awww 转场不会使用贝塞尔曲线，但该共享值仍会用于 overview 转场。")
                }
            }
        }

        Section {
            title: qsTr("视差效果")
            iconName: "view_in_ar"

            SettingsSection {
                id: parallaxSection

                Layout.fillWidth: true
                title: qsTr("桌面视差")
                supportingText: qsTr(
                    "仅移动 Quickshell 桌面壁纸的 X/Y 取景，不影响 overview。")
                opacity: root.desktopUsesAwww ? 0.45 : 1

                HoverHandler {
                    id: parallaxHover
                    acceptedDevices:
                        PointerDevice.Mouse | PointerDevice.TouchPad
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "swap_vert"
                    title: qsTr("垂直视差")
                    supportingText: qsTr(
                        "允许壁纸在垂直溢出范围内移动。")

                    trailing: StyledSwitch {
                        enabled: !root.desktopUsesAwww
                        checked: PersonalizationConfig
                            .parallaxVerticalEnabled
                        Accessible.name: qsTr("垂直视差")
                        onToggled: PersonalizationConfig
                            .setParallaxVerticalEnabled(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "workspaces"
                    title: qsTr("随工作区移动")
                    supportingText: qsTr(
                        "每块显示器按自己的活动工作区位置计算。")

                    trailing: Item {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 36

                        HoverHandler {
                            id: workspaceParallaxHover
                            acceptedDevices: PointerDevice.Mouse
                                | PointerDevice.TouchPad
                        }

                        StyledSwitch {
                            anchors.centerIn: parent
                            enabled: !root.desktopUsesAwww
                                && PersonalizationConfig
                                    .parallaxVerticalEnabled
                            checked: PersonalizationConfig
                                .parallaxFollowWorkspaces
                            Accessible.name: qsTr("随工作区移动")
                            onToggled: PersonalizationConfig
                                .setParallaxFollowWorkspaces(checked)
                        }

                        StyledToolTip {
                            extraVisibleCondition:
                                workspaceParallaxHover.hovered
                                && !root.desktopUsesAwww
                                && !PersonalizationConfig
                                    .parallaxVerticalEnabled
                            text: qsTr("需要先启用垂直视差。")
                        }
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "dock_to_left"
                    title: qsTr("随侧边栏移动")
                    supportingText: qsTr(
                        "左侧栏向右偏移，右侧栏向左偏移。")

                    trailing: StyledSwitch {
                        enabled: !root.desktopUsesAwww
                        checked: PersonalizationConfig
                            .parallaxFollowSidebars
                        Accessible.name: qsTr("随侧边栏移动")
                        onToggled: PersonalizationConfig
                            .setParallaxFollowSidebars(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "view_column"
                    title: qsTr("随平铺窗口移动")
                    supportingText: qsTr(
                        "仅使用活动工作区去重后的平铺列数。")

                    trailing: StyledSwitch {
                        enabled: !root.desktopUsesAwww
                        checked: PersonalizationConfig
                            .parallaxFollowTiledColumns
                        Accessible.name: qsTr("随平铺窗口移动")
                        onToggled: PersonalizationConfig
                            .setParallaxFollowTiledColumns(checked)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("首选壁纸缩放比例")
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.typeBodyMedium
                        font.weight: Font.Medium
                    }

                    MaterialAccessibleSlider {
                        Layout.fillWidth: true
                        enabled: !root.desktopUsesAwww
                        from: 1
                        to: 1.35
                        stepSize: 0.01
                        value: PersonalizationConfig
                            .parallaxPreferredScale
                        accessibleName:
                            qsTr("首选壁纸缩放比例")
                        valueFormatter: sliderValue =>
                            Number(sliderValue).toFixed(2)
                        onMoved: PersonalizationConfig
                            .setParallaxPreferredScale(value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("横向完整行程列数")
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.typeBodyMedium
                        font.weight: Font.Medium
                    }

                    MaterialAccessibleSlider {
                        Layout.fillWidth: true
                        enabled: !root.desktopUsesAwww
                        from: 2
                        to: 12
                        stepSize: 1
                        value: PersonalizationConfig
                            .parallaxTiledColumnSpan
                        accessibleName:
                            qsTr("横向完整行程列数")
                        valueFormatter: sliderValue =>
                            Math.round(sliderValue).toString()
                        onMoved: PersonalizationConfig
                            .setParallaxTiledColumnSpan(
                                Math.round(value))
                    }
                }

                StyledToolTip {
                    extraVisibleCondition:
                        parallaxHover.hovered
                        && root.desktopUsesAwww
                    text: qsTr(
                        "awww 当前未提供持续修改壁纸取景偏移的接口，因此桌面视差仅适用于 Quickshell 后端。")
                }
            }
        }

        Section {
            title: qsTr("Overview 背景")
            iconName: "overview"

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("niri overview 背景")
                supportingText: qsTr(
                    "该表面始终由 Quickshell 管理，与桌面壁纸管理器无关。")

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible:
                        WallpaperService.overviewBackdropRuleProbeComplete
                        && !WallpaperService
                            .overviewBackdropRuleDetected
                    tone: "error"
                    message: qsTr(
                        "未检测到 clavis-overview-wallpaper 的 niri backdrop 规则。当前表面会停留在普通 Background 层，因此这里的参数看起来会改变桌面背景。请由人工将文档中的 layer-rule 加入 niri 配置。")
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible:
                        WallpaperService.overviewBackdropRuleProbeComplete
                        && !WallpaperService
                            .niriTransparentBackgroundDetected
                    tone: "error"
                    message: qsTr(
                        "niri workspace 背景仍不透明，会遮住 kitty 等窗口的透明与 xray 模糊背景。请由人工在 layout 中设置 background-color \"transparent\"。")
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "visibility"
                    title: qsTr("启用 overview 背景")

                    trailing: StyledSwitch {
                        checked:
                            PersonalizationConfig.overviewEnabled
                        Accessible.name:
                            qsTr("启用 overview 背景")
                        onToggled: PersonalizationConfig
                            .setOverviewEnabled(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "sync"
                    title: qsTr("使用桌面壁纸")
                    supportingText: qsTr(
                        "读取 Clavis 保存的原始路径，不读取 awww surface 或缓存。")

                    trailing: StyledSwitch {
                        checked: PersonalizationConfig
                            .overviewUseDesktopWallpaper
                        Accessible.name: qsTr("使用桌面壁纸")
                        onToggled: PersonalizationConfig
                            .setOverviewUseDesktopWallpaper(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "splitscreen"
                    title: qsTr("每显示器使用不同 overview 壁纸")
                    supportingText: qsTr(
                        "每个输出保持独立的路径与填充模式。")

                    trailing: StyledSwitch {
                        checked: PersonalizationConfig
                            .overviewPerMonitorWallpaper
                        Accessible.name:
                            qsTr("每显示器使用不同 overview 壁纸")
                        onToggled: PersonalizationConfig
                            .setOverviewPerMonitorWallpaper(checked)
                    }
                }

                SearchSelectMenuField {
                    Layout.fillWidth: true
                    options: root.outputOptions
                    value: root.selectedOverviewOutput
                    placeholder: qsTr("选择 overview 输出")
                    Accessible.name: qsTr("overview 壁纸输出")
                    onAccepted: value =>
                        root.selectedOverviewOutput = value
                }

                Text {
                    Layout.fillWidth: true
                    text: root.currentOverviewPath !== ""
                        ? root.currentOverviewPath
                        : qsTr("未选择 overview 壁纸")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeBodySmall
                    elide: Text.ElideMiddle
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Appearance.spacing.small
                    opacity: PersonalizationConfig
                        .overviewUseDesktopWallpaper ? 0.45 : 1

                    ActionPillButton {
                        text: qsTr("选择独立壁纸")
                        iconName: "folder_open"
                        enabled: !PersonalizationConfig
                            .overviewUseDesktopWallpaper
                        onClicked: root.chooseOverviewFile()
                    }

                    ActionPillButton {
                        text: qsTr("选择颜色")
                        iconName: "palette"
                        enabled: !PersonalizationConfig
                            .overviewUseDesktopWallpaper
                        onClicked: root.chooseOverviewColor()
                    }

                    ActionPillButton {
                        text: qsTr("清除")
                        iconName: "clear"
                        enabled: !PersonalizationConfig
                            .overviewUseDesktopWallpaper
                        onClicked:
                            WallpaperService.clearOverviewWallpaper(
                                root.selectedOverviewOutput)
                    }
                }

                StyledButtonGroup {
                    Layout.alignment: Qt.AlignHCenter
                    model: PersonalizationConfig.fillModes
                    currentValue:
                        root.selectedOverviewOutput !== ""
                            ? PersonalizationConfig
                                .overviewMonitorFillMode(
                                    root.selectedOverviewOutput)
                            : PersonalizationConfig
                                .overviewWallpaperFillMode
                    onValueSelected: value =>
                        WallpaperService
                            .setOverviewFillModeForScreen(
                                root.selectedOverviewOutput, value)
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("overview 转场")
                supportingText: qsTr(
                    "使用 DMS shader，并与桌面共享持续时间、缓动和贝塞尔曲线。")

                StyledButtonGroup {
                    Layout.alignment: Qt.AlignHCenter
                    model:
                        PersonalizationConfig.transitionTypes.slice(0, 5)
                    currentValue:
                        PersonalizationConfig.overviewTransitionType
                    onValueSelected: value =>
                        PersonalizationConfig
                            .setOverviewTransitionType(value)
                }

                StyledButtonGroup {
                    Layout.alignment: Qt.AlignHCenter
                    model:
                        PersonalizationConfig.transitionTypes.slice(5, 9)
                    currentValue:
                        PersonalizationConfig.overviewTransitionType
                    onValueSelected: value =>
                        PersonalizationConfig
                            .setOverviewTransitionType(value)
                }
            }

            SettingsSection {
                Layout.fillWidth: true
                title: qsTr("overview 图像效果")
                supportingText: qsTr(
                    "所有输出共享效果参数；源图实时处理，不生成缓存图片。")
                opacity:
                    PersonalizationConfig.overviewEnabled ? 1 : 0.45

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("模糊")
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.typeBodyMedium
                    }

                    MaterialAccessibleSlider {
                        Layout.fillWidth: true
                        enabled:
                            PersonalizationConfig.overviewEnabled
                        from: 0
                        to: 100
                        stepSize: 1
                        value:
                            PersonalizationConfig.overviewBlurRadius
                        accessibleName: qsTr("overview 模糊")
                        valueFormatter: value =>
                            Math.round(value) + "%"
                        onMoved: PersonalizationConfig
                            .setOverviewBlurRadius(value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("暗化")
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.typeBodyMedium
                    }

                    MaterialAccessibleSlider {
                        Layout.fillWidth: true
                        enabled:
                            PersonalizationConfig.overviewEnabled
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: PersonalizationConfig.overviewDim
                        accessibleName: qsTr("overview 暗化")
                        valueFormatter: value =>
                            Math.round(value * 100) + "%"
                        onMoved: PersonalizationConfig
                            .setOverviewDim(value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("饱和度")
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.typeBodyMedium
                    }

                    MaterialAccessibleSlider {
                        Layout.fillWidth: true
                        enabled:
                            PersonalizationConfig.overviewEnabled
                        from: 0
                        to: 2
                        stepSize: 0.05
                        value:
                            PersonalizationConfig.overviewSaturation
                        accessibleName: qsTr("overview 饱和度")
                        valueFormatter: value =>
                            Number(value).toFixed(2)
                        onMoved: PersonalizationConfig
                            .setOverviewSaturation(value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("对比度")
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.typeBodyMedium
                    }

                    MaterialAccessibleSlider {
                        Layout.fillWidth: true
                        enabled:
                            PersonalizationConfig.overviewEnabled
                        from: 0.5
                        to: 2
                        stepSize: 0.05
                        value:
                            PersonalizationConfig.overviewContrast
                        accessibleName: qsTr("overview 对比度")
                        valueFormatter: value =>
                            Number(value).toFixed(2)
                        onMoved: PersonalizationConfig
                            .setOverviewContrast(value)
                    }
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    tone: WallpaperService.lastOverviewError !== ""
                        ? "error" : "info"
                    message: WallpaperService.lastOverviewError !== ""
                        ? WallpaperService.lastOverviewError
                        : (PersonalizationConfig.overviewEnabled
                            ? (WallpaperService.overviewReady
                                ? qsTr("overview Quickshell 表面已就绪")
                                : qsTr("overview Quickshell 表面正在加载"))
                            : qsTr("overview Quickshell 表面已加载但当前禁用"))
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
        }
    }

    WallpaperFileBrowser {
        id: wallpaperFileBrowser
        startPath: PersonalizationConfig.wallpaperFolder
        onFolderSelected: path => {
            WallpaperService.setWallpaperFolder(path);
        }
        onFileSelected: path => {
            const folder = WallpaperService.parentFolder(path);
            if (folder !== "")
                WallpaperService.setWallpaperFolder(folder);
            WallpaperService.setWallpaper(
                path, root.selectedDesktopOutput);
        }
    }

    WallpaperColorPicker {
        id: wallpaperColorPicker
        onColorSelected: color => WallpaperService.setWallpaper(
            color, root.selectedDesktopOutput)
    }

    WallpaperFileBrowser {
        id: overviewFileBrowser
        startPath: PersonalizationConfig.wallpaperFolder
        onFileSelected: path =>
            WallpaperService.setOverviewWallpaper(
                path, root.selectedOverviewOutput)
    }

    WallpaperColorPicker {
        id: overviewColorPicker
        onColorSelected: color =>
            WallpaperService.setOverviewWallpaper(
                color, root.selectedOverviewOutput)
    }

    BezierCurveLayerEditor {
        id: bezierCurveLayerEditor
        onCurveEdited: nextCurve => WallpaperService.setTransitionBezierCurve(nextCurve)
    }
}
