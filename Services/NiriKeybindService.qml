pragma Singleton

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    readonly property var actions: [
        ({ "id": "lock", "category": qsTr("Shell"), "title": qsTr("锁屏"), "defaultKey": "Mod+P", "action": "spawn-sh \"$CLAVIS_KEY ipc call lock open\";" }),
        ({ "id": "dashboard", "category": qsTr("Shell"), "title": qsTr("打开仪表盘"), "defaultKey": "Mod+M", "action": "spawn-sh \"$CLAVIS_KEY ipc call keystone dashboard\";" }),
        ({ "id": "tools", "category": qsTr("Shell"), "title": qsTr("打开工具面板"), "defaultKey": "Mod+Shift+T", "action": "spawn-sh \"$CLAVIS_KEY ipc call keystone tools\";" }),
        ({ "id": "hub", "category": qsTr("Shell"), "title": qsTr("打开壁纸中心"), "defaultKey": "Mod+Shift+W", "action": "spawn-sh \"$CLAVIS_KEY ipc call keystone hub\";" }),
        ({ "id": "spotlight", "category": qsTr("Shell"), "title": qsTr("打开 Spotlight"), "defaultKey": "Mod+D", "action": "spawn-sh \"$CLAVIS_KEY ipc call spotlight toggle\";" })
    ]
    property int pendingRevision: 0
    property var pendingOverrides: null
    property string lastError: ""
    readonly property var bindings:
        NiriConfigService.status.keybindings || []
    readonly property var conflicts:
        NiriConfigService.status.keybindConflicts || []

    signal applied()
    signal failed(string message)

    function saveOverride(actionId, key) {
        const action = root.actions.find(item => item.id === actionId)
        if (!action)
            return
        const overrides = Object.assign({},
            PersonalizationConfig.niriKeybindOverrides)
        if (!key || String(key).trim() === "")
            delete overrides[actionId]
        else
            overrides[actionId] = String(key).trim()
        const rendered = ({})
        for (const item of root.actions) {
            const binding = overrides[item.id]
            if (binding)
                rendered[binding] = item.action
        }
        root.pendingOverrides = overrides
        root.pendingRevision = NiriConfigService.applyDomain("binds", rendered)
    }

    Connections {
        target: NiriConfigService
        function onApplySucceeded(domain, revision) {
            if (domain !== "binds" || revision !== root.pendingRevision)
                return
            PersonalizationConfig.setNiriKeybindOverrides(root.pendingOverrides)
            root.pendingOverrides = null
            root.lastError = ""
            root.applied()
        }
        function onApplyFailed(domain, revision, message) {
            if (domain !== "binds" || revision !== root.pendingRevision)
                return
            root.pendingOverrides = null
            root.lastError = message
            root.failed(message)
        }
    }
}
