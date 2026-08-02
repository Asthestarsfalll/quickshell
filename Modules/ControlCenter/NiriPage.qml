import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Quickshell
import Clavis.Niri 1.0
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight
        + Metrics.pageMargin

    property string statusMessage: ""
    property string errorMessage: ""
    readonly property real pageContentWidth: Metrics.scaled(720)
    readonly property var configStatus: NiriConfigService.status || ({})
    readonly property var domains: configStatus.domains || ({})

    function domainSummary(name) {
        const domain = root.domains[name]
        if (!domain)
            return qsTr("尚未检查")
        if (!domain.exists)
            return qsTr("片段不存在")
        if (!domain.include)
            return qsTr("片段存在但未 include")
        const base = qsTr("有效 · %1:%2")
            .arg(domain.include.source).arg(domain.include.line)
        const later = domain.laterUserIncludes || []
        return later.length > 0
            ? base + qsTr(" · 其后有 %1 个用户 include，可能覆盖同名字段")
                .arg(later.length)
            : base
    }

    function payloadForDomain(name) {
        if (name === "outputs")
            return PersonalizationConfig.niriOutputSettings
        if (name === "layout")
            return PersonalizationConfig.niriLayoutSettings
        if (name === "binds") {
            const rendered = ({})
            for (const item of NiriKeybindService.actions) {
                const binding = PersonalizationConfig
                    .niriKeybindOverrides[item.id]
                if (binding)
                    rendered[binding] = item.action
            }
            return rendered
        }
        return null
    }

    Connections {
        target: NiriConfigService
        function onApplySucceeded(domain, revision) {
            root.errorMessage = ""
            root.statusMessage = qsTr("%1 配置已由 Niri 确认").arg(domain)
        }
        function onApplyFailed(domain, revision, message) {
            root.statusMessage = ""
            root.errorMessage = message
        }
    }

    Connections {
        target: NiriOutputConfigService
        function onFailed(outputName, message) {
            root.errorMessage = qsTr("输出 %1：%2").arg(outputName).arg(message)
        }
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth,
            Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin,
            (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.errorMessage !== ""
                || NiriConfigService.lastError !== ""
            tone: "error"
            message: root.errorMessage || NiriConfigService.lastError
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: !NiriConfigService.mainConfigActive
            tone: "warning"
            message: qsTr("当前会话使用旧配置入口 %1。页面可查看状态，但持久化需在重新登录 Niri 后进行。")
                .arg(NiriConfigService.activeConfigPath)
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.statusMessage !== ""
            message: root.statusMessage
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Niri 总览")
            supportingText: qsTr("用户拥有主配置；Clavis 只写入 ~/.config/niri/clavis/ 中已启用的派生片段。")

            SettingsRow {
                Layout.fillWidth: true
                iconName: Niri.connected ? "check_circle" : "error"
                title: Niri.connected ? qsTr("Niri 正在运行") : qsTr("Niri 未连接")
                supportingText: qsTr("版本 %1 · Socket %2")
                    .arg(root.configStatus.niriVersion || qsTr("未知"))
                    .arg(Niri.socketPath || qsTr("不可用"))
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: root.configStatus.validation
                    && root.configStatus.validation.ok ? "verified" : "warning"
                title: root.configStatus.validation
                    && root.configStatus.validation.ok
                    ? qsTr("完整配置验证通过") : qsTr("完整配置验证失败")
                supportingText: root.configStatus.mainConfig || ""
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "folder_managed"
                title: qsTr("Clavis 配置目录")
                supportingText: root.configStatus.clavisDirectory || ""
            }

            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacingS

                DialogActionButton {
                    text: qsTr("打开配置目录")
                    onClicked: Qt.openUrlExternally(Paths.fileUrl(
                        Paths.xdgConfigHome + "/niri"))
                }
                DialogActionButton {
                    text: qsTr("重新检查")
                    onClicked: NiriConfigService.refresh()
                }
                DialogActionButton {
                    text: qsTr("重新加载配置")
                    enabled: Niri.connected
                    onClicked: NiriRuntimeService.reloadConfig()
                }
            }

            Repeater {
                model: ["colors", "effects", "cursor", "binds", "layout", "outputs"]
                delegate: SettingsRow {
                    required property string modelData
                    Layout.fillWidth: true
                    iconName: root.domains[modelData]
                        && root.domains[modelData].include
                        ? "check" : "pending"
                    title: qsTr("片段：%1").arg(modelData)
                    supportingText: root.domainSummary(modelData)
                    trailing: DialogActionButton {
                        visible: ["binds", "layout", "outputs"]
                            .includes(modelData)
                            && !(root.domains[modelData]
                                && root.domains[modelData].include)
                        text: qsTr("修复 include")
                        enabled: NiriConfigService.canApply
                        onClicked: NiriConfigService.applyDomain(
                            modelData, root.payloadForDomain(modelData))
                    }
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("输出设置")
            supportingText: qsTr("使用 Niri 逻辑坐标。修改先通过 IPC 预览，再生成 outputs.kdl、验证并等待 ConfigLoaded；不会把 output scale 再乘到 QML 尺寸。")

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: (root.configStatus.outputDefinitions || []).length > 0
                    && !(root.domains.outputs && root.domains.outputs.include)
                tone: "warning"
                message: qsTr("用户配置中仍有 output 定义。迁移完成前为避免重复 output block，持久化控件保持禁用。")
            }

            Repeater {
                model: Niri.outputs

                delegate: Rectangle {
                    id: outputCard

                    required property string name
                    required property string make
                    required property string model
                    required property string currentMode
                    required property int logicalX
                    required property int logicalY
                    required property int logicalWidth
                    required property int logicalHeight
                    required property real scale
                    required property string transform
                    required property bool outputEnabled
                    required property bool vrrSupported
                    required property bool vrrEnabled
                    required property var modes

                    Layout.fillWidth: true
                    implicitHeight: outputLayout.implicitHeight
                        + Metrics.cardPadding * 2
                    radius: Metrics.cornerM
                    color: Appearance.colors.colLayer2
                    readonly property bool persistAvailable:
                        root.domains.outputs
                        && root.domains.outputs.include
                        && !NiriOutputConfigService.busy
                        && NiriConfigService.mainConfigActive
                    readonly property var modeChoices: {
                        const result = []
                        for (const mode of outputCard.modes || []) {
                            result.push("%1x%2@%3".arg(mode.width)
                                .arg(mode.height)
                                .arg(Number(mode.refreshRate).toFixed(3)))
                        }
                        return result
                    }

                    ColumnLayout {
                        id: outputLayout
                        anchors.fill: parent
                        anchors.margins: Metrics.cardPadding
                        spacing: Metrics.spacingS

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: outputCard.name
                                color: Appearance.colors.colOnLayer2
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.typeTitleMedium
                                font.weight: Font.DemiBold
                            }
                            StyledSwitch {
                                checked: outputCard.outputEnabled
                                enabled: outputCard.persistAvailable
                                onToggled: NiriOutputConfigService
                                    .setEnabled(outputCard.name, checked,
                                        outputCard.outputEnabled)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("%1 %2 · %3 · 逻辑 %4×%5 @ %6,%7 · %8")
                                .arg(outputCard.make).arg(outputCard.model)
                                .arg(outputCard.currentMode || qsTr("禁用"))
                                .arg(outputCard.logicalWidth)
                                .arg(outputCard.logicalHeight)
                                .arg(outputCard.logicalX).arg(outputCard.logicalY)
                                .arg(outputCard.transform || "normal")
                            color: Appearance.colors.colOnLayer1
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.typeBodySmall
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Metrics.spacingS

                            ComboBox {
                                id: modeBox
                                Layout.fillWidth: true
                                model: outputCard.modeChoices
                                currentIndex: Math.max(0,
                                    outputCard.modeChoices.indexOf(
                                        outputCard.currentMode))
                                enabled: outputCard.persistAvailable
                                    && count > 0
                                onActivated: index => {
                                    const selected = outputCard.modeChoices[index]
                                    if (selected !== outputCard.currentMode)
                                        NiriOutputConfigService.setMode(
                                            outputCard.name, selected,
                                            outputCard.currentMode)
                                }
                            }

                            ComboBox {
                                id: transformBox
                                Layout.preferredWidth: Metrics.scaled(170)
                                model: ["normal", "90", "180", "270",
                                    "flipped", "flipped-90",
                                    "flipped-180", "flipped-270"]
                                currentIndex: Math.max(0,
                                    model.indexOf(outputCard.transform))
                                enabled: outputCard.persistAvailable
                                onActivated: index => {
                                    const selected = model[index]
                                    if (selected !== outputCard.transform)
                                        NiriOutputConfigService.setTransform(
                                            outputCard.name, selected,
                                            outputCard.transform)
                                }
                            }
                        }

                        MaterialSlider {
                            Layout.fillWidth: true
                            from: 0.5
                            to: 4.0
                            stepSize: 0.25
                            value: outputCard.scale
                            valueDecimals: 2
                            valueSuffix: "×"
                            enabled: outputCard.persistAvailable
                            onCommitted: value => NiriOutputConfigService
                                .setScale(outputCard.name, value,
                                    outputCard.scale)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("当前 scale %1× · 预计逻辑分辨率 %2×%3")
                                .arg(outputCard.scale.toFixed(2))
                                .arg(Math.round(outputCard.logicalWidth))
                                .arg(Math.round(outputCard.logicalHeight))
                            color: Appearance.colors.colOnLayer1
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: Sizes.typeBodySmall
                        }

                        SettingsRow {
                            Layout.fillWidth: true
                            visible: outputCard.vrrSupported
                            title: qsTr("可变刷新率")
                            supportingText: qsTr("只修改 VRR，不改变当前模式或刷新率")
                            trailing: StyledSwitch {
                                checked: outputCard.vrrEnabled
                                enabled: outputCard.persistAvailable
                                onToggled: NiriOutputConfigService.setVrr(
                                    outputCard.name, checked,
                                    outputCard.vrrEnabled)
                            }
                        }

                        SettingsRow {
                            Layout.fillWidth: true
                            title: qsTr("逻辑位置")
                            supportingText: qsTr("修改 scale 后布局可能变化；坐标为 Niri logical coordinates")
                            trailing: RowLayout {
                                spacing: Metrics.spacingXS
                                MaterialTextField {
                                    id: logicalXField
                                    implicitWidth: Metrics.scaled(76)
                                    text: String(outputCard.logicalX)
                                    placeholderText: "X"
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                                MaterialTextField {
                                    id: logicalYField
                                    implicitWidth: Metrics.scaled(76)
                                    text: String(outputCard.logicalY)
                                    placeholderText: "Y"
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                                DialogActionButton {
                                    text: qsTr("应用")
                                    enabled: outputCard.persistAvailable
                                        && logicalXField.acceptableInput
                                        && logicalYField.acceptableInput
                                    onClicked: NiriOutputConfigService.setPosition(
                                        outputCard.name,
                                        Number(logicalXField.text),
                                        Number(logicalYField.text),
                                        outputCard.logicalX,
                                        outputCard.logicalY)
                                }
                            }
                        }

                        SettingsRow {
                            Layout.fillWidth: true
                            title: qsTr("登录后优先聚焦")
                            supportingText: qsTr("只写入 focus-at-startup，不修改输出位置")
                            trailing: StyledSwitch {
                                checked: !!(PersonalizationConfig
                                    .niriOutputSettings[outputCard.name]
                                    && PersonalizationConfig
                                        .niriOutputSettings[outputCard.name]
                                        .focusAtStartup)
                                enabled: outputCard.persistAvailable
                                onToggled: NiriOutputConfigService
                                    .setFocusAtStartup(outputCard.name, checked)
                            }
                        }
                    }
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Layout")
            supportingText: qsTr("仅保存这里明确填写的字段。留空表示继续由用户配置管理；“跟随 Shell 间距”不会从第一条 bar 配置隐式推导。")

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS

                MaterialTextField {
                    id: gapsField
                    Layout.fillWidth: true
                    placeholderText: qsTr("窗口间距，例如 16")
                    text: PersonalizationConfig.niriLayoutSettings.gaps === undefined
                        ? "" : String(PersonalizationConfig.niriLayoutSettings.gaps)
                    inputMethodHints: Qt.ImhDigitsOnly
                }
                MaterialTextField {
                    id: radiusField
                    Layout.fillWidth: true
                    placeholderText: qsTr("窗口圆角，例如 12")
                    text: PersonalizationConfig.niriLayoutSettings.cornerRadius === undefined
                        ? "" : String(PersonalizationConfig.niriLayoutSettings.cornerRadius)
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("窗口阴影")
                trailing: StyledSwitch {
                    id: shadowSwitch
                    checked: PersonalizationConfig.niriLayoutSettings.shadow
                        && PersonalizationConfig.niriLayoutSettings.shadow.enabled
                    enabled: root.domains.layout
                        && root.domains.layout.include
                    onToggled: {
                        const settings = Object.assign({},
                            PersonalizationConfig.niriLayoutSettings)
                        settings.shadow = ({ "enabled": checked })
                        NiriLayoutConfigService.apply(settings)
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Focus ring")
                supportingText: qsTr("启用后由 Clavis 管理开关和宽度")
                trailing: RowLayout {
                    spacing: Metrics.spacingS
                    MaterialTextField {
                        id: focusRingWidthField
                        implicitWidth: Metrics.scaled(90)
                        placeholderText: qsTr("宽度")
                        text: PersonalizationConfig.niriLayoutSettings.focusRing
                            && PersonalizationConfig.niriLayoutSettings.focusRing.width !== undefined
                            ? String(PersonalizationConfig.niriLayoutSettings.focusRing.width) : ""
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                    StyledSwitch {
                        id: focusRingSwitch
                        checked: PersonalizationConfig.niriLayoutSettings.focusRing
                            && PersonalizationConfig.niriLayoutSettings.focusRing.enabled !== false
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Border")
                supportingText: qsTr("Niri 的 border 启用语义独立于 focus ring")
                trailing: RowLayout {
                    spacing: Metrics.spacingS
                    MaterialTextField {
                        id: borderWidthField
                        implicitWidth: Metrics.scaled(90)
                        placeholderText: qsTr("宽度")
                        text: PersonalizationConfig.niriLayoutSettings.border
                            && PersonalizationConfig.niriLayoutSettings.border.width !== undefined
                            ? String(PersonalizationConfig.niriLayoutSettings.border.width) : ""
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                    StyledSwitch {
                        id: borderSwitch
                        checked: PersonalizationConfig.niriLayoutSettings.border
                            && PersonalizationConfig.niriLayoutSettings.border.enabled !== false
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS
                MaterialTextField {
                    id: defaultWidthField
                    Layout.fillWidth: true
                    placeholderText: qsTr("默认列宽比例，例如 0.5")
                    text: PersonalizationConfig.niriLayoutSettings.defaultColumnWidth === undefined
                        ? "" : String(PersonalizationConfig.niriLayoutSettings.defaultColumnWidth)
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
                MaterialTextField {
                    id: presetsField
                    Layout.fillWidth: true
                    placeholderText: qsTr("预设列宽比例，逗号分隔")
                    text: (PersonalizationConfig.niriLayoutSettings.presetColumnWidths || []).join(", ")
                }
                ComboBox {
                    id: centerModeBox
                    Layout.preferredWidth: Metrics.scaled(190)
                    model: ["never", "always", "on-overflow"]
                    currentIndex: Math.max(0, model.indexOf(
                        PersonalizationConfig.niriLayoutSettings.centerFocusedColumn || "never"))
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("单列时始终居中")
                trailing: StyledSwitch {
                    id: centerSingleSwitch
                    checked: !!PersonalizationConfig.niriLayoutSettings.alwaysCenterSingleColumn
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS
                Repeater {
                    id: strutRepeater
                    model: [
                        ({ "name": "left", "label": qsTr("左 strut") }),
                        ({ "name": "right", "label": qsTr("右 strut") }),
                        ({ "name": "top", "label": qsTr("上 strut") }),
                        ({ "name": "bottom", "label": qsTr("下 strut") })
                    ]
                    delegate: MaterialTextField {
                        required property var modelData
                        Layout.fillWidth: true
                        placeholderText: modelData.label
                        property string strutName: modelData.name
                        text: PersonalizationConfig.niriLayoutSettings.struts
                            && PersonalizationConfig.niriLayoutSettings.struts[strutName] !== undefined
                            ? String(PersonalizationConfig.niriLayoutSettings.struts[strutName]) : ""
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }
            }

            DialogActionButton {
                text: qsTr("验证并应用 Layout")
                enabled: root.domains.layout && root.domains.layout.include
                    && NiriConfigService.mainConfigActive
                    && !NiriLayoutConfigService.busy
                onClicked: {
                    const settings = Object.assign({},
                        PersonalizationConfig.niriLayoutSettings)
                    if (gapsField.text.trim() === "")
                        delete settings.gaps
                    else
                        settings.gaps = Math.max(0,
                            Number(gapsField.text))
                    if (radiusField.text.trim() === "")
                        delete settings.cornerRadius
                    else
                        settings.cornerRadius = Math.max(0,
                            Number(radiusField.text))
                    if (settings.focusRing !== undefined
                            || focusRingSwitch.checked
                            || focusRingWidthField.text.trim() !== "") {
                        settings.focusRing = ({ "enabled": focusRingSwitch.checked })
                        if (focusRingWidthField.text.trim() !== "")
                            settings.focusRing.width = Math.max(0,
                                Number(focusRingWidthField.text))
                    }
                    if (settings.border !== undefined
                            || borderSwitch.checked
                            || borderWidthField.text.trim() !== "") {
                        settings.border = ({ "enabled": borderSwitch.checked })
                        if (borderWidthField.text.trim() !== "")
                            settings.border.width = Math.max(0,
                                Number(borderWidthField.text))
                    }
                    if (defaultWidthField.text.trim() === "")
                        delete settings.defaultColumnWidth
                    else
                        settings.defaultColumnWidth = Math.max(0,
                            Number(defaultWidthField.text))
                    settings.presetColumnWidths = presetsField.text
                        .split(",").map(value => Number(value.trim()))
                        .filter(value => Number.isFinite(value) && value > 0)
                    if (settings.centerFocusedColumn !== undefined
                            || centerModeBox.currentIndex > 0)
                        settings.centerFocusedColumn = centerModeBox.currentText
                    settings.alwaysCenterSingleColumn = centerSingleSwitch.checked
                    const struts = ({})
                    for (let index = 0; index < strutRepeater.count; ++index) {
                        const item = strutRepeater.itemAt(index)
                        if (item && item.text.trim() !== "")
                            struts[item.strutName] = Number(item.text)
                    }
                    if (Object.keys(struts).length > 0)
                        settings.struts = struts
                    NiriLayoutConfigService.apply(settings)
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Clavis 快捷键")
            supportingText: qsTr("用户 binds 保持原样。这里只生成 Clavis override，并显示递归 include 后检测到的冲突。删除 override 会恢复用户绑定或未绑定状态。")

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: NiriKeybindService.conflicts.length > 0
                tone: "warning"
                message: qsTr("检测到 %1 个重复组合键，请检查来源后再保存覆盖。")
                    .arg(NiriKeybindService.conflicts.length)
            }

            MaterialTextField {
                id: bindSearchField
                Layout.fillWidth: true
                placeholderText: qsTr("搜索功能、分类或组合键")
            }

            Repeater {
                model: NiriKeybindService.actions
                delegate: SettingsRow {
                    id: bindRow
                    required property var modelData
                    Layout.fillWidth: true
                    visible: {
                        const query = bindSearchField.text.trim().toLowerCase()
                        return query === ""
                            || modelData.title.toLowerCase().includes(query)
                            || modelData.category.toLowerCase().includes(query)
                            || modelData.defaultKey.toLowerCase().includes(query)
                    }
                    iconName: "keyboard_command_key"
                    title: modelData.title
                    supportingText: qsTr("默认：%1 · 分类：%2")
                        .arg(modelData.defaultKey).arg(modelData.category)
                    trailing: RowLayout {
                        spacing: Metrics.spacingS
                        MaterialTextField {
                            id: bindingField
                            implicitWidth: Metrics.scaled(180)
                            text: PersonalizationConfig
                                .niriKeybindOverrides[bindRow.modelData.id] || ""
                            placeholderText: bindRow.modelData.defaultKey
                        }
                        DialogActionButton {
                            text: qsTr("保存")
                            enabled: root.domains.binds
                                && root.domains.binds.include
                                && NiriConfigService.mainConfigActive
                            onClicked: NiriKeybindService.saveOverride(
                                bindRow.modelData.id, bindingField.text)
                        }
                        DialogActionButton {
                            text: qsTr("清除")
                            enabled: root.domains.binds
                                && root.domains.binds.include
                                && NiriConfigService.mainConfigActive
                            onClicked: {
                                bindingField.text = ""
                                NiriKeybindService.saveOverride(
                                    bindRow.modelData.id, "")
                            }
                        }
                    }
                }
            }
        }
    }
}
