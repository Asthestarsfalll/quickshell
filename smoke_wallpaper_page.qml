//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.ControlCenter

ShellRoot {
    Item {
        width: 900
        height: 1200

        WallpaperPage {
            anchors.fill: parent
        }
    }

    Timer {
        interval: 250
        running: true
        onTriggered: {
            console.log("WALLPAPER_PAGE_SMOKE_PASS");
            Qt.quit();
        }
    }
}
