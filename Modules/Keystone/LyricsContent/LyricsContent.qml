import QtQuick
import QtQuick.Effects
import Quickshell
import Clavis.Lyrics
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var player
    property bool active: false
    property bool vertical: false
    property string edge: "top"
    property int defaultTextWidth: 350
    property int currentTextWidth: defaultTextWidth
    readonly property var lyricsModel: Lyrics.lyrics
    readonly property string artUrl: player ? player.trackArtUrl || "" : ""
    readonly property string spectrumToken: "keystone-lyrics"
    readonly property int horizontalHeight: 42
    readonly property int horizontalWidth: 102 + currentTextWidth
    readonly property int currentLineIndex: {
        const lines = Lyrics.lyrics;
        if (!root.player || !Lyrics.hasSynchronizedLyrics || !lines || lines.length === 0)
            return -1;

        const position = root.player === MediaManager.active ? MediaManager.currentPosition : Math.max(0, Number(root.player.position) || 0);
        return Lyrics.indexForTime(position);
    }

    implicitWidth: vertical ? horizontalHeight : horizontalWidth
    implicitHeight: vertical ? horizontalWidth : horizontalHeight
    Component.onCompleted: {
        if (root.active)
            AudioSpectrum.acquire(root.spectrumToken);

    }
    Component.onDestruction: AudioSpectrum.release(root.spectrumToken)

    Connections {
        function onActiveChanged() {
            if (root.active)
                AudioSpectrum.acquire(root.spectrumToken);
            else
                AudioSpectrum.release(root.spectrumToken);
        }

        target: root
    }

    Item {
        id: rotatedLayout

        anchors.centerIn: parent
        width: root.horizontalWidth
        height: root.horizontalHeight
        rotation: !root.vertical ? 0 : root.edge === "left" ? -90 : 90

        Item {
            id: albumCoverContainer

            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26

            Image {
                id: coverImage

                anchors.fill: parent
                source: root.artUrl
                visible: source !== ""
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true

                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: coverMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

            }

            Rectangle {
                id: coverMask

                anchors.fill: parent
                radius: 5
                color: "black"
                visible: false
                layer.enabled: true
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                text: "music_note"
                iconSize: 14
                color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.5)
            }

        }

        StyledListView {
            id: lyricsView

            anchors.left: albumCoverContainer.right
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.currentTextWidth
            interactive: false
            animateAppearance: false
            animateMovement: false
            showVerticalScrollBar: false
            model: root.lyricsModel
            currentIndex: root.currentLineIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: 0
            highlightMoveDuration: 400

            delegate: Item {
                required property var modelData
                required property int index
                readonly property bool isCurrent: index === root.currentLineIndex

                width: ListView.view.width
                height: root.horizontalHeight
                onIsCurrentChanged: {
                    if (isCurrent)
                        root.currentTextWidth = Math.max(root.defaultTextWidth, Math.min(lyricText.implicitWidth, 800));

                }

                Text {
                    id: lyricText

                    anchors.centerIn: parent
                    text: parent.modelData.text
                    color: Appearance.m3colors.darkmode ? "white" : "black"
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.expressiveFastEffects.duration
                            easing.type: Appearance.animation.expressiveFastEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                        }

                    }

                }

            }

        }

        Text {
            anchors.centerIn: lyricsView
            width: lyricsView.width - 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.65)
            font.family: Fonts.ui
            font.pixelSize: 13
            visible: Lyrics.status !== "ready"
            text: Lyrics.status === "loading" ? qsTr("正在加载歌词…") : Lyrics.status === "error" ? Lyrics.error || qsTr("歌词加载失败") : qsTr("暂无歌词")
        }

        Item {
            id: spectrumContainer

            property var smoothValues: [0, 0, 0, 0, 0, 0]

            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 21
            height: 16

            Timer {
                interval: 16
                running: root.active && AudioSpectrum.available
                repeat: true
                onTriggered: {
                    const values = AudioSpectrum.values;
                    if (!values || values.length < 6)
                        return ;

                    const ranges = [[0.55, 0.78, 1.5], [0.18, 0.33, 1.2], [0, 0.08, 1], [0.08, 0.18, 1], [0.33, 0.55, 1.2], [0.78, 0.98, 1.5]];
                    const next = spectrumContainer.smoothValues.slice();
                    for (let index = 0; index < ranges.length; ++index) {
                        const range = ranges[index];
                        const start = Math.floor(values.length * range[0]);
                        const end = Math.min(values.length - 1, Math.floor(values.length * range[1]));
                        let maximum = 0;
                        for (let sample = start; sample <= end; ++sample) maximum = Math.max(maximum, values[sample])
                        const target = Math.min(100, maximum * 100 * range[2]);
                        const difference = target - next[index];
                        next[index] += (difference > 0 ? 0.85 : 0.08) * difference;
                    }
                    spectrumContainer.smoothValues = next;
                    spectrumCanvas.requestPaint();
                }
            }

            Canvas {
                id: spectrumCanvas

                anchors.fill: parent
                onPaint: {
                    const context = getContext("2d");
                    context.clearRect(0, 0, width, height);
                    context.beginPath();
                    context.lineCap = "round";
                    context.lineWidth = 2.5;
                    context.strokeStyle = String(Appearance.colors.colPrimary);
                    for (let index = 0; index < 6; ++index) {
                        const amount = Math.min(1, spectrumContainer.smoothValues[index] / 100);
                        const barHeight = Math.max(3, amount * height);
                        const x = 1.25 + index * 3.7;
                        context.moveTo(x, height / 2 - barHeight / 2);
                        context.lineTo(x, height / 2 + barHeight / 2);
                    }
                    context.stroke();
                }
            }

        }

    }

}
