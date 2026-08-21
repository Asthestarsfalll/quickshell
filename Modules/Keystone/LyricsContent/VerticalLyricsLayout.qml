import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    required property string lyric
    required property string artUrl
    required property bool active
    required property string edge
    required property string status
    required property string errorText
    property string currentLyric: ""
    property string previousLyric: ""
    property real transitionProgress: 1
    readonly property int padding: 15
    readonly property int contentSpacing: 12
    readonly property int tokenSpacing: 3
    readonly property int lyricWidth: 42
    readonly property real lyricExtent: Math.max(20, currentTokens.implicitHeight, previousTokens.implicitHeight * (1 - transitionProgress))

    function isCjk(character) {
        return /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]/.test(character);
    }

    function isLatinCore(character) {
        return /[A-Za-z0-9]/.test(character);
    }

    function isLatinPunctuation(character) {
        return /['’\-….,!?]/.test(character);
    }

    function tokenize(text) {
        const result = [];
        const source = String(text || "");
        let index = 0;
        while (index < source.length) {
            const character = source[index];
            if (/\s/.test(character)) {
                ++index;
                continue;
            }
            if (isCjk(character)) {
                result.push({
                    "text": character,
                    "latin": false
                });
                ++index;
                continue;
            }
            if (isLatinCore(character)) {
                let token = character;
                ++index;
                while (index < source.length && (isLatinCore(source[index]) || isLatinPunctuation(source[index]))) {
                    token += source[index];
                    ++index;
                }
                result.push({
                    "text": token,
                    "latin": true
                });
                continue;
            }
            result.push({
                "text": character,
                "latin": false
            });
            ++index;
        }
        return result;
    }

    function showLyric(nextLyric) {
        if (nextLyric === currentLyric)
            return ;

        previousLyric = currentLyric;
        currentLyric = nextLyric;
        transitionProgress = 0;
        lyricTransition.restart();
    }

    implicitWidth: lyricWidth
    implicitHeight: padding + 26 + contentSpacing + lyricExtent + contentSpacing + 21 + padding
    onLyricChanged: showLyric(lyric)
    Component.onCompleted: showLyric(lyric)

    LyricsAlbumArt {
        id: albumArt

        anchors.top: parent.top
        anchors.topMargin: root.padding
        anchors.horizontalCenter: parent.horizontalCenter
        sourceUrl: root.artUrl
    }

    Item {
        id: lyricSlot

        anchors.top: albumArt.bottom
        anchors.topMargin: root.contentSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.lyricWidth
        height: root.lyricExtent

        TokenColumn {
            id: previousTokens

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            lyricText: root.previousLyric
            opacity: 1 - root.transitionProgress

            transform: Translate {
                y: -6 * root.transitionProgress
            }

        }

        TokenColumn {
            id: currentTokens

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            lyricText: root.currentLyric
            opacity: root.transitionProgress

            transform: Translate {
                y: 6 * (1 - root.transitionProgress)
            }

        }

        Text {
            anchors.centerIn: parent
            width: root.lyricWidth
            visible: root.status !== "ready"
            text: root.status === "loading" ? qsTr("加载中") : root.status === "error" ? qsTr("失败") : qsTr("暂无")
            color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.65)
            font.family: Fonts.ui
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAnywhere
        }

    }

    Canvas {
        id: spectrum

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padding
        anchors.horizontalCenter: parent.horizontalCenter
        width: 16
        height: 21
        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            context.beginPath();
            context.lineCap = "round";
            context.lineWidth = 2.5;
            context.strokeStyle = String(Appearance.colors.colPrimary);
            const values = AudioSpectrum.values || [];
            for (let index = 0; index < 6; ++index) {
                const sampleIndex = values.length > 0 ? Math.floor(index * (values.length - 1) / 5) : 0;
                const amount = values.length > 0 ? Math.min(1, values[sampleIndex] * 4) : 0;
                const barWidth = Math.max(3, amount * width);
                const y = 1.25 + index * 3.7;
                const start = root.edge === "left" ? 0 : width - barWidth;
                context.moveTo(start, y);
                context.lineTo(start + barWidth, y);
            }
            context.stroke();
        }

        Timer {
            interval: 16
            running: root.active && AudioSpectrum.available
            repeat: true
            onTriggered: parent.requestPaint()
        }

    }

    NumberAnimation {
        id: lyricTransition

        target: root
        property: "transitionProgress"
        from: 0
        to: 1
        duration: Appearance.animation.expressiveDefaultEffects.duration
        easing.type: Appearance.animation.expressiveDefaultEffects.type
        easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
        onFinished: root.previousLyric = ""
    }

    component TokenColumn: Column {
        required property string lyricText
        property var tokenModel: root.tokenize(lyricText)

        width: root.lyricWidth
        spacing: root.tokenSpacing

        Repeater {
            model: parent.tokenModel

            delegate: Item {
                required property var modelData
                readonly property bool latin: modelData.latin

                width: root.lyricWidth
                height: latin ? tokenText.implicitWidth : Math.max(18, tokenText.implicitHeight)

                Text {
                    id: tokenText

                    anchors.centerIn: parent
                    text: parent.modelData.text
                    color: Appearance.m3colors.darkmode ? "white" : "black"
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    rotation: parent.latin ? (root.edge === "left" ? -90 : 90) : 0
                    horizontalAlignment: Text.AlignHCenter
                }

            }

        }

    }

}
