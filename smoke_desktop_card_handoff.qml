//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Services

ShellRoot {
    id: root

    property Item sourceItem: null
    property string phase: "committed-source"
    property string frozenPresentedId: ""

    Component {
        id: sourceComponent

        Item {
            width: 200
            height: 160
        }
    }

    function fail(message) {
        console.error("DESKTOP_CARD_HANDOFF_SMOKE_FAIL", message);
        Qt.callLater(Qt.quit);
    }

    function beginCommittedSourceCheck() {
        root.sourceItem = sourceComponent.createObject(root);
        SystemCardDragSession.begin(
            "cpu", root.sourceItem, 100, 120, 20, 30);
        SystemCardDragSession.freezeGhost();
        if (!SystemCardDragSession.notifyFrozenGhostPresented()
                || root.frozenPresentedId !== "cpu") {
            root.fail("frozen ghost presentation barrier did not signal");
            return;
        }
        SystemCardDragSession.prepareVisualHandoff("cpu");
        SystemCardDragSession.markTransferCommitted("cpu");
        const rect = SystemCardDragSession.frozenGhostRect;
        if (!rect.valid || rect.x !== 80 || rect.y !== 90
                || rect.width !== 200 || rect.height !== 160) {
            root.fail("frozen ghost rect was not captured exactly: "
                + JSON.stringify(rect));
            return;
        }
        root.sourceItem.destroy();
        root.phase = "committed-source-destroyed";
        Qt.callLater(function() {
            if (!SystemCardDragSession.active
                    || !SystemCardDragSession.transferCommitted) {
                root.fail("source destruction cleared committed handoff");
                return;
            }
            if (!SystemCardDragSession.completeVisualHandoff("cpu")) {
                root.fail("ready delegate did not complete handoff");
                return;
            }
            Qt.callLater(root.checkCommittedSource);
        });
    }

    function checkCommittedSource() {
        if (SystemCardDragSession.phase
                !== SystemCardDragSession.idlePhase) {
            root.fail("committed source did not clean up: "
                + SystemCardDragSession.phase);
            return;
        }
        if (SystemCardDragSession.transferCommitted) {
            root.fail("committed transfer flag survived cleanup");
            return;
        }

        root.sourceItem = sourceComponent.createObject(root);
        SystemCardDragSession.begin(
            "gpu", root.sourceItem, 0, 0, 0, 0);
        root.sourceItem.destroy();
        root.phase = "uncommitted-source-destroyed";
        Qt.callLater(root.checkUncommittedSource);
    }

    function checkUncommittedSource() {
        if (SystemCardDragSession.phase
                !== SystemCardDragSession.idlePhase) {
            root.fail("uncommitted source did not cancel: "
                + SystemCardDragSession.phase);
            return;
        }
        console.log("DESKTOP_CARD_HANDOFF_SMOKE_PASS");
        Qt.callLater(Qt.quit);
    }

    Component.onCompleted: Qt.callLater(root.beginCommittedSourceCheck)

    Connections {
        target: SystemCardDragSession

        function onFrozenGhostPresented(cardId) {
            root.frozenPresentedId = String(cardId);
        }
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: root.fail(
            "timeout phase=" + root.phase
                + " session=" + SystemCardDragSession.phase)
    }
}
