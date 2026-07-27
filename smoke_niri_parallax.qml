//@ pragma UseQApplication

import QtQuick
import Quickshell
import Clavis.Niri 1.0

ShellRoot {
    id: root

    property int attempts: 0

    Timer {
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            root.attempts += 1;
            if (!Niri.connected || Quickshell.screens.length === 0) {
                if (root.attempts < 60)
                    return;
                stop();
                console.error("NIRI_PARALLAX_SMOKE_FAIL",
                    Niri.lastError);
                Qt.quit();
                return;
            }

            for (let index = 0;
                    index < Quickshell.screens.length; index += 1) {
                const output =
                    String(Quickshell.screens[index].name);
                console.log("NIRI_PARALLAX_STATE", output,
                    JSON.stringify(
                        Niri.workspacesForOutput(output)),
                    JSON.stringify(
                        Niri.activeWorkspaceForOutput(output)));
            }
            stop();
            console.log("NIRI_PARALLAX_SMOKE_PASS");
            Qt.quit();
        }
    }
}
