import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin

    property var selectedApplication: null
    property var pendingRemoveEntry: null
    property var parentModal: null
    readonly property real pageContentWidth: 720

    function openApplicationBrowser() {
        appBrowserLoader.active = true;
        if (appBrowserLoader.item)
            appBrowserLoader.item.show();
    }

    function requestRemove(entry) {
        root.pendingRemoveEntry = entry;
        removeDialog.open();
    }

    function removePendingEntry() {
        const entry = root.pendingRemoveEntry;
        removeDialog.close();
        root.pendingRemoveEntry = null;
        if (entry)
            AutostartService.remove(entry);
    }

    function selectedApplicationDescription() {
        if (!root.selectedApplication)
            return "";
        return String(root.selectedApplication.genericName
            || root.selectedApplication.comment || "");
    }

    Loader {
        id: appBrowserLoader

        active: false
        asynchronous: false
        source: Qt.resolvedUrl("AppBrowserPopup.qml")

        onLoaded: item.parentModal = root.parentModal
    }

    Binding {
        target: appBrowserLoader.item
        property: "appsModel"
        value: ApplicationService.applications
        when: appBrowserLoader.status === Loader.Ready
    }

    Connections {
        target: appBrowserLoader.item
        ignoreUnknownSignals: true

        function onAppSelected(application) {
            root.selectedApplication = application;
        }
    }

    Connections {
        target: AutostartService

        function onOperationFinished(success, operation) {
            if (success && operation === "add")
                root.selectedApplication = null;
        }
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth,
            Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.lastError !== ""
                && !AutostartService.initializationFailed
            tone: "error"
            message: AutostartService.lastError
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.lastMessage !== ""
            tone: "info"
            message: AutostartService.lastMessage
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.initializing
            iconName: "progress_activity"
            message: qsTr("正在初始化用户 autostart 目录…")
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.initialized
                && AutostartService.listing
            iconName: "progress_activity"
            message: qsTr("正在加载用户自启条目…")
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !AutostartService.initializing
                && AutostartService.initializationFailed
            spacing: Metrics.spacingS

            InlineStatusBanner {
                Layout.fillWidth: true
                tone: "error"
                message: AutostartService.lastError
            }

            DialogActionButton {
                text: qsTr("重试")
                filled: true
                onClicked: AutostartService.initialize()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingL
            visible: AutostartService.ready

            MaterialCard {
                Layout.fillWidth: true
                iconName: "rocket_launch"
                title: qsTr("添加应用到开机启动")
                supportingText: qsTr("选择已安装应用，创建用户级 Desktop Entry。")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingS

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingS

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Metrics.controlHeightXL
                            radius: Appearance.rounding.normal
                            color: root.selectedApplication
                                ? Appearance.colors.colSecondaryContainer
                                : Appearance.colors.colLayer2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Metrics.spacingM
                                anchors.rightMargin: Metrics.spacingM
                                spacing: Metrics.spacingS

                                Image {
                                    Layout.preferredWidth: Metrics.iconM
                                    Layout.preferredHeight: Metrics.iconM
                                    visible: root.selectedApplication !== null
                                    source: root.selectedApplication
                                        ? ApplicationService.iconSource(
                                            root.selectedApplication.icon) : ""
                                    sourceSize.width: Metrics.iconM * 2
                                    sourceSize.height: Metrics.iconM * 2
                                    fillMode: Image.PreserveAspectFit
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Metrics.spacingXXS

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.selectedApplication
                                            ? root.selectedApplication.name
                                            : qsTr("尚未选择应用")
                                        color: root.selectedApplication
                                            ? Appearance.colors.colOnSecondaryContainer
                                            : Appearance.colors.colOnSurfaceVariant
                                        font.family: Typography.bodyMedium.family
                                        font.pixelSize: Typography.bodyMedium.pixelSize
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: root.selectedApplication !== null
                                            && root.selectedApplicationDescription() !== ""
                                        text: root.selectedApplicationDescription()
                                        color: Appearance.colors.colOnSecondaryContainer
                                        font.family: Typography.bodySmall.family
                                        font.pixelSize: Typography.bodySmall.pixelSize
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        DialogActionButton {
                            text: qsTr("浏览应用")
                            enabled: !AutostartService.busy
                            onClicked: root.openApplicationBrowser()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.selectedApplication !== null
                        text: root.selectedApplication
                            ? qsTr("Desktop Entry ID：%1").arg(
                                root.selectedApplication.id) : ""
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.mono
                        font.pixelSize: Typography.bodySmall.pixelSize
                        elide: Text.ElideMiddle
                    }

                    DialogActionButton {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("添加到自启")
                        filled: true
                        enabled: !AutostartService.busy
                            && root.selectedApplication !== null
                        onClicked: AutostartService.addApplication(
                            root.selectedApplication)
                    }
                }
            }

            MaterialCard {
                Layout.fillWidth: true
                iconName: "list_alt"
                title: qsTr("用户自启应用")
                supportingText: AutostartService.autostartDir

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingS

                    Text {
                        Layout.fillWidth: true
                        text: AutostartService.entries.length > 0
                            ? qsTr("只显示用户目录中的 .desktop 条目") : ""
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodySmall.pixelSize
                    }

                    DialogActionButton {
                        text: qsTr("刷新")
                        enabled: AutostartService.ready
                        onClicked: AutostartService.refresh()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXS

                    Repeater {
                        model: AutostartService.entries

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: Math.max(Metrics.controlHeightXL,
                                entryContent.implicitHeight + Metrics.spacingS * 2)
                            radius: Metrics.cornerM
                            color: modelData.valid
                                ? Appearance.colors.colLayer1
                                : Appearance.colors.colErrorContainer

                            RowLayout {
                                id: entryContent

                                anchors.fill: parent
                                anchors.margins: Metrics.spacingS
                                spacing: Metrics.spacingS

                                Image {
                                    Layout.preferredWidth: Metrics.iconL
                                    Layout.preferredHeight: Metrics.iconL
                                    Layout.alignment: Qt.AlignVCenter
                                    source: ApplicationService.iconSourceForEntry(modelData)
                                    sourceSize.width: Metrics.iconL * 2
                                    sourceSize.height: Metrics.iconL * 2
                                    fillMode: Image.PreserveAspectFit
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: Metrics.spacingXXS

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.valid ? modelData.name
                                            : qsTr("无效条目：%1").arg(modelData.name)
                                        color: modelData.valid
                                            ? Appearance.colors.colOnSurface
                                            : Appearance.colors.colOnErrorContainer
                                        font.family: Fonts.ui
                                        font.pixelSize: Typography.bodyMedium.pixelSize
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.valid ? modelData.exec
                                            : modelData.error
                                        color: modelData.valid
                                            ? Appearance.colors.colOnSurfaceVariant
                                            : Appearance.colors.colOnErrorContainer
                                        font.family: Fonts.mono
                                        font.pixelSize: Typography.bodySmall.pixelSize
                                        elide: Text.ElideMiddle
                                    }
                                }

                                StyledSwitch {
                                    Layout.alignment: Qt.AlignVCenter
                                    checked: modelData.valid && !modelData.hidden
                                    enabled: modelData.valid && !AutostartService.busy
                                    onToggled: AutostartService.setEnabled(
                                        modelData, checked)
                                }

                                DialogActionButton {
                                    text: qsTr("删除")
                                    enabled: !AutostartService.busy
                                    onClicked: root.requestRemove(modelData)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: AutostartService.entries.length === 0
                        spacing: Metrics.spacingS

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "rocket_launch"
                            iconSize: Metrics.iconL
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("暂无自启应用")
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("从已安装应用中选择一个加入用户级开机启动。")
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Fonts.ui
                            font.pixelSize: Typography.bodySmall.pixelSize
                        }

                        DialogActionButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("浏览应用")
                            enabled: !AutostartService.busy
                            onClicked: root.openApplicationBrowser()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: removeDialog

        anchors.centerIn: Overlay.overlay
        modal: true
        width: Math.min(420, root.width - Metrics.spacingL * 2)
        padding: Metrics.spacingL
        Material.theme: PersonalizationConfig.themeMode === "light"
            ? Material.Light : Material.Dark
        Material.accent: Appearance.colors.colPrimary

        background: Rectangle {
            radius: Appearance.rounding.large
            color: Appearance.colors.colSurfaceContainerHigh
        }

        header: Text {
            text: qsTr("删除自启条目？")
            color: Appearance.colors.colOnSurface
            font.family: Fonts.ui
            font.pixelSize: Typography.titleMedium.pixelSize
            font.weight: Font.DemiBold
            leftPadding: Metrics.spacingM
            rightPadding: Metrics.spacingM
            topPadding: Metrics.spacingM
        }

        contentItem: Text {
            text: root.pendingRemoveEntry
                ? qsTr("将删除“%1”在用户 autostart 目录中的条目。")
                    .arg(root.pendingRemoveEntry.name) : ""
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Fonts.ui
            font.pixelSize: Typography.bodyMedium.pixelSize
            wrapMode: Text.Wrap
        }

        footer: RowLayout {
            spacing: Metrics.spacingS

            Item { Layout.fillWidth: true }

            DialogActionButton {
                text: qsTr("取消")
                onClicked: removeDialog.close()
            }

            DialogActionButton {
                text: qsTr("删除")
                filled: true
                onClicked: root.removePendingEntry()
            }
        }
    }

    Component.onCompleted: {
        AutostartService.initialize();
    }

    function closeChildWindows() {
        if (appBrowserLoader.item)
            appBrowserLoader.item.hide();
    }
}
