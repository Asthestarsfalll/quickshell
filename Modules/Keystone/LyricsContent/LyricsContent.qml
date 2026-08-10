import QtQuick
import QtQuick.Layouts
import QtQuick.Effects 
import Quickshell
import Quickshell.Services.Mpris
import Clavis.Lyrics
import qs.Common 
import qs.Services 
import qs.Widgets.common

Item {
    id: root
    
    required property var player
    property bool active: false
    readonly property var lyricsModel: Lyrics.lyrics
    readonly property int currentLineIndex: {
        const lines = Lyrics.lyrics;
        const synchronized = Lyrics.hasSynchronizedLyrics;
        if (!root.player || !synchronized || !lines || lines.length === 0)
            return -1;

        const position = root.player === MediaManager.active
            ? MediaManager.currentPosition
            : Math.max(0, Number(root.player.position) || 0);
        return Lyrics.indexForTime(position);
    }
    
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    
    readonly property string spectrumToken: "keystone-lyrics"

    Component.onCompleted: {
        if (root.active)
            AudioSpectrum.acquire(root.spectrumToken);
    }
    Component.onDestruction: AudioSpectrum.release(root.spectrumToken)

    // ============================================================
    // 【动态自适应宽度引擎】
    // ============================================================
    property int defaultTextWidth: 350 
    property int currentTextWidth: defaultTextWidth 
    
    // 左边距(15) + 封面(26) + 间距(12) + 歌词(动态) + 间距(12) + 频谱(22) + 右边距(15) = 102
    implicitWidth: 102 + currentTextWidth 

    Connections {
        target: root
        function onActiveChanged() {
            if (root.active)
                AudioSpectrum.acquire(root.spectrumToken);
            else
                AudioSpectrum.release(root.spectrumToken);
        }
    }

    // The singleton controller owns track loading. This compact view only
    // projects the shared timeline and never cancels or reloads it.

    // ================= 界面层 =================
    Item {
        anchors.fill: parent
        clip: true 

        // --- 专辑封面 ---
        Item {
            id: albumCoverContainer
            anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            
            Image {
                id: coverImg; anchors.fill: parent
                source: root.artUrl; visible: root.artUrl !== ""; fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource { sourceItem: Rectangle { width: coverImg.width; height: coverImg.height; radius: 5; color: "black" } }
                }
            }
            Text {
                visible: root.artUrl === ""; anchors.centerIn: parent
                text: "\uf001"; font.family: Fonts.nerdSymbols; font.pixelSize: 14; color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.50)
            }
        }

        // --- 歌词列表 ---
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
            smoothWheelEnabled: false
            model: root.lyricsModel
            currentIndex: root.currentLineIndex
            
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: 0 
            highlightMoveDuration: 400 

            delegate: Item {
                width: ListView.view.width
                height: 42 
                readonly property bool isCurrent: index === root.currentLineIndex

                onIsCurrentChanged: {
                    if (isCurrent) {
                        root.currentTextWidth = Math.max(root.defaultTextWidth, Math.min(lyricText.implicitWidth, 800))
                    }
                }

                Text {
                    id: lyricText
                    anchors.centerIn: parent
                    text: modelData.text
                    color: parent.isCurrent
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnLayer0
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

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!root.player || root.player.canSeek !== true)
                            return
                        const target = Lyrics.timeForIndex(index)
                        if (target >= 0)
                            root.player.position = target
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
            text: Lyrics.status === "loading"
                ? qsTr("正在加载歌词…")
                : (Lyrics.status === "error"
                    ? (Lyrics.error || qsTr("歌词加载失败"))
                    : qsTr("暂无歌词"))
        }

        // ============================================================
        // 【全新】：高动态对称聚合频谱条
        // ============================================================
        Item {
            id: spectrumContainer
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 21  
            height: 16 

            property var smoothValues: [0, 0, 0, 0, 0, 0]

            Timer {
                interval: 16 
                running: root.active && AudioSpectrum.available
                repeat: true
                onTriggered: {
                    let s = spectrumContainer.smoothValues;
                    let r = AudioSpectrum.values;
                    if (!r || r.length < 6) return;
                    
                    let getRegionMax = (startRatio, endRatio) => {
                        let start = Math.max(0, Math.min(r.length - 1, Math.floor(r.length * startRatio)));
                        let end = Math.max(start, Math.min(r.length - 1, Math.floor(r.length * endRatio)));
                        let maxV = 0;
                        for (let i = start; i <= end; i++) {
                            if (r[i] > maxV) maxV = r[i];
                        }
                        return maxV * 100;
                    };

                    let targets = [0, 0, 0, 0, 0, 0];
                    
                    targets[0] = getRegionMax(0.55, 0.78) * 1.5;
                    targets[5] = getRegionMax(0.78, 0.98) * 1.5;
                    
                    targets[1] = getRegionMax(0.18, 0.33) * 1.2;
                    targets[4] = getRegionMax(0.33, 0.55) * 1.2;
                    
                    targets[2] = getRegionMax(0.00, 0.08);
                    targets[3] = getRegionMax(0.08, 0.18);

                    let globalBeat = Math.max(targets[2], targets[3]);

                    for (let i = 0; i < 6; i++) {
                        let finalTarget = Math.min(100, targets[i] * 0.8 + globalBeat * 0.2);
                        
                        let diff = finalTarget - s[i];
                        
                        if (diff > 0) s[i] += 0.85 * diff;
                        else s[i] += 0.08 * diff;
                    }
                    
                    spectrumContainer.smoothValues = s;
                    spectrumCanvas.requestPaint();
                }
            }

            Canvas {
                id: spectrumCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    let s = parent.smoothValues;
                    
                    ctx.beginPath();
                    ctx.lineCap = "round"; 
                    ctx.lineWidth = 2.5;   
                    ctx.strokeStyle = String(Appearance.colors.colPrimary); 

                    for(let i = 0; i < 6; i++) {
                        let val = Math.min(1.0, s[i] / 100.0);
                        let h = Math.max(3, val * height); // 最低保持 3px 圆点
                        
                        let x = 1.25 + i * 3.7; 
                        
                        ctx.moveTo(x, height / 2 - h / 2);
                        ctx.lineTo(x, height / 2 + h / 2);
                    }
                    ctx.stroke();
                }
            }
        }
    }
}
