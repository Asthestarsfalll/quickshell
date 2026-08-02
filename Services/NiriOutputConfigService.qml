pragma Singleton

import QtQuick
import qs.Services

Singleton {
    id: root

    property var pending: ({})
    property var rollback: ({})
    property string lastError: ""
    readonly property bool busy: NiriRuntimeService.busy
        || NiriConfigService.busy

    signal applied(string outputName)
    signal failed(string outputName, string message)

    function settingsWith(outputName, patch) {
        const all = Object.assign({}, PersonalizationConfig.niriOutputSettings)
        all[outputName] = Object.assign({}, all[outputName] || {}, patch)
        return all
    }

    function preview(outputName, patch, actual) {
        const pending = Object.assign({}, root.pending)
        pending[outputName] = root.settingsWith(outputName, patch)
        root.pending = pending
        const rollback = Object.assign({}, root.rollback)
        rollback[outputName] = actual
        root.rollback = rollback
        NiriRuntimeService.applyOutput(outputName, patch)
    }

    function setScale(outputName, scale, actualScale) {
        root.preview(outputName, ({ "scale": scale }),
            ({ "scale": actualScale }))
    }

    function setEnabled(outputName, enabled, oldEnabled) {
        root.preview(outputName, ({ "disabled": !enabled }),
            ({ "disabled": !oldEnabled }))
    }

    function setMode(outputName, mode, oldMode) {
        root.preview(outputName, ({ "mode": mode }), ({ "mode": oldMode }))
    }

    function setTransform(outputName, transform, oldTransform) {
        root.preview(outputName, ({ "transform": transform }),
            ({ "transform": oldTransform }))
    }

    function setPosition(outputName, x, y, oldX, oldY) {
        root.preview(outputName,
            ({ "position": ({ "x": x, "y": y }) }),
            ({ "position": ({ "x": oldX, "y": oldY }) }))
    }

    function setVrr(outputName, enabled, oldEnabled) {
        root.preview(outputName, ({ "vrr": enabled }),
            ({ "vrr": oldEnabled }))
    }

    function setFocusAtStartup(outputName, enabled) {
        const pending = Object.assign({}, root.pending)
        pending[outputName] = root.settingsWith(outputName,
            ({ "focusAtStartup": enabled }))
        root.pending = pending
        NiriConfigService.applyDomain("outputs", pending[outputName])
    }

    Connections {
        target: NiriRuntimeService

        function onOutputApplied(outputName, config) {
            const requested = root.pending[outputName]
            if (!requested)
                return
            NiriConfigService.applyDomain("outputs", requested)
        }

        function onOutputFailed(outputName, message) {
            const pending = Object.assign({}, root.pending)
            delete pending[outputName]
            root.pending = pending
            root.lastError = message
            root.failed(outputName, message)
        }
    }

    Connections {
        target: NiriConfigService

        function onApplySucceeded(domain, revision) {
            if (domain !== "outputs")
                return
            const requestedOutputs = Object.keys(root.pending)
            if (requestedOutputs.length === 0)
                return
            const outputName = requestedOutputs[0]
            PersonalizationConfig.setNiriOutputSettings(
                root.pending[outputName])
            const pending = Object.assign({}, root.pending)
            delete pending[outputName]
            root.pending = pending
            const rollback = Object.assign({}, root.rollback)
            delete rollback[outputName]
            root.rollback = rollback
            root.lastError = ""
            root.applied(outputName)
        }

        function onApplyFailed(domain, revision, message) {
            if (domain !== "outputs")
                return
            const requestedOutputs = Object.keys(root.pending)
            if (requestedOutputs.length === 0)
                return
            const outputName = requestedOutputs[0]
            const previous = root.rollback[outputName]
            if (previous)
                NiriRuntimeService.applyOutput(outputName, previous)
            const pending = Object.assign({}, root.pending)
            delete pending[outputName]
            root.pending = pending
            root.lastError = message
            root.failed(outputName, message)
        }
    }
}
