import QtQuick
import QtQuick.Layouts
import Clavis.Niri 1.0
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

    property var previewScales: ({})
    property var independentScales: ({})
    property var pendingScales: ({})
    property int previewRevision: 0
    property bool linkedOutputs: false
    property bool waitingForConfirmation: false
    property string statusMessage: ""
    property string errorMessage: ""
    readonly property real pageContentWidth: 680

    function roundedScale(value) {
        return Math.round(Number(value) * 4) / 4
    }

    function previewFor(name, actual) {
        root.previewRevision
        return root.previewScales[name] === undefined
            ? Number(actual) : Number(root.previewScales[name])
    }

    function setPreview(name, value) {
        const next = Object.assign({}, root.previewScales)
        next[name] = root.roundedScale(value)
        root.previewScales = next
        root.previewRevision++
    }

    function outputDelegates() {
        const delegates = []
        for (let index = 0; index < outputRepeater.count; ++index) {
            const item = outputRepeater.itemAt(index)
            if (item)
                delegates.push(item)
        }
        return delegates
    }

    function currentOutputNames() {
        return root.outputDelegates().map(item => item.outputName)
    }

    function actualScales() {
        const result = ({})
        for (const item of root.outputDelegates())
            result[item.outputName] = Number(item.actualScale)
        return result
    }

    function restoreActualScales() {
        root.previewScales = root.actualScales()
        root.previewRevision++
    }

    function apply(scales) {
        root.errorMessage = ""
        root.statusMessage = qsTr("正在验证并写入缩放配置…")
        root.pendingScales = Object.assign({}, scales)
        if (!NiriScaleService.applyScales(
                root.pendingScales, root.currentOutputNames())) {
            root.errorMessage = NiriScaleService.available
                ? qsTr("另一个缩放修改仍在进行")
                : qsTr("当前会话未使用 Clavis 托管的 Niri 配置")
            root.statusMessage = ""
            root.restoreActualScales()
        }
    }

    function commitScale(name, value) {
        root.setPreview(name, value)
        const requested = ({})
        if (root.linkedOutputs) {
            for (const item of root.outputDelegates()) {
                root.setPreview(item.outputName, value)
                requested[item.outputName] = root.roundedScale(value)
            }
        } else {
            // The generated fragment is replaced atomically, so every write
            // carries the complete connected-output snapshot. This preserves
            // the independent scales that were not touched by this drag.
            for (const item of root.outputDelegates())
                requested[item.outputName] = root.previewFor(
                    item.outputName, item.actualScale)
        }
        root.apply(requested)
    }

    function setLinked(enabled) {
        if (enabled === root.linkedOutputs)
            return
        if (enabled) {
            root.independentScales = Object.assign({}, root.previewScales,
                root.actualScales())
            root.linkedOutputs = true
            const delegates = root.outputDelegates()
            if (delegates.length > 0)
                root.commitScale(delegates[0].outputName,
                    root.previewFor(delegates[0].outputName,
                        delegates[0].actualScale))
        } else {
            root.linkedOutputs = false
            const restored = ({})
            for (const item of root.outputDelegates()) {
                restored[item.outputName] =
                    root.independentScales[item.outputName] === undefined
                    ? item.actualScale
                    : root.independentScales[item.outputName]
            }
            root.previewScales = restored
            root.previewRevision++
            root.apply(restored)
        }
    }

    function confirmationMatches() {
        const pendingNames = Object.keys(root.pendingScales)
        const delegates = root.outputDelegates()
        if (pendingNames.length === 0)
            return false
        for (const name of pendingNames) {
            const item = delegates.find(candidate => candidate.outputName === name)
            if (!item || Math.abs(item.actualScale
                    - root.pendingScales[name]) > 0.01)
                return false
        }
        return true
    }

    function verifyConfirmation() {
        if (!root.waitingForConfirmation || !root.confirmationMatches())
            return
        confirmationTimer.stop()
        root.waitingForConfirmation = false
        root.pendingScales = ({})
        root.statusMessage = qsTr("Niri 已确认新的输出缩放")
        root.restoreActualScales()
    }

    Connections {
        target: NiriScaleService

        function onWriteSucceeded() {
            root.statusMessage = qsTr("配置已通过验证，正在等待 Niri 确认…")
            root.waitingForConfirmation = true
            confirmationTimer.restart()
            Qt.callLater(root.verifyConfirmation)
        }

        function onWriteFailed(message) {
            root.waitingForConfirmation = false
            root.statusMessage = ""
            root.errorMessage = message
            root.pendingScales = ({})
            root.restoreActualScales()
        }
    }

    Connections {
        target: Niri
        function onOutputsChanged() {
            if (root.waitingForConfirmation)
                Qt.callLater(root.verifyConfirmation)
            else
                Qt.callLater(root.restoreActualScales)
        }
    }

    Timer {
        id: confirmationTimer
        interval: 3000
        onTriggered: {
            root.waitingForConfirmation = false
            root.statusMessage = ""
            root.errorMessage = qsTr("Niri 未确认新的缩放；输出可能已断开或配置未重新加载")
            root.pendingScales = ({})
            root.restoreActualScales()
        }
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth,
            Math.max(0, root.width - 48))
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: Appearance.spacing.medium

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: !NiriScaleService.available
            tone: "warning"
            message: qsTr("此功能仅在由 Clavis 启动、且包含 generated outputs 配置的 Niri 会话中可用。")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.errorMessage !== ""
            tone: "error"
            message: root.errorMessage
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.statusMessage !== ""
            message: root.statusMessage
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("输出缩放")
            supportingText: qsTr("每个输出独立使用 Niri scale；只改变缩放，不修改模式、刷新率、位置或旋转。缩放会改变逻辑尺寸，多显示器布局可能随之变化。")

            SettingsRow {
                Layout.fillWidth: true
                iconName: "link"
                title: qsTr("联动所有显示器")
                supportingText: qsTr("启用时将同一个缩放安全写入当前所有输出；关闭后恢复之前的独立值。")

                trailing: StyledSwitch {
                    enabled: NiriScaleService.available
                        && !NiriScaleService.busy
                    checked: root.linkedOutputs
                    onToggled: root.setLinked(checked)
                }
            }

            Repeater {
                id: outputRepeater
                model: Niri.outputs

                delegate: Rectangle {
                    id: outputCard

                    required property string name
                    required property string currentMode
                    required property int logicalWidth
                    required property int logicalHeight
                    required property real scale
                    readonly property string outputName: name
                    readonly property real actualScale: scale
                    readonly property real previewScale:
                        root.previewFor(outputName, actualScale)

                    Layout.fillWidth: true
                    implicitHeight: outputLayout.implicitHeight
                        + Appearance.spacing.medium * 2
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    ColumnLayout {
                        id: outputLayout
                        anchors.fill: parent
                        anchors.margins: Appearance.spacing.medium
                        spacing: Appearance.spacing.xSmall

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: outputCard.outputName
                                color: Appearance.colors.colOnLayer2
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.typeTitleMedium
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                text: outputCard.previewScale.toFixed(2) + "×"
                                color: Appearance.colors.colPrimary
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.typeTitleMedium
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("模式 %1 · 当前逻辑尺寸 %2 × %3 · 当前 scale %4×")
                                .arg(outputCard.currentMode || qsTr("未知"))
                                .arg(outputCard.logicalWidth)
                                .arg(outputCard.logicalHeight)
                                .arg(outputCard.actualScale.toFixed(2))
                            color: Appearance.colors.colOnLayer1
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.typeBodySmall
                            wrapMode: Text.Wrap
                        }

                        MaterialSlider {
                            Layout.fillWidth: true
                            from: 0.5
                            to: 4.0
                            stepSize: 0.25
                            value: outputCard.previewScale
                            valueDecimals: 2
                            valueSuffix: "×"
                            enabled: NiriScaleService.available
                                && !NiriScaleService.busy
                            onMoved: value => {
                                if (root.linkedOutputs) {
                                    for (const item of root.outputDelegates())
                                        root.setPreview(item.outputName, value)
                                } else {
                                    root.setPreview(outputCard.outputName, value)
                                }
                            }
                            onCommitted: value =>
                                root.commitScale(outputCard.outputName, value)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("预计逻辑分辨率：%1 × %2")
                                .arg(Math.round(outputCard.logicalWidth
                                    * outputCard.actualScale
                                    / outputCard.previewScale))
                                .arg(Math.round(outputCard.logicalHeight
                                    * outputCard.actualScale
                                    / outputCard.previewScale))
                            color: Appearance.colors.colOnLayer1
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.typeBodyMedium
                        }
                    }
                }
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: Niri.outputs.count === 0
                tone: "warning"
                message: qsTr("未检测到已连接的 Niri 输出")
            }
        }
    }
}
