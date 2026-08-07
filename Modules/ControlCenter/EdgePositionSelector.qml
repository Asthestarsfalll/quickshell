import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Widgets.common

StyledButtonGroup {
    id: root

    property string position: "top"
    signal positionSelected(string position)

    model: PersonalizationConfig.edgePositions
    currentValue: root.position
    style: StyledButtonGroup.Style.Tonal
    buttonMinWidth: 64
    horizontalPadding: 12
    Layout.preferredWidth: implicitWidth
    onValueSelected: value => root.positionSelected(String(value))
}
