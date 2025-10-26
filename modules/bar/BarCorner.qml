import QtQuick 2.15
import QtQuick.Shapes 1.15

Item {
    id: root
    // color: "transparent"

    enum CornerEnum {
        TopLeft,
        TopRight,
        BottomLeft,
        BottomRight
    }

    // Default to TopLeft. Use the local enum.
    // property int corner: BarCorner.CornerEnum.TopLeft
    required property int corner
    required property color color
    required property int implicitSize

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    // --- Helper Booleans (Bindings simplified) ---
    property bool isTopLeft: corner === BarCorner.CornerEnum.TopLeft
    property bool isBottomLeft: corner === BarCorner.CornerEnum.BottomLeft
    property bool isTopRight: corner === BarCorner.CornerEnum.TopRight
    property bool isBottomRight: corner === BarCorner.CornerEnum.BottomRight

    property bool isTop: isTopLeft || isTopRight
    property bool isBottom: isBottomLeft || isBottomRight
    property bool isLeft: isTopLeft || isBottomLeft
    property bool isRight: isTopRight || isBottomRight

    // --- Shape Definition ---
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true

        ShapePath {
            id: shapePath
            strokeWidth: 0
            fillColor: root.color

            // The "point" of the corner.
            // (0,0) for TopLeft, (width,0) for TopRight, etc.
            startX: root.isLeft ? 0 : root.width
            startY: root.isTop ? 0 : root.height

            // 1. Line to the start of the arc
            // For TopLeft: moves from (0,0) to (0, height)
            PathLine {
                x: root.isLeft ? 0 : root.width
                y: root.isTop ? root.height : 0
            }

            // 2. The arc itself
            // For TopLeft: draws an arc from (0, height) to (width, 0)
            PathArc {
                x: root.isLeft ? root.width : 0
                y: root.isTop ? 0 : root.height
                radiusX: root.width
                radiusY: root.height
                direction: (root.isTopLeft || root.isBottomRight) ? PathArc.Clockwise : PathArc.Counterclockwise
            }

            // 3. Close the path
            // For TopLeft: draws a line from (width, 0) back to (0,0)
            PathLine {
                x: shapePath.startX
                y: shapePath.startY
            }
        }
    }
}
