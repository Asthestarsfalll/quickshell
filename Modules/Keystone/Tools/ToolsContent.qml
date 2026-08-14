import QtQuick
import QtQuick.Layouts
import QtQuick.Window 
import qs.Common
import qs.Widgets.common

Item {
    id: toolsRoot

    property bool vertical: false
    property string edge: "top"
    property string popupEdge: edge

    ToolsBackend {
        id: toolsBackend
    }

    signal requestHideKeystone()

    property var toolsModel: [
        { icon: "colorize",         tip: qsTr("取色器") },
        { icon: "videocam",         tip: qsTr("录屏") },
        { icon: "gif",              tip: qsTr("录制 GIF") },
        { icon: "crop_free",        tip: qsTr("普通截屏") },
        { icon: "height",           tip: qsTr("截长屏") },
        { icon: "document_scanner", tip: qsTr("OCR 识别") },
        { icon: "mic",              tip: qsTr("录麦克风") },
        { icon: "speaker",          tip: qsTr("录电脑声音") }
    ]

    property int selectedIndex: 0

    focus: visible
    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            forceActiveFocus(); 
        }
    }

    Keys.onLeftPressed: {
        selectedIndex = (selectedIndex - 1 + toolsModel.length) % toolsModel.length
    }
    
    Keys.onRightPressed: {
        selectedIndex = (selectedIndex + 1) % toolsModel.length
    }
    Keys.onUpPressed: {
        if (toolsRoot.vertical)
            selectedIndex = (selectedIndex - 1 + toolsModel.length) % toolsModel.length
    }
    Keys.onDownPressed: {
        if (toolsRoot.vertical)
            selectedIndex = (selectedIndex + 1) % toolsModel.length
    }
    
    Keys.onReturnPressed: triggerSelected()
    Keys.onEnterPressed: triggerSelected()

    function triggerSelected() {
        toolsRoot.requestHideKeystone()
        
        if (selectedIndex === 0) {
            toolsBackend.pickColor()
        } else if (selectedIndex === 1) {
            toolsBackend.startRecord("video")
        } else if (selectedIndex === 2) {
            toolsBackend.startRecord("gif")
        } else if (selectedIndex === 3) {
            toolsBackend.takeScreenshot()
        } else if (selectedIndex === 6) {
            toolsBackend.startAudio("mic")
        } else if (selectedIndex === 7) {
            toolsBackend.startAudio("system")
        } else {
            console.warn("[Tools] backend unavailable", toolsModel[selectedIndex].tip)
        }
    }

    function stopRecording() {
        toolsBackend.stopRecord()
    }
    function stopAudio() {
        toolsBackend.stopAudio()
    }

    Grid {
        anchors.centerIn: parent
        spacing: 8
        columns: toolsRoot.vertical ? 1 : toolsRoot.toolsModel.length

        Repeater {
            model: toolsRoot.toolsModel

            IconButton {
                controlSize: 48
                iconName: modelData.icon
                iconSize: 22
                iconColor: Appearance.colors.colOnSurface
                selectedIconColor: Appearance.colors.colOnSurface
                accessibleName: modelData.tip
                selected: index === toolsRoot.selectedIndex
                selectedContainerColor: Appearance.colors.colLayer2Hover
                selectedHoverContainerColor: Appearance.colors.colLayer2Hover
                selectedPressedContainerColor: Appearance.colors.colLayer2Active
                hoverContainerColor: Appearance.colors.colLayer2Hover
                pressedContainerColor: Appearance.colors.colLayer2Active
                onPointerHoveredChanged: {
                    if (pointerHovered)
                        toolsRoot.selectedIndex = index;
                }
                onClicked: {
                    toolsRoot.selectedIndex = index;
                    toolsRoot.triggerSelected();
                }
            }
        }
    }
}
