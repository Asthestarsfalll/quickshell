import QtQuick
import qs.Common

Item {
    id: root

    property var screen: null
    property bool foreground: false
    property bool presentationActive: false

    PageTransitionLayer {
        anchors.fill: parent
        active: root.presentationActive
            && WidgetState.qsView === "network"

        NetworkContent {
            anchors.fill: parent
            foreground: root.foreground
                && WidgetState.qsView === "network"
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.presentationActive
            && WidgetState.qsView === "bluetooth"

        BluetoothContent {
            anchors.fill: parent
            foreground: root.foreground
                && WidgetState.qsView === "bluetooth"
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.presentationActive
            && WidgetState.qsView === "idle"

        IdleContent {
            anchors.fill: parent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.presentationActive
            && WidgetState.qsView === "audio"

        AudioContent {
            anchors.fill: parent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.presentationActive
            && WidgetState.qsView === "microphone"

        MicrophoneContent {
            anchors.fill: parent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.presentationActive
            && WidgetState.qsView === "settings"
        hubPage: true

        SettingsContent {
            anchors.fill: parent
            screen: root.screen
        }
    }
}
