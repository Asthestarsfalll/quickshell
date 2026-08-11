import QtQuick
import M3Shapes
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Modules.SystemCards
import "../../SystemCards/SystemCardGeometry.js" as CardGeometry
import "./system"
import "./system/SystemGridLayout.js" as GridLayout

Item {
    id: root

    property string screenName: ""
    property bool foreground: false
    readonly property bool isForeground: root.foreground
    readonly property var activeSidebarIds: {
        const ids = SystemCardService.sidebarCardIds.slice();
        // Keep the hidden source delegate available only as long as the
        // global visual ghost needs its ShaderEffectSource.  It is not a
        // second ownership record and never suppresses the Desktop delegate.
        if (SystemCardDragSession.active
                && SystemCardDragSession.tileId !== ""
                && ids.indexOf(SystemCardDragSession.tileId) === -1) {
            ids.push(SystemCardDragSession.tileId);
        }
        return ids;
    }
    readonly property var tileDefinitions:
        GridLayout.definitions(root.activeSidebarIds)
    readonly property int gridColumns: GridLayout.columnCount
    readonly property int gridRows:
        GridLayout.contentRowCount(
            root.committedLayout, root.activeSidebarIds)
    readonly property real gridGap: CardGeometry.cellGap
    readonly property int gridCellWidth: CardGeometry.baseCellWidth
    readonly property int gridCellHeight: CardGeometry.baseCellHeight
    readonly property int gridContentWidth:
        root.gridColumns * root.gridCellWidth
            + (root.gridColumns - 1) * root.gridGap
    readonly property int gridContentHeight:
        root.gridRows * root.gridCellHeight
            + (root.gridRows - 1) * root.gridGap
    readonly property var sidebarAnchors: {
        const result = {};
        root.activeSidebarIds.forEach(function(id) {
            result[id] = SystemCardService.sidebarAnchor(id);
        });
        return result;
    }

    property bool preferencesApplied: false
    property bool serviceForegroundAcquired: false
    property var committedLayout: GridLayout.defaultLayout(
        root.activeSidebarIds, root.sidebarAnchors)
    property var previewLayout: []
    property string draggingTileId: ""
    property Item dragSourceItem: null
    property real dragPointerX: 0
    property real dragPointerY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property int targetColumn: -1
    property int targetRow: -1
    property bool dragTargetValid: false
    property bool desktopExtraction: false

    function layoutPlacement(layout, tileId) {
        return GridLayout.placementFor(layout, tileId);
    }

    function cardSize(tileId) {
        return CardGeometry.sizeFor(String(tileId));
    }

    readonly property Item timeCardItem: {
        if (!root.isForeground)
            return null;
        for (let index = 0; index < tileRepeater.count; ++index) {
            const item = tileRepeater.itemAt(index);
            if (item && item.tileId === "time")
                return item;
        }
        return null;
    }

    function displayPlacement(tileId) {
        if (root.draggingTileId === tileId)
            return root.layoutPlacement(root.committedLayout, tileId);
        if (root.draggingTileId.length > 0
                && root.dragTargetValid && !root.desktopExtraction) {
            return root.layoutPlacement(root.previewLayout, tileId);
        }
        return root.layoutPlacement(root.committedLayout, tileId);
    }

    function sidebarContainsPoint(x, y) {
        let item = root;
        while (item) {
            if (typeof item.containsPoint === "function")
                return item.containsPoint(x, y);
            item = item.parent;
        }
        return false;
    }

    function applyStoredLayout(forceRefresh) {
        if ((!forceRefresh && root.preferencesApplied)
                || !UiPreferences.preferencesReady
                || root.draggingTileId.length > 0) {
            return;
        }

        const hydrated = GridLayout.hydrateSaved(
            UiPreferences.systemGridLayout,
            root.activeSidebarIds,
            root.sidebarAnchors
        );
        const normalized = GridLayout.serializeLayout(
            hydrated, root.activeSidebarIds);
        root.committedLayout = hydrated;
        root.preferencesApplied = true;
        if (JSON.stringify(normalized)
                !== JSON.stringify(UiPreferences.systemGridLayout || {})) {
            UiPreferences.setSystemGridLayout(normalized);
        }
    }

    function beginDrag(tileId, sourceItem, pointerX, pointerY) {
        if (root.draggingTileId.length > 0)
            root.cancelDrag();

        root.draggingTileId = tileId;
        root.dragSourceItem = sourceItem;
        root.dragPointerX = pointerX;
        root.dragPointerY = pointerY;
        const sourcePosition = sourceItem.mapToItem(null, 0, 0);
        root.dragOffsetX = pointerX - sourcePosition.x;
        root.dragOffsetY = pointerY - sourcePosition.y;
        root.targetColumn = -1;
        root.targetRow = -1;
        root.dragTargetValid = false;
        root.desktopExtraction = false;
        SystemCardDragSession.begin(
            tileId,
            sourceItem,
            pointerX,
            pointerY,
            root.dragOffsetX,
            root.dragOffsetY
        );
        dashboard.forceActiveFocus();
        root.updateDrag(tileId, pointerX, pointerY);
    }

    function updateDrag(tileId, pointerX, pointerY) {
        if (tileId !== root.draggingTileId)
            return;

        root.dragPointerX = pointerX;
        root.dragPointerY = pointerY;
        SystemCardDragSession.update(pointerX, pointerY);

        if (root.desktopExtraction)
            return;
        if (!root.sidebarContainsPoint(pointerX, pointerY)) {
            root.desktopExtraction = true;
            root.previewLayout = [];
            root.dragTargetValid = false;
            root.targetColumn = -1;
            root.targetRow = -1;
            return;
        }

        const localPoint = dashboard.mapFromItem(null, pointerX, pointerY);
        const definition = GridLayout.tileDefinitionFor(tileId);
        if (!definition)
            return;

        const rawColumn = Math.round(
            (localPoint.x - root.dragOffsetX) / dashboard.columnStride
        );
        const rawRow = Math.round(
            (localPoint.y - root.dragOffsetY)
                / dashboard.rowStride
        );
        const anchor = GridLayout.clampAnchor(
            definition,
            rawColumn,
            rawRow
        );
        if (anchor.column === root.targetColumn
                && anchor.row === root.targetRow) {
            return;
        }

        root.targetColumn = anchor.column;
        root.targetRow = anchor.row;
        const solved = GridLayout.moveLayout(
            root.committedLayout,
            tileId,
            anchor.column,
            anchor.row,
            root.activeSidebarIds
        );
        root.previewLayout = solved || [];
        root.dragTargetValid = solved !== null;
    }

    function finishDrag(tileId) {
        if (tileId !== root.draggingTileId)
            return;

        if (root.desktopExtraction) {
            const scene = root.screenName !== ""
                ? WallpaperSceneService.sceneFor(root.screenName) : null;
            // The persisted point is the Card's top-left corner, not the
            // pointer location.  This is the same corner represented by the
            // top-level ShaderEffectSource ghost.
            const topLeftX = root.dragPointerX
                - SystemCardDragSession.offsetX;
            const topLeftY = root.dragPointerY
                - SystemCardDragSession.offsetY;
            const point = scene
                ? scene.screenToWallpaper(topLeftX, topLeftY)
                : { x: topLeftX, y: topLeftY };
            const canvasWidth = scene ? scene.canvasWidth : 1;
            const canvasHeight = scene ? scene.canvasHeight : 1;
            const size = root.cardSize(tileId);
            const wallpaperX = Math.max(0, Math.min(
                Math.max(0, canvasWidth - size.width), point.x));
            const wallpaperY = Math.max(0, Math.min(
                Math.max(0, canvasHeight - size.height), point.y));
            SystemCardDragSession.freezeGhost();
            const committed = SystemCardService.setContainer(
                tileId,
                "desktop",
                root.screenName,
                wallpaperX / Math.max(1, canvasWidth),
                wallpaperY / Math.max(1, canvasHeight)
            );
            const card = SystemCardService.card(tileId);
            if (!committed || !card || !card.enabled
                    || card.container !== "desktop") {
                console.warn(
                    "[SystemCards] desktop transfer rejected", tileId);
                SystemCardDragSession.cancel();
                root.resetDragState(false);
                return;
            }
            SystemCardDragSession.markTransferCommitted(tileId);
            root.resetDragState(true);
            WidgetState.leftSidebarOpen = false;
            SystemCardDragSession.finishTransfer();
            return;
        }

        if (root.dragTargetValid) {
            root.committedLayout = root.previewLayout;
            UiPreferences.setSystemGridLayout(
                GridLayout.serializeLayout(
                    root.committedLayout, root.activeSidebarIds)
            );
            SystemCardService.setSidebarLayout(root.committedLayout);
        }
        root.resetDragState(false);
    }

    function cancelDrag(tileId) {
        if (tileId && tileId !== root.draggingTileId)
            return;
        SystemCardDragSession.cancel();
        root.resetDragState(false);
    }

    function resetDragState(keepSession) {
        if (!keepSession)
            SystemCardDragSession.end();
        root.draggingTileId = "";
        root.dragSourceItem = null;
        root.previewLayout = [];
        root.dragTargetValid = false;
        root.targetColumn = -1;
        root.targetRow = -1;
        root.desktopExtraction = false;
    }

    function syncServiceOwnership() {
        if (root.isForeground && !root.serviceForegroundAcquired) {
            SystemCardService.setSidebarForeground(true);
            root.serviceForegroundAcquired = true;
        } else if (!root.isForeground && root.serviceForegroundAcquired) {
            SystemCardService.setSidebarForeground(false);
            root.serviceForegroundAcquired = false;
        }
    }

    onIsForegroundChanged: root.syncServiceOwnership()

    onActiveSidebarIdsChanged: {
        if (root.draggingTileId.length === 0)
            root.applyStoredLayout(true);
    }

    Component.onCompleted: {
        root.applyStoredLayout();
        root.syncServiceOwnership();
    }

    Component.onDestruction: {
        if (root.draggingTileId !== ""
                && !SystemCardDragSession.transferCommitted)
            SystemCardDragSession.cancel();
        if (root.serviceForegroundAcquired)
            SystemCardService.setSidebarForeground(false);
    }

    Connections {
        target: UiPreferences

        function onPreferencesReadyChanged() {
            root.applyStoredLayout();
        }

        function onSystemGridLayoutChanged() {
            if (root.preferencesApplied)
                root.applyStoredLayout(true);
        }
    }

    Connections {
        target: SystemCardService

        function onCardStateChanged() {
            if (root.draggingTileId !== "") {
                const card = SystemCardService.card(root.draggingTileId);
                if (!card || !card.enabled) {
                    root.cancelDrag(root.draggingTileId);
                    return;
                }
            }
            root.applyStoredLayout(true);
        }
    }

    Connections {
        target: SystemCardDragSession

        function onCancelRequested(tileId) {
            if (root.draggingTileId === String(tileId))
                root.cancelDrag(String(tileId));
        }

        function onCanceled() {
            // A destroyed source item can cancel the global session after
            // this page has stopped receiving pointer events.  Clear only
            // local gesture UI; no CardState rollback is performed here.
            if (root.draggingTileId !== "")
                root.resetDragState(false);
        }
    }

    Item {
        anchors {
            fill: parent
            margins: Appearance.spacing.small
        }

        SystemLoadingState {
            anchors.fill: parent
            active: root.isForeground && !SystemMonitorService.error
            visible: !SystemMonitorService.hasData
                && !SystemMonitorService.error
                && !SystemMonitorService.reconnecting
            message: qsTr("正在连接 keytop")
        }

        SystemUnavailableState {
            anchors {
                fill: parent
                topMargin: Appearance.spacing.large
                bottomMargin: Appearance.spacing.large
            }
            visible: !SystemMonitorService.hasData
                && (SystemMonitorService.error
                    || SystemMonitorService.reconnecting)
            title: SystemMonitorService.reconnecting
                ? qsTr("正在重新连接")
                : qsTr("系统监测暂不可用")
            message: SystemMonitorService.error
                ? qsTr("数据暂时缺失，页面将在后台退避重试。")
                : qsTr("连接中断后会自动恢复；已有数据不会被伪装成正常值。")
            reconnecting: SystemMonitorService.reconnecting
            onRetryRequested: SystemMonitorService.retry()
        }

        StyledFlickable {
            id: dashboardScroll

            anchors.fill: parent
            visible: SystemMonitorService.hasData
            contentWidth: width
            contentHeight: Math.max(height, root.gridContentHeight)
            interactive: contentHeight > height + 1
                && root.draggingTileId.length === 0
            showVerticalScrollBar: contentHeight > height + 1
            activeFocusOnTab: contentHeight > height + 1
            Accessible.name: contentHeight > height + 1
                ? qsTr("系统信息网格，可滚动并可拖动卡片")
                : qsTr("系统信息网格，可拖动卡片")

            function scrollBy(delta) {
                const next = dashboardScroll.clampContentY(
                    dashboardScroll.contentY + delta);
                dashboardScroll.scrollTargetY = next;
                dashboardScroll.contentY = next;
            }

            Keys.onPressed: event => {
                if (root.draggingTileId.length > 0
                        && event.key === Qt.Key_Escape) {
                    root.cancelDrag();
                    event.accepted = true;
                    return;
                }
                if (dashboardScroll.contentHeight <= dashboardScroll.height + 1)
                    return;
                if (event.key === Qt.Key_Up)
                    dashboardScroll.scrollBy(-64);
                else if (event.key === Qt.Key_Down)
                    dashboardScroll.scrollBy(64);
                else if (event.key === Qt.Key_PageUp)
                    dashboardScroll.scrollBy(-dashboardScroll.height * 0.8);
                else if (event.key === Qt.Key_PageDown)
                    dashboardScroll.scrollBy(dashboardScroll.height * 0.8);
                else if (event.key === Qt.Key_Home)
                    dashboardScroll.scrollBy(-dashboardScroll.contentHeight);
                else if (event.key === Qt.Key_End)
                    dashboardScroll.scrollBy(dashboardScroll.contentHeight);
                else
                    return;
                event.accepted = true;
            }

            Item {
                id: dashboard

                x: Math.max(0, Math.floor(
                    (dashboardScroll.width - root.gridContentWidth) / 2))
                width: root.gridContentWidth
                height: root.gridContentHeight
                focus: root.draggingTileId.length > 0

                readonly property int cellWidth: root.gridCellWidth
                readonly property int cellHeight: root.gridCellHeight
                readonly property real columnStride:
                    cellWidth + root.gridGap
                readonly property real rowStride:
                    cellHeight + root.gridGap

                Keys.onEscapePressed: event => {
                    if (root.draggingTileId.length === 0)
                        return;
                    root.cancelDrag();
                    event.accepted = true;
                }

                Rectangle {
                    id: targetPreview

                    x: root.targetColumn * dashboard.columnStride
                    y: root.targetRow * dashboard.rowStride
                    width: {
                        const definition = GridLayout.tileDefinitionFor(
                            root.draggingTileId);
                        return definition
                            ? CardGeometry.widthForSpan(
                                definition.columnSpan) : 0;
                    }
                    height: {
                        const definition = GridLayout.tileDefinitionFor(
                            root.draggingTileId);
                        return definition
                            ? CardGeometry.heightForSpan(
                                definition.rowSpan) : 0;
                    }
                    visible: root.draggingTileId.length > 0
                        && !root.desktopExtraction
                        && root.targetColumn >= 0
                        && root.targetRow >= 0
                    radius: Appearance.rounding.extraLarge
                    color: Appearance.applyAlpha(
                        root.dragTargetValid
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colError,
                        0.14)
                    border.width: 2
                    border.color: root.dragTargetValid
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colError
                    z: 20

                    Behavior on x {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                }

                Repeater {
                    id: tileRepeater

                    model: root.tileDefinitions

                    delegate: SystemGridTile {
                        id: tile

                        required property var modelData
                        readonly property var definition: modelData
                        readonly property var placement:
                            root.displayPlacement(tile.tileId)

                        tileId: definition.id
                        x: placement
                            ? placement.column * dashboard.columnStride : 0
                        y: placement
                            ? placement.row * dashboard.rowStride : 0
                        width: root.cardSize(tile.tileId).width
                        height: root.cardSize(tile.tileId).height
                        active: root.isForeground
                        dragging: root.draggingTileId === tile.tileId
                        z: dragging ? 30 : 1

                        onDragStarted: (
                            tileId, sourceItem, pointerX, pointerY
                        ) => root.beginDrag(
                            tileId, sourceItem, pointerX, pointerY)
                        onDragMoved: (
                            tileId, pointerX, pointerY
                        ) => root.updateDrag(
                            tileId, pointerX, pointerY)
                        onDragFinished: tileId => root.finishDrag(tileId)
                        onDragCanceled: tileId => root.cancelDrag(tileId)
                    }
                }
            }
        }
    }
}
