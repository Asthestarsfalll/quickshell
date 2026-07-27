import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common

FocusScope {
    id: root

    property var model: []
    property string currentValue: ""
    property string accessibleName: ""
    property string valueRole: "value"
    property string labelRole: "label"
    property string supportingTextRole: "supportingText"
    property string enabledRole: "enabled"
    property string tooltipRole: "tooltip"

    signal valueSelected(string value)

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight
    Accessible.role: Accessible.Grouping
    Accessible.name: accessibleName

    function role(item, roleName, fallback) {
        if (!item || item[roleName] === undefined
                || item[roleName] === null)
            return fallback;
        return item[roleName];
    }

    function optionEnabled(item) {
        return !!role(item, enabledRole, true);
    }

    function selectRelative(fromIndex, delta) {
        if (model.length === 0)
            return;
        for (let offset = 1; offset <= model.length; offset += 1) {
            const nextIndex = (fromIndex + delta * offset
                + model.length) % model.length;
            if (!optionEnabled(model[nextIndex]))
                continue;
            const value = String(role(
                model[nextIndex], valueRole, nextIndex));
            valueSelected(value);
            const target = repeater.itemAt(nextIndex);
            if (target)
                target.forceRadioFocus();
            return;
        }
    }

    ButtonGroup {
        id: exclusiveGroup
        exclusive: true
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.spacing.xSmall

        Repeater {
            id: repeater
            model: root.model

            delegate: Item {
                id: option

                required property int index
                required property var modelData

                readonly property string optionValue: String(
                    root.role(modelData, root.valueRole, index))
                readonly property string optionLabel: String(
                    root.role(modelData, root.labelRole, ""))
                readonly property string optionSupportingText: String(
                    root.role(modelData,
                        root.supportingTextRole, ""))
                readonly property string optionTooltip: String(
                    root.role(modelData, root.tooltipRole, ""))
                readonly property bool optionEnabled:
                    root.enabled && root.optionEnabled(modelData)

                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(
                    48, content.implicitHeight
                        + Appearance.spacing.small * 2)
                opacity: option.optionEnabled ? 1 : 0.45

                function forceRadioFocus() {
                    radio.forceActiveFocus();
                }

                HoverHandler {
                    id: hover
                    acceptedDevices:
                        PointerDevice.Mouse | PointerDevice.TouchPad
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: radio.down || optionMouse.pressed
                        ? Appearance.colors.colLayer2Active
                        : hover.hovered
                            ? Appearance.colors.colLayer2Hover
                            : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation
                                .expressiveFastEffects.duration
                            easing.type: Appearance.animation
                                .expressiveFastEffects.type
                            easing.bezierCurve: Appearance.animation
                                .expressiveFastEffects.bezierCurve
                        }
                    }
                }

                RowLayout {
                    id: content

                    anchors {
                        fill: parent
                        leftMargin: Appearance.spacing.small
                        rightMargin: Appearance.spacing.small
                        topMargin: Appearance.spacing.small
                        bottomMargin: Appearance.spacing.small
                    }
                    spacing: Appearance.spacing.small

                    RadioButton {
                        id: radio

                        ButtonGroup.group: exclusiveGroup
                        checked:
                            root.currentValue === option.optionValue
                        enabled: option.optionEnabled
                        focusPolicy: Qt.StrongFocus
                        hoverEnabled: true
                        Accessible.name: option.optionLabel
                        Material.theme: Material.System
                        Material.accent:
                            Appearance.colors.colPrimary
                        Material.foreground:
                            Appearance.colors.colOnSurface
                        onClicked:
                            root.valueSelected(option.optionValue)

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Up
                                    || event.key === Qt.Key_Left) {
                                root.selectRelative(option.index, -1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down
                                    || event.key === Qt.Key_Right) {
                                root.selectRelative(option.index, 1);
                                event.accepted = true;
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: option.optionLabel
                            color: Appearance.colors.colOnSurface
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.typeBodyMedium
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            visible:
                                option.optionSupportingText !== ""
                            text: option.optionSupportingText
                            color:
                                Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.typeBodySmall
                            wrapMode: Text.Wrap
                        }
                    }
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    enabled: option.optionEnabled
                    acceptedButtons: Qt.LeftButton
                    cursorShape: option.optionEnabled
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.valueSelected(option.optionValue);
                        radio.forceActiveFocus();
                    }
                }

                StyledToolTip {
                    extraVisibleCondition:
                        hover.hovered && option.optionTooltip !== ""
                    text: option.optionTooltip
                }
            }
        }
    }
}
