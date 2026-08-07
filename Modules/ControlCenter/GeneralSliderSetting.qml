import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

ColumnLayout {
    id: root

    property string title: ""
    property string description: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 1
    property string suffix: ""

    signal moved(real value)

    Layout.fillWidth: true
    spacing: Metrics.spacingXS
    opacity: enabled ? 1 : 0.45

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacingM

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXXS

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: Typography.bodyMedium.pixelSize
                font.weight: Font.Medium
            }

            Text {
                Layout.fillWidth: true
                visible: root.description !== ""
                text: root.description
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: Typography.bodySmall.pixelSize
                wrapMode: Text.Wrap
            }
        }

        Item {
            id: valueEditor

            Layout.preferredWidth: 108
            Layout.preferredHeight: 36

            property bool editing: false
            property bool invalid: false
            property string draft: ""

            function startEdit() {
                draft = Math.round(root.value).toString();
                invalid = false;
                editing = true;
            }

            function applyEdit() {
                if (!editing)
                    return;
                const cleanDraft = draft.trim();
                const numberValue = Number(cleanDraft);
                if (cleanDraft === "" || !isFinite(numberValue)) {
                    invalid = true;
                    return;
                }
                editing = false;
                invalid = false;
                root.moved(Math.max(root.from,
                    Math.min(root.to, Math.round(numberValue))));
            }

            function cancelEdit() {
                editing = false;
                invalid = false;
            }

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.full
                color: valueEditor.invalid
                    ? Appearance.colors.colErrorContainer
                    : Appearance.colors.colSecondaryContainer
            }

            Text {
                anchors.centerIn: parent
                visible: !valueEditor.editing
                text: Math.round(root.value) + root.suffix
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Fonts.numeric
                font.pixelSize: Typography.bodySmall.pixelSize
                font.weight: Font.Medium
            }

            TextField {
                id: valueInput

                anchors.fill: parent
                visible: valueEditor.editing
                text: valueEditor.draft
                color: Appearance.colors.colOnSecondaryContainer
                selectedTextColor: Appearance.colors.colOnPrimary
                selectionColor: Appearance.colors.colPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                selectByMouse: true
                validator: IntValidator {
                    bottom: Math.ceil(root.from)
                    top: Math.floor(root.to)
                }
                font.family: Fonts.numeric
                font.pixelSize: Typography.bodySmall.pixelSize
                padding: 0
                Material.accent: Appearance.colors.colPrimary
                background: Item {}
                onTextChanged: {
                    if (valueEditor.editing) {
                        valueEditor.draft = text;
                        valueEditor.invalid = false;
                    }
                }
                onVisibleChanged: {
                    if (visible) {
                        Qt.callLater(() => {
                            forceActiveFocus();
                            selectAll();
                        });
                    }
                }
                onEditingFinished: valueEditor.applyEdit()
                Keys.onReturnPressed: valueEditor.applyEdit()
                Keys.onEnterPressed: valueEditor.applyEdit()
                Keys.onEscapePressed: event => {
                    valueEditor.cancelEdit();
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !valueEditor.editing
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: valueEditor.startEdit()
            }
        }
    }

    MaterialAccessibleSlider {
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        enabled: root.enabled
        accessibleName: root.title
        valueFormatter: sliderValue => Math.round(sliderValue).toString()
        onMoved: root.moved(Math.round(value))
    }
}
