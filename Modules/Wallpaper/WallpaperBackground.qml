import QtQuick
import qs.Services

Item {
    id: root

    OverviewWallpaper {}

    Loader {
        id: desktopLoader

        active: AwwwWallpaperService.quickshellSurfaceRequested
        asynchronous: false
        sourceComponent: Component {
            DesktopWallpaper {}
        }
    }
}
