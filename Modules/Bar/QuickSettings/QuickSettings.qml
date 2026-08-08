import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services as Services
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    property bool vertical: false
    
    implicitHeight: vertical ? layout.implicitHeight + 16 : Sizes.barPillThickness
    implicitWidth: vertical ? Sizes.barVisualThickness
        : layout.implicitWidth + 2 * Sizes.barPillHorizontalPadding

    TopBarPillBackground {
        anchors.fill: parent
        fillColor: Services.BlurService.backgroundColor(
            Appearance.colors.colLayer0)
    }

    GridLayout {
        id: layout
        anchors.centerIn: parent
        rowSpacing: 8
        columnSpacing: 8
        columns: root.vertical ? 1 : 6
        
        // 直接调用同目录下的组件，无需 import
        Network {
            screen: root.screen
            vertical: root.vertical
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
