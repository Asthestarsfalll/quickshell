import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common
import qs.Modules.Keystone.ClockContent

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

    readonly property real pageContentWidth: 600
    property string selectedDigit: "h0"
    property string customColorDraft: ""

    component Section: ColumnLayout {
        id: section

        property string title: ""
        property string iconName: "toggle_off"
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
                font.family: Fonts.ui
                font.pixelSize: 18
                font.weight: Font.Medium
            }
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: 10
        }
    }

    component SearchSelectSettingRow: Item {
        id: selectRow

        property string title: ""
        property string description: ""
        property var options: []
        property string value: ""
        property string placeholder: ""
        property int fieldWidth: 240

        signal accepted(string value)

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(58, selectLabelColumn.implicitHeight + 16)

        RowLayout {
            anchors.fill: parent
            spacing: 16

            Column {
                id: selectLabelColumn

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: selectRow.title
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: selectRow.description
                    color: Appearance.colors.colSubtext
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }

            SearchSelectMenuField {
                Layout.preferredWidth: selectRow.fieldWidth
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                options: selectRow.options
                value: selectRow.value
                placeholder: selectRow.placeholder
                textRole: "label"
                valueRole: "value"
                maxVisibleItems: 6
                noResultText: qsTr("无匹配结果")
                onAccepted: value => selectRow.accepted(value)
            }
        }
    }

    component ClockSliderSetting: ColumnLayout {
        id: clockSliderSetting

        property string title: ""
        property string axisTag: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property real stepSize: 1
        property int valueDecimals: 0
        property string suffix: ""

        signal moved(real value)
        signal committed(real value)

        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: clockSliderSetting.title
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Text {
                text: clockSliderSetting.axisTag
                    + "  "
                    + Number(clockSliderSetting.value).toFixed(
                        clockSliderSetting.valueDecimals)
                    + clockSliderSetting.suffix
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Fonts.numeric
                font.pixelSize: 12
            }
        }

        MaterialSlider {
            Layout.fillWidth: true
            from: clockSliderSetting.from
            to: clockSliderSetting.to
            stepSize: clockSliderSetting.stepSize
            value: clockSliderSetting.value
            valueDecimals: clockSliderSetting.valueDecimals
            valueSuffix: clockSliderSetting.suffix
            onMoved: clockSliderSetting.moved(value)
            onCommitted: clockSliderSetting.committed(value)
        }
    }

    function selectedDigitData() {
        const defaults = PersonalizationConfig.horizontalClockDigitDefaults;
        const configured = PersonalizationConfig.horizontalClockDigits;
        return configured && configured[selectedDigit]
            ? configured[selectedDigit] : defaults[selectedDigit];
    }

    function selectedDigitCustomColor() {
        const data = root.selectedDigitData();
        return String(data && data.customColor || "");
    }

    function updateCustomColorDraft() {
        root.customColorDraft = root.selectedDigitCustomColor();
        if (customColorField && !customColorField.activeFocus)
            customColorField.text = root.customColorDraft;
    }

    function selectedDigitThemeColor() {
        const data = root.selectedDigitData();
        return data && data.colorRole === "inversePrimary"
            ? Appearance.colors.colInversePrimary.toString()
            : Appearance.colors.colPrimary.toString();
    }

    ColumnLayout {
        id: contentColumn

        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: 30

        Section {
            title: qsTr("钥石样式")
            iconName: "toggle_off"

            SearchSelectSettingRow {
                title: qsTr("样式")
                options: PersonalizationConfig.keystoneStyles
                value: PersonalizationConfig.keystoneStyle
                placeholder: qsTr("选择钥石样式")
                onAccepted: value => PersonalizationConfig.setKeystoneStyle(value)
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("屏幕边缘")
                supportingText: qsTr("钥石始终贴合物理屏幕边缘，不占用工作区")

                trailing: EdgePositionSelector {
                    position: PersonalizationConfig.keystonePosition
                    onPositionSelected: position =>
                        PersonalizationConfig.setKeystonePosition(position)
                }
            }
        }

        Section {
            title: qsTr("横向时钟")
            iconName: "schedule"

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 76

                Rectangle {
                    id: clockPreviewSurface

                    anchors.centerIn: parent
                    width: 220
                    height: 42
                    radius: Appearance.rounding.large
                    color: Appearance.colors.colSurfaceContainerHighest
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                    clip: true

                    ClockContent {
                        id: clockPreview

                        anchors.fill: parent
                        edge: "top"
                    }
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("隐藏日期")
                supportingText: qsTr("同时隐藏横向和竖向钥石中的日期")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.keystoneHideDate
                    Accessible.name: qsTr("隐藏日期")
                    onToggled: PersonalizationConfig.setKeystoneHideDate(checked)
                }
            }

            ClockSliderSetting {
                title: qsTr("字号")
                axisTag: "px"
                from: 16
                to: 28
                stepSize: 1
                value: PersonalizationConfig.horizontalClockFontSize
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockFontSize(value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockFontSize(value, true)
            }

            ClockSliderSetting {
                title: qsTr("字重")
                axisTag: "wght"
                from: 1
                to: 1000
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.wght
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockAxis("wght", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockAxis("wght", value, true)
            }

            ClockSliderSetting {
                title: qsTr("字宽")
                axisTag: "wdth"
                from: 25
                to: 151
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.wdth
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockAxis("wdth", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockAxis("wdth", value, true)
            }

            ClockSliderSetting {
                title: qsTr("光学尺寸")
                axisTag: "opsz"
                from: 6
                to: 144
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.opsz
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockAxis("opsz", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockAxis("opsz", value, true)
            }

            ClockSliderSetting {
                title: qsTr("Grade")
                axisTag: "GRAD"
                from: 0
                to: 100
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.GRAD
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockAxis("GRAD", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockAxis("GRAD", value, true)
            }

            ClockSliderSetting {
                title: qsTr("圆润度")
                axisTag: "ROND"
                from: 0
                to: 100
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.ROND
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockAxis("ROND", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockAxis("ROND", value, true)
            }

            ClockSliderSetting {
                title: qsTr("倾斜")
                axisTag: "slnt"
                from: -10
                to: 0
                stepSize: 1
                value: PersonalizationConfig.horizontalClockAxes.slnt
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockAxis("slnt", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockAxis("slnt", value, true)
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("当前数字")
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            StyledButtonGroup {
                Layout.fillWidth: true
                model: [
                    ({ "value": "h0", "label": String(clockPreview.h0) }),
                    ({ "value": "h1", "label": String(clockPreview.h1) }),
                    ({ "value": "separator", "label": ":",
                        "enabled": false, "width": 24 }),
                    ({ "value": "m0", "label": String(clockPreview.m0) }),
                    ({ "value": "m1", "label": String(clockPreview.m1) })
                ]
                currentValue: root.selectedDigit
                style: StyledButtonGroup.Style.Tonal
                buttonMinWidth: 52
                onValueSelected: value => {
                    root.selectedDigit = String(value);
                    root.updateCustomColorDraft();
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("颜色")
                supportingText: qsTr("默认主题色会随 Matugen 主题变化")

                trailing: StyledButtonGroup {
                    model: [
                        ({ "value": "primary", "label": qsTr("主色") }),
                        ({ "value": "inversePrimary", "label": qsTr("反色") }),
                        ({ "value": "custom", "label": qsTr("自定义") })
                    ]
                    currentValue: root.selectedDigitData().colorRole
                    style: StyledButtonGroup.Style.Tonal
                    buttonMinWidth: 64
                    onValueSelected: value => {
                        const role = String(value);
                        const color = role === "custom"
                            ? root.selectedDigitCustomColor()
                                || root.selectedDigitThemeColor()
                            : root.selectedDigitCustomColor();
                        PersonalizationConfig.setHorizontalClockDigitColor(
                            root.selectedDigit, role, color, true);
                    }
                }
            }

            MaterialTextField {
                id: customColorField

                Layout.fillWidth: true
                visible: root.selectedDigitData().colorRole === "custom"
                text: root.customColorDraft
                placeholderText: "#RRGGBB 或 #RRGGBBAA"
                Accessible.name: qsTr("自定义颜色")
                onTextChanged: {
                    if (activeFocus)
                        root.customColorDraft = text;
                }
                onEditingFinished: PersonalizationConfig
                    .setHorizontalClockDigitColor(
                        root.selectedDigit, "custom", text, true)
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("位置：%1").arg(root.selectedDigit.toUpperCase())
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Fonts.ui
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            ClockSliderSetting {
                title: qsTr("X 偏移")
                axisTag: "x"
                from: -8
                to: 8
                stepSize: 1
                value: root.selectedDigitData().x
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockDigitValue(
                        root.selectedDigit, "x", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockDigitValue(
                        root.selectedDigit, "x", value, true)
            }

            ClockSliderSetting {
                title: qsTr("Y 偏移")
                axisTag: "y"
                from: -6
                to: 6
                stepSize: 1
                value: root.selectedDigitData().y
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockDigitValue(
                        root.selectedDigit, "y", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockDigitValue(
                        root.selectedDigit, "y", value, true)
            }

            ClockSliderSetting {
                title: qsTr("旋转")
                axisTag: "°"
                from: -12
                to: 12
                stepSize: 1
                value: root.selectedDigitData().rotation
                suffix: "°"
                onMoved: value => PersonalizationConfig
                    .setHorizontalClockDigitValue(
                        root.selectedDigit, "rotation", value, false)
                onCommitted: value => PersonalizationConfig
                    .setHorizontalClockDigitValue(
                        root.selectedDigit, "rotation", value, true)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }

    Component.onCompleted: root.updateCustomColorDraft()

    onSelectedDigitChanged: root.updateCustomColorDraft()

    Connections {
        target: PersonalizationConfig

        function onHorizontalClockDigitsChanged() {
            if (!customColorField.activeFocus)
                root.updateCustomColorDraft();
        }
    }
}
