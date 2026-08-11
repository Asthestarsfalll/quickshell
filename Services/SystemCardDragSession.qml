pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool active: false
    property bool frozen: false
    property string tileId: ""
    property Item sourceItem: null
    property real pointerX: 0
    property real pointerY: 0
    property real offsetX: 0
    property real offsetY: 0

    signal started(string cardId)
    signal moved(real x, real y)
    signal finished()
    signal canceled()
    signal cancelRequested(string requestedTileId)

    function begin(cardId, item, x, y, offsetX, offsetY) {
        root.active = true;
        root.frozen = false;
        root.tileId = String(cardId || "");
        root.sourceItem = item;
        root.pointerX = Number(x) || 0;
        root.pointerY = Number(y) || 0;
        root.offsetX = Number(offsetX) || 0;
        root.offsetY = Number(offsetY) || 0;
        root.started(root.tileId);
    }

    function update(x, y) {
        if (!root.active)
            return;
        root.pointerX = Number(x) || 0;
        root.pointerY = Number(y) || 0;
        root.moved(root.pointerX, root.pointerY);
    }

    function freezeGhost() {
        if (root.active)
            root.frozen = true;
    }

    function end() {
        if (!root.active)
            return;
        root.active = false;
        root.frozen = false;
        root.tileId = "";
        root.sourceItem = null;
        root.finished();
    }

    function cancel() {
        if (!root.active)
            return;
        root.active = false;
        root.frozen = false;
        root.tileId = "";
        root.sourceItem = null;
        root.canceled();
    }

    // SidebarHostWindow owns the exclusive keyboard focus while a sidebar is
    // open. Route Escape back to SystemView without making the host know
    // about the grid's committed layout.
    function requestCancel() {
        if (root.active)
            root.cancelRequested(root.tileId);
    }
}
