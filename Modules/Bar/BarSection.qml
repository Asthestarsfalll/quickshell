import QtQuick.Layouts

GridLayout {
    id: root

    property bool vertical: false
    property int componentCount: 0

    rows: vertical ? Math.max(1, componentCount) : 1
    columns: vertical ? 1 : Math.max(1, componentCount)
    rowSpacing: 8
    columnSpacing: 8
}
