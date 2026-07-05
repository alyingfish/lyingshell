import QtQuick
import Qcm.Material as MD
import "Motion.js" as Motion

// M3E connected button group, single-select (Compose ButtonGroup / the
// web-prototype power-mode row): segments sit split-button spacing apart
// and read as one unit — stadium outer corners, split-button inner corners.
// The selected segment fills primary, springs its inner corners round,
// grows by `selectedWeight` while its neighbors yield, and emphasizes its
// label. QmlMaterial has no connected-group control, so the plus kit
// carries it. Desktop-compact: 44px XS cells.
Item {
    id: root

    // [{icon, text, value}] — text pre-localized by the caller.
    required property var model
    // Matches a model entry's value; selects nothing when it matches none.
    property var current
    // Grow factor of the selected segment (prototype flex-grow).
    property real selectedWeight: 1.5
    // Label typeface; callers pass Theme.textTypeface.
    property string textTypeface: Qt.application.font.family

    // Radio semantics: emitted only for a not-yet-selected segment.
    signal selected(var value)

    implicitHeight: 44
    implicitWidth: count * implicitHeight * 2 + gap * (count - 1)

    readonly property real gap: MD.Token.split_button.xsmall.between_space
    readonly property real innerCorner: MD.Token.split_button.xsmall.inner_corner_size
    readonly property int count: model.length
    readonly property bool hasCurrent: model.some(entry => entry.value === root.current)
    readonly property real weightSum: count + (hasCurrent ? selectedWeight - 1 : 0)
    readonly property real slotWidth: width - gap * (count - 1)

    Row {
        spacing: root.gap

        Repeater {
            model: root.model

            MD.Button {
                id: segment

                required property var modelData
                required property int index

                readonly property bool isCurrent: modelData.value === root.current

                checkable: false
                implicitHeight: root.implicitHeight
                // Same-duration width springs keep the row sum constant
                // while the selected segment grows and the rest yield.
                width: root.slotWidth * (isCurrent ? root.selectedWeight : 1) / root.weightSum
                Behavior on width {
                    NumberAnimation {
                        duration: Motion.spatialDefault.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.spatialDefault.curve
                    }
                }

                mdState.size: MD.Enum.XS
                mdState.type: isCurrent ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal

                // Selection colors on the effects spring (no overshoot),
                // same pattern as the quick-settings toggles.
                property color animBackground: isCurrent ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_highest
                property color animText: isCurrent ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface
                Behavior on animBackground {
                    ColorAnimation {
                        duration: Motion.effectsDefault.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.effectsDefault.curve
                    }
                }
                Behavior on animText {
                    ColorAnimation {
                        duration: Motion.effectsDefault.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.effectsDefault.curve
                    }
                }
                mdState.backgroundColor: animBackground
                mdState.textColor: animText

                // Outer edges and the selected segment run the stadium
                // corner (mdState.corner also carries the pressed morph);
                // shared edges keep the split-button inner corner. Spatial
                // spring = the bouncy M3E shape morph.
                property real leftCorner: index === 0 || isCurrent ? mdState.corner : root.innerCorner
                property real rightCorner: index === root.count - 1 || isCurrent ? mdState.corner : root.innerCorner
                Behavior on leftCorner {
                    NumberAnimation {
                        duration: Motion.spatialFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.spatialFast.curve
                    }
                }
                Behavior on rightCorner {
                    NumberAnimation {
                        duration: Motion.spatialFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.spatialFast.curve
                    }
                }
                mdState.corners: MD.Util.corners(leftCorner, rightCorner, leftCorner, rightCorner)

                onClicked: if (!isCurrent)
                    root.selected(modelData.value)

                contentItem: MD.IconLabel {
                    opacity: segment.mdState.contentOpacity
                    icon.name: segment.modelData.icon
                    icon.size: MD.Token.button.xsmall.icon_size
                    text: segment.modelData.text
                    color: segment.mdState.textColor
                    label.typescale: MD.Token.typescale.label_medium
                    // M3E emphasized type on the selected segment.
                    label.prominent: segment.isCurrent
                    label.font.family: root.textTypeface
                }
            }
        }
    }
}
