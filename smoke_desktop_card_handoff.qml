//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Services

ShellRoot {
    id: root

    property Item sourceItem: null
    property string phase: "normal-handoff"
    property var committedSourceRect: null
    property int handoffCheckCount: 0

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
            "cpu", "test-output", root.sourceItem,
            100, 120, 20, 30, 200, 160, 1920, 1080);
        SystemCardDragSession.freezeGhost();
        SystemCardDragSession.prepareVisualHandoff("cpu");
        SystemCardDragSession.markTransferCommitted("cpu");
        const rect = SystemCardDragSession.presentationGhostRect;
        if (!rect.valid || rect.x !== 80 || rect.y !== 90
                || rect.width !== 200 || rect.height !== 160) {
            root.fail("presentation ghost rect was not captured exactly: "
                + JSON.stringify(rect));
            return;
        }
        if (SystemCardDragSession.phase
                === SystemCardDragSession.idlePhase) {
            root.fail("commit synchronously cleared the handoff barrier");
            return;
        }
        if (!SystemCardDragSession.requestVisualHandoffCheck("cpu")) {
            root.fail("could not request the ready delegate check");
            return;
        }
        Qt.callLater(root.checkCommittedSource);
    }

    function checkCommittedSource() {
        if (root.handoffCheckCount !== 1) {
            root.fail("normal handoff check count was "
                + root.handoffCheckCount);
            return;
        }
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
            "battery", "test-output", root.sourceItem,
            100, 120, 20, 30, 200, 160, 1920, 1080);
        SystemCardDragSession.freezeGhost();
        SystemCardDragSession.prepareVisualHandoff("battery");
        SystemCardDragSession.markTransferCommitted("battery");
        SystemCardDragSession.finishTransfer();
        root.committedSourceRect =
            SystemCardDragSession.presentationGhostRect;
        root.sourceItem.destroy();
        root.phase = "committed-source-destroyed";
        Qt.callLater(root.checkCommittedSourceDestroyed);
    }

    function checkCommittedSourceDestroyed() {
        if (SystemCardDragSession.phase
                === SystemCardDragSession.idlePhase) {
            root.fail("committed source destruction cleared handoff");
            return;
        }
        if (!SystemCardDragSession.transferCommitted
                || !SystemCardDragSession.visualHandoffPending) {
            root.fail("committed source destruction cleared transfer state");
            return;
        }
        if (SystemCardDragSession.tileId !== "battery") {
            root.fail("committed source destruction cleared tile id");
            return;
        }

        const rect = SystemCardDragSession.presentationGhostRect;
        const before = root.committedSourceRect;
        if (!rect.valid || !before || rect.x !== before.x
                || rect.y !== before.y || rect.width !== before.width
                || rect.height !== before.height) {
            root.fail("presentation rect did not survive source destruction: "
                + JSON.stringify(rect));
            return;
        }

        if (!SystemCardDragSession.requestVisualHandoffCheck("battery")) {
            root.fail("post-destruction handoff check was not requested");
            return;
        }
        root.phase = "committed-handoff-complete";
        Qt.callLater(root.checkCommittedHandoffComplete);
    }

    function checkCommittedHandoffComplete() {
        if (root.handoffCheckCount !== 2) {
            root.fail("post-destruction handoff check count was "
                + root.handoffCheckCount);
            return;
        }
        if (SystemCardDragSession.phase
                !== SystemCardDragSession.idlePhase) {
            root.fail("handoff completion did not return to idle: "
                + SystemCardDragSession.phase);
            return;
        }
        if (SystemCardDragSession.visualHandoffPending
                || SystemCardDragSession.transferCommitted) {
            root.fail("handoff completion left transfer state behind");
            return;
        }

        root.sourceItem = sourceComponent.createObject(root);
        SystemCardDragSession.begin(
            "gpu", "test-output", root.sourceItem,
            0, 0, 0, 0, 200, 160, 1920, 1080);
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

        function onHandoffCheckRequested(tileId) {
            root.handoffCheckCount += 1;
            if (!SystemCardDragSession.completeVisualHandoff(tileId))
                root.fail("ready delegate did not complete " + tileId);
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
