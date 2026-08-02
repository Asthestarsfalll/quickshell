pragma Singleton

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    property var pendingSettings: null
    property int pendingRevision: 0
    property string lastError: ""
    readonly property bool busy: NiriConfigService.busy

    signal applied()
    signal failed(string message)

    function apply(settings) {
        root.pendingSettings = Object.assign({}, settings)
        root.pendingRevision = NiriConfigService.applyDomain(
            "layout", root.pendingSettings)
    }

    Connections {
        target: NiriConfigService

        function onApplySucceeded(domain, revision) {
            if (domain !== "layout" || revision !== root.pendingRevision)
                return
            PersonalizationConfig.setNiriLayoutSettings(root.pendingSettings)
            root.pendingSettings = null
            root.lastError = ""
            root.applied()
        }

        function onApplyFailed(domain, revision, message) {
            if (domain !== "layout" || revision !== root.pendingRevision)
                return
            root.pendingSettings = null
            root.lastError = message
            root.failed(message)
        }
    }
}
