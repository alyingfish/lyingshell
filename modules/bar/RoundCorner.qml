import QtQuick

Item {
    id: root

    enum CornerEnum {
        TopLeft,
        TopRight,
        BottomLeft,
        BottomRight
    }
    property int corner: RoundCorner.CornerEnum.TopLeft // Default to TopLeft
    property int implicitSize: 15
    required property color color

    onColorChanged: {
        canvas.requestPaint();
    }
    onCornerChanged: {
        canvas.requestPaint();
    }

    implicitHeight: implicitSize
    implicitWidth: implicitSize

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            var r = root.implicitSize;
            ctx.clearRect(0, 0, r, r);
            ctx.beginPath();
            switch (root.corner) {
            case RoundCorner.CornerEnum.TopLeft:
                ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2);
                ctx.lineTo(0, 0);
                break;
            case RoundCorner.CornerEnum.TopRight:
                ctx.arc(0, r, r, 3 * Math.PI / 2, 2 * Math.PI);
                ctx.lineTo(r, 0);
                break;
            case RoundCorner.CornerEnum.BottomLeft:
                ctx.arc(r, 0, r, Math.PI / 2, Math.PI);
                ctx.lineTo(0, r);
                break;
            case RoundCorner.CornerEnum.BottomRight:
                ctx.arc(0, 0, r, 0, Math.PI / 2);
                ctx.lineTo(r, r);
                break;
            }
            ctx.closePath();
            ctx.fillStyle = root.color;
            ctx.fill();
        }
    }
}
