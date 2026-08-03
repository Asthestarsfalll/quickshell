import QtQml

QtObject {
    id: root

    property var items: []

    function count() {
        return Array.isArray(root.items) ? root.items.length : 0
    }

    function get(index) {
        const values = Array.isArray(root.items) ? root.items : []
        return index >= 0 && index < values.length ? values[index] : ({})
    }

    function replace(values) {
        root.items = Array.isArray(values) ? values.slice() : []
    }
}
