import QtQuick

Canvas {
    id: root

    property int sides: 12
    property real innerRadiusRatio: 0.8
    property color color: "transparent"
    property real rotationOffset: 30

    function pointDistance(first, second) {
        const dx = second.x - first.x;
        const dy = second.y - first.y;
        return Math.sqrt(dx * dx + dy * dy);
    }

    function pointToward(origin, target, distance) {
        const length = root.pointDistance(origin, target);
        if (length <= 0)
            return origin;

        const ratio = Math.min(1, distance / length);
        return {
            "x": origin.x + (target.x - origin.x) * ratio,
            "y": origin.y + (target.y - origin.y) * ratio
        };
    }

    function cookieVertices() {
        const count = Math.max(2, Math.round(root.sides));
        const vertices = [];
        const offset = root.rotationOffset * Math.PI / 180;
        const regular = root.innerRadiusRatio >= 0.999;
        const vertexCount = regular ? count : count * 2;
        for (let index = 0; index < vertexCount; ++index) {
            const radius = regular || index % 2 === 0 ? 0.5 : 0.5 * Math.max(0.05, Math.min(1, root.innerRadiusRatio));
            const angle = offset + Math.PI * 2 * index / vertexCount;
            vertices.push({
                "x": 0.5 + radius * Math.cos(angle),
                "y": 0.5 + radius * Math.sin(angle)
            });
        }
        return vertices;
    }

    function roundedPoints(vertices) {
        const result = [];
        const count = vertices.length;
        const radius = (root.sides < 17 ? 1.5 : 1.1) / Math.max(root.sides, 1);
        for (let index = 0; index < count; ++index) {
            const previous = vertices[(index + count - 1) % count];
            const current = vertices[index];
            const next = vertices[(index + 1) % count];
            const cut = Math.min(radius, root.pointDistance(current, previous) * 0.45, root.pointDistance(current, next) * 0.45);
            result.push({
                "corner": current,
                "entry": root.pointToward(current, previous, cut),
                "exit": root.pointToward(current, next, cut)
            });
        }
        return result;
    }

    function paintCircle(context) {
        context.beginPath();
        context.arc(0.5, 0.5, 0.5, 0, Math.PI * 2);
        context.closePath();
        context.fill();
    }

    antialiasing: true
    renderStrategy: Canvas.Cooperative
    onPaint: {
        const context = getContext("2d");
        context.clearRect(0, 0, width, height);
        context.fillStyle = root.color;
        const size = Math.min(width, height);
        context.save();
        context.translate((width - size) / 2, (height - size) / 2);
        context.scale(size, size);
        if (root.sides <= 1) {
            root.paintCircle(context);
        } else {
            const points = root.roundedPoints(root.cookieVertices());
            context.beginPath();
            context.moveTo(points[0].entry.x, points[0].entry.y);
            for (let index = 0; index < points.length; ++index) {
                const point = points[index];
                context.quadraticCurveTo(point.corner.x, point.corner.y, point.exit.x, point.exit.y);
                const next = points[(index + 1) % points.length];
                context.lineTo(next.entry.x, next.entry.y);
            }
            context.closePath();
            context.fill();
        }
        context.restore();
    }
    onSidesChanged: requestPaint()
    onInnerRadiusRatioChanged: requestPaint()
    onColorChanged: requestPaint()
    onRotationOffsetChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
}
