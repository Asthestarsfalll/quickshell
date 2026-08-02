import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services as Services
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    
    // 维持 36 的高度
    implicitHeight: 36
    implicitWidth: layout.width + 16

    TopBarPillBackground {
        anchors.fill: parent
        fillColor: Services.BlurService.backgroundColor(
            Appearance.colors.colLayer0)
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8 
        
        // 直接调用同目录下的组件，无需 import
        Network {
            screen: root.screen
        }
        Brightness {
            screen: root.screen
        }
        Volume {
            screen: root.screen
        }
        Microphone {
            screen: root.screen
        }
        SettingsButton {
            screen: root.screen
        }
        PowerButton {}
    }
}
