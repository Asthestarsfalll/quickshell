import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components

FocusScope {
    id: root

    property var options: []
    property var values: []
    property string zone: ""
    property var dragCoordinator: null
    property int highlightedIndex: 0
    property bool expanded: false
    property real fieldHeight: 40
    property real itemHeight: 40
    property real menuItemSpacing: 4
    property int maxVisibleItems: 6
    property Item popupBoundsItem: null
    property real scrollTargetX: 0
    property real autoScrollVelocity: 0
    readonly property Item popupParentItem: root.Window.window ? root.Window.window.contentItem : null
    readonly property real menuPadding: 6
    readonly property real menuGap: 6
    readonly property int visibleMenuItemCount: Math.min(Math.max(1, maxVisibleItems), Math.max(1, options.length))
    readonly property real listTargetHeight: visibleMenuItemCount * itemHeight + Math.max(0, visibleMenuItemCount - 1) * menuItemSpacing
    readonly property bool dragActive: dragCoordinator && dragCoordinator.dragActive

    signal toggled(string componentId)
    signal removed(string componentId)

    function optionValue(option) {
        return option && typeof option === "object" ? String(option.value || "") : String(option || "");
    }

    function optionLabel(option) {
        return option && typeof option === "object" ? String(option.label || option.value || "") : String(option || "");
    }

    function labelFor(componentId) {
        for (let index = 0; index < root.options.length; index += 1) {
            if (root.optionValue(root.options[index]) === componentId)
                return root.optionLabel(root.options[index]);

        }
        return componentId;
    }

    function entryIndex(entryKey) {
        for (let index = 0; index < chipModel.count; index += 1) {
            if (chipModel.get(index).entryKey === entryKey)
                return index;

        }
        return -1;
    }

    function synchronizeEntries(entries) {
        const desiredKeys = entries.map((entry) => {
            return entry.entryKey;
        });
        for (let index = chipModel.count - 1; index >= 0; index -= 1) {
            if (desiredKeys.indexOf(chipModel.get(index).entryKey) === -1)
                chipModel.remove(index);

        }
        for (let index = 0; index < entries.length; index += 1) {
            const entry = entries[index];
            const currentIndex = root.entryIndex(entry.entryKey);
            if (currentIndex < 0) {
                chipModel.insert(index, entry);
            } else {
                if (currentIndex !== index)
                    chipModel.move(currentIndex, index, 1);

                chipModel.setProperty(index, "componentId", entry.componentId);
                chipModel.setProperty(index, "placeholder", entry.placeholder);
            }
        }
    }

    function synchronizeValues() {
        if (root.dragActive)
            return ;

        const entries = [];
        const source = Array.isArray(root.values) ? root.values : [];
        for (let index = 0; index < source.length; index += 1) {
            entries.push({
                "entryKey": source[index],
                "componentId": source[index],
                "placeholder": false
            });
        }
        root.synchronizeEntries(entries);
    }

    function showDropPreview(componentId, sourceZone, targetZone, targetIndex) {
        const source = Array.isArray(root.values) ? root.values : [];
        const entries = [];
        for (let index = 0; index < source.length; index += 1) {
            const value = source[index];
            const isDraggedComponent = value === componentId;
            const movingWithinThisZone = root.zone === sourceZone && root.zone === targetZone;
            if (isDraggedComponent && movingWithinThisZone)
                continue;

            if (isDraggedComponent && root.zone !== sourceZone)
                continue;

            entries.push({
                "entryKey": value,
                "componentId": value,
                "placeholder": false
            });
        }
        if (root.zone === targetZone) {
            const insertionIndex = Math.max(0, Math.min(entries.length, targetIndex));
            entries.splice(insertionIndex, 0, {
                "entryKey": componentId,
                "componentId": componentId,
                "placeholder": true
            });
        }
        root.synchronizeEntries(entries);
    }

    function clearDropPreview() {
        root.synchronizeValues();
        root.autoScrollVelocity = 0;
    }

    function insertionIndexAt(coordinatorItem, sceneX, sceneY) {
        const local = chipList.mapFromItem(coordinatorItem, sceneX, sceneY);
        const contentPosition = local.x + chipList.contentX;
        let insertionIndex = 0;
        for (let index = 0; index < chipModel.count; index += 1) {
            const delegateItem = chipList.itemAtIndex(index);
            if (!delegateItem || delegateItem.placeholder || delegateItem.isDragged)
                continue;

            if (contentPosition < delegateItem.x + delegateItem.width / 2)
                return insertionIndex;

            insertionIndex += 1;
        }
        return insertionIndex;
    }

    function containsScenePoint(coordinatorItem, sceneX, sceneY) {
        const local = root.mapFromItem(coordinatorItem, sceneX, sceneY);
        return local.x >= 0 && local.x <= root.width && local.y >= 0 && local.y <= root.height;
    }

    function updateAutoScroll(coordinatorItem, sceneX) {
        const local = chipViewport.mapFromItem(coordinatorItem, sceneX, 0);
        const edgeSize = 44;
        if (local.x < edgeSize && chipList.contentX > 0)
            root.autoScrollVelocity = -Math.min(8, (edgeSize - local.x) / edgeSize * 8);
        else if (local.x > chipViewport.width - edgeSize && chipList.contentX < root.maxContentX())
            root.autoScrollVelocity = Math.min(8, (local.x - chipViewport.width + edgeSize) / edgeSize * 8);
        else
            root.autoScrollVelocity = 0;
    }

    function stepAutoScroll() {
        if (root.autoScrollVelocity === 0)
            return ;

        chipList.contentX = root.clampContentX(chipList.contentX + root.autoScrollVelocity);
        root.scrollTargetX = chipList.contentX;
    }

    function maxContentX() {
        return Math.max(0, chipList.contentWidth - chipList.width);
    }

    function clampContentX(value) {
        return Math.max(0, Math.min(value, root.maxContentX()));
    }

    function handleWheel(wheelEvent) {
        const pixelX = Number(wheelEvent.pixelDelta.x);
        const pixelY = Number(wheelEvent.pixelDelta.y);
        const angleX = Number(wheelEvent.angleDelta.x);
        const angleY = Number(wheelEvent.angleDelta.y);
        let delta = 0;
        if (isFinite(pixelX) && pixelX !== 0)
            delta = -pixelX;
        else if (isFinite(pixelY) && pixelY !== 0)
            delta = -pixelY;
        else if (isFinite(angleX) && angleX !== 0)
            delta = -angleX;
        else if (isFinite(angleY) && angleY !== 0)
            delta = -angleY;
        if (delta === 0)
            return ;

        const base = scrollAnimation.running ? root.scrollTargetX : chipList.contentX;
        root.scrollTargetX = root.clampContentX(base + delta);
        chipList.contentX = root.scrollTargetX;
        wheelEvent.accepted = true;
    }

    function updatePopupGeometry() {
        if (!root.popupParentItem)
            return false;

        const bounds = root.popupBoundsItem || root.popupParentItem;
        const origin = bounds.mapToItem(root.popupParentItem, 0, 0);
        const margin = 12;
        const left = origin.x + margin;
        const top = origin.y + margin;
        const right = origin.x + bounds.width - margin;
        const bottom = origin.y + bounds.height - margin;
        optionsPopup.width = Math.min(root.width, right - left);
        optionsPopup.height = Math.min(root.listTargetHeight + root.menuPadding * 2, bottom - top);
        const below = root.mapToItem(root.popupParentItem, 0, root.height + root.menuGap);
        const above = root.mapToItem(root.popupParentItem, 0, -optionsPopup.height - root.menuGap);
        optionsPopup.x = Math.max(left, Math.min(below.x, right - optionsPopup.width));
        optionsPopup.y = below.y + optionsPopup.height <= bottom ? below.y : above.y >= top ? above.y : Math.max(top, bottom - optionsPopup.height);
        return true;
    }

    function openMenu() {
        if (!root.expanded && root.updatePopupGeometry()) {
            root.highlightedIndex = 0;
            root.expanded = true;
        }
    }

    function closeMenu() {
        root.expanded = false;
    }

    function toggleMenu() {
        if (root.expanded)
            root.closeMenu();
        else
            root.openMenu();
    }

    function moveHighlight(delta) {
        if (root.options.length === 0)
            return ;

        root.highlightedIndex = (root.highlightedIndex + delta + root.options.length) % root.options.length;
        menuList.positionViewAtIndex(root.highlightedIndex, ListView.Contain);
    }

    function toggleHighlighted() {
        if (root.highlightedIndex < 0 || root.highlightedIndex >= root.options.length)
            return ;

        root.toggled(root.optionValue(root.options[root.highlightedIndex]));
    }

    function handleKey(event) {
        if (!root.expanded) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                root.openMenu();
                event.accepted = true;
            }
            return ;
        }
        if (event.key === Qt.Key_Escape)
            root.closeMenu();
        else if (event.key === Qt.Key_Down)
            root.moveHighlight(1);
        else if (event.key === Qt.Key_Up)
            root.moveHighlight(-1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
            root.toggleHighlighted();
        else
            return ;
        event.accepted = true;
    }

    implicitWidth: 360
    implicitHeight: fieldHeight
    activeFocusOnTab: true
    onValuesChanged: synchronizeValues()
    Component.onCompleted: synchronizeValues()
    Keys.onPressed: (event) => {
        return root.handleKey(event);
    }
    onExpandedChanged: {
        if (expanded) {
            updatePopupGeometry();
            optionsPopup.open();
        } else if (optionsPopup.visible) {
            optionsPopup.close();
        }
    }

    Rectangle {
        id: fieldFrame

        anchors.fill: parent
        clip: true
        color: root.expanded || fieldTap.pressed ? Appearance.colors.colLayer2Active : fieldHover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

        Item {
            id: chipViewport

            clip: true

            anchors {
                left: parent.left
                right: arrowIcon.left
                top: parent.top
                bottom: parent.bottom
                leftMargin: 8
                rightMargin: 8
            }

            ListView {
                id: chipList

                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: 6
                model: chipModel
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: false

                Behavior on contentX {
                    enabled: !root.dragActive

                    NumberAnimation {
                        id: scrollAnimation

                        alwaysRunToEnd: false
                        duration: Appearance.animation.scroll.duration
                        easing.type: Appearance.animation.scroll.type
                        easing.bezierCurve: Appearance.animation.scroll.bezierCurve
                    }

                }

                delegate: Item {
                    id: chipDelegate

                    required property string entryKey
                    required property string componentId
                    required property bool placeholder
                    readonly property bool ownsActiveDrag: root.dragActive && root.dragCoordinator && root.dragCoordinator.componentId === chipDelegate.componentId && root.dragCoordinator.sourceZone === root.zone
                    readonly property bool isDragged: root.dragActive && root.dragCoordinator.componentId === componentId && !placeholder
                    readonly property real naturalWidth: Math.max(72, chipLabel.implicitWidth + 48)

                    width: placeholder && root.dragCoordinator ? root.dragCoordinator.dragWidth : isDragged ? 0 : naturalWidth
                    height: chipList.height
                    opacity: isDragged ? 0 : 1

                    Rectangle {
                        id: chipSurface

                        width: chipDelegate.placeholder ? parent.width : chipDelegate.naturalWidth
                        height: 30
                        anchors.centerIn: parent
                        radius: Appearance.rounding.small
                        color: chipDelegate.placeholder ? Appearance.colors.colLayer2Active : chipHover.hovered ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer
                        opacity: chipDelegate.placeholder ? 0.45 : 1

                        Text {
                            id: chipLabel

                            text: root.labelFor(chipDelegate.componentId)
                            color: Appearance.colors.colOnPrimaryContainer
                            font.family: Fonts.ui
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            visible: !chipDelegate.placeholder
                            elide: Text.ElideRight

                            anchors {
                                left: parent.left
                                right: closeButton.left
                                leftMargin: 12
                                rightMargin: 4
                                verticalCenter: parent.verticalCenter
                            }

                        }

                        Item {
                            id: closeButton

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            visible: !chipDelegate.placeholder

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 17
                                color: Appearance.colors.colOnPrimaryContainer
                            }

                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    mouse.accepted = true;
                                    root.removed(chipDelegate.componentId);
                                }
                            }

                        }

                        HoverHandler {
                            id: chipHover
                        }

                        MouseArea {
                            enabled: !chipDelegate.placeholder
                            cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onClicked: (mouse) => {
                                return mouse.accepted = true;
                            }

                            anchors {
                                left: parent.left
                                right: closeButton.left
                                top: parent.top
                                bottom: parent.bottom
                            }

                        }

                        DragHandler {
                            id: dragHandler

                            enabled: root.dragCoordinator !== null && (!chipDelegate.placeholder || chipDelegate.ownsActiveDrag) && (!closeMouse.containsMouse || chipDelegate.ownsActiveDrag)
                            target: null
                            dragThreshold: 8
                            onActiveChanged: {
                                if (active)
                                    root.dragCoordinator.beginDrag(root, chipDelegate.componentId, root.labelFor(chipDelegate.componentId), chipDelegate.naturalWidth, centroid.scenePosition);
                                else if (root.dragCoordinator && root.dragCoordinator.dragActive && root.dragCoordinator.componentId === chipDelegate.componentId)
                                    root.dragCoordinator.finishDrag();
                            }
                            onTranslationChanged: {
                                if (active)
                                    root.dragCoordinator.updateDrag(centroid.scenePosition);

                            }
                        }

                    }

                }

                move: Transition {
                    ElementMoveAnimation {
                        property: "x"
                    }

                }

                moveDisplaced: Transition {
                    ElementMoveAnimation {
                        property: "x"
                    }

                }

                addDisplaced: Transition {
                    ElementMoveAnimation {
                        property: "x"
                    }

                }

                removeDisplaced: Transition {
                    ElementMoveAnimation {
                        property: "x"
                    }

                }

            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheelEvent) => {
                    return root.handleWheel(wheelEvent);
                }
            }

        }

        Text {
            visible: chipModel.count === 0
            text: qsTr("未选择组件")
            color: Appearance.colors.colSubtext
            font.family: Fonts.ui
            font.pixelSize: 14

            anchors {
                left: parent.left
                right: arrowIcon.left
                leftMargin: 14
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }

        }

        MaterialSymbol {
            id: arrowIcon

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "expand_more"
            iconSize: 20
            color: Appearance.colors.colOnLayer2
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastSpatial.duration
                    easing.type: Appearance.animation.expressiveFastSpatial.type
                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                }

            }

        }

        TapHandler {
            id: fieldTap

            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                root.forceActiveFocus();
                root.toggleMenu();
            }
        }

        HoverHandler {
            id: fieldHover
        }

        Rectangle {
            height: root.expanded ? 2 : 1
            color: root.expanded ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }

        }

    }

    ListModel {
        id: chipModel
    }

    Popup {
        id: optionsPopup

        property real revealProgress: 0

        parent: root.popupParentItem
        padding: 0
        modal: true
        dim: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAboutToShow: {
            revealProgress = 0;
            Qt.callLater(() => {
                return revealProgress = 1;
            });
        }
        onAboutToHide: revealProgress = 0
        onOpened: Qt.callLater(() => {
            return menuContent.forceActiveFocus();
        })
        onClosed: root.expanded = false

        background: Item {
        }

        contentItem: FocusScope {
            id: menuContent

            focus: optionsPopup.visible
            Keys.onPressed: (event) => {
                return root.handleKey(event);
            }

            Item {
                id: maskedSurface

                width: parent.width
                height: parent.height * optionsPopup.revealProgress
                clip: true
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainerHigh
                }

                StyledListView {
                    id: menuList

                    x: root.menuPadding
                    y: root.menuPadding
                    width: parent.width - root.menuPadding * 2
                    height: optionsPopup.height - root.menuPadding * 2
                    model: root.options
                    spacing: root.menuItemSpacing
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: root.highlightedIndex
                    animateAppearance: false
                    animateMovement: false

                    delegate: Item {
                        id: optionItem

                        required property var modelData
                        required property int index
                        readonly property string componentId: root.optionValue(modelData)
                        readonly property bool selected: root.values.indexOf(componentId) !== -1

                        width: ListView.view.width
                        height: root.itemHeight

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: optionItem.selected ? Appearance.colors.colPrimaryContainer : optionItem.index === root.highlightedIndex ? Appearance.m3colors.m3surfaceContainerHighest : Appearance.m3colors.m3surfaceContainerHigh
                        }

                        Item {
                            id: checkSlot

                            anchors.left: parent.left
                            width: 38
                            height: parent.height
                            scale: optionItem.selected ? 1 : 0

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 19
                                fill: 1
                                color: Appearance.colors.colOnPrimaryContainer
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Appearance.animation.clickBounce.duration
                                    easing.type: Appearance.animation.clickBounce.type
                                    easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
                                }

                            }

                        }

                        Text {
                            text: root.optionLabel(optionItem.modelData)
                            color: optionItem.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
                            font.family: Fonts.ui
                            font.pixelSize: 14
                            font.weight: optionItem.selected ? Font.Medium : Font.Normal
                            elide: Text.ElideRight

                            anchors {
                                left: checkSlot.right
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: 12
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.highlightedIndex = optionItem.index
                            onClicked: root.toggled(optionItem.componentId)
                        }

                    }

                }

                layer.effect: OpacityMask {

                    maskSource: Rectangle {
                        width: maskedSurface.width
                        height: maskedSurface.height
                        radius: Appearance.rounding.normal
                    }

                }

            }

        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.animation.standardDecel.duration
                easing.type: Appearance.animation.standardDecel.type
                easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
            }

        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }

        }

        Behavior on revealProgress {
            NumberAnimation {
                duration: Appearance.animation.standardDecel.duration
                easing.type: Appearance.animation.standardDecel.type
                easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
            }

        }

    }

}
