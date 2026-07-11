import QtQuick
import Qcm.Material as MD
import qs.Material

// Prototype .swt mini switch (34x20 track, 10px outline thumb growing to a
// 15px filled one, springs on travel and size). Display state is caller-owned:
// bind `checked` via `checkedState` and flip the service in onToggled.
MD.Switch {
    id: control

    // The service-owned state this switch reflects.
    property bool checkedState: false

    // Re-assert caller-owned state after a user toggle wrote `checked`.
    Binding {
        target: control
        property: "checked"
        value: control.checkedState
    }

    indicator: Rectangle {
        id: track

        width: 34
        height: 20
        radius: 10
        y: (control.height - height) / 2
        color: control.checked ? MD.Token.color.primary : MD.Token.color.surface_container_highest
        border.width: 2
        border.color: control.checked ? MD.Token.color.primary : MD.Token.color.outline

        Behavior on color {
            MotionColorAnimation {}
        }

        Behavior on border.color {
            MotionColorAnimation {}
        }

        Rectangle {
            readonly property real thumbSize: control.checked ? 15 : control.pressed ? 13 : 10

            x: control.checked ? track.width - width - 2.5 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: thumbSize
            height: thumbSize
            radius: thumbSize / 2
            color: control.checked ? MD.Token.color.on_primary : MD.Token.color.outline

            Behavior on x {
                MotionAnimation {}
            }

            Behavior on width {
                MotionAnimation {}
            }

            Behavior on color {
                MotionColorAnimation {}
            }
        }
    }
}
