import QtQuick

// The refusal shake: a damped horizontal wobble that says "no" without moving
// the thing it is attached to anywhere. Four stops over 420ms, each a fraction
// of `unit` — the caller's own layout unit, so the gesture keeps its
// proportions on any screen.
//
// Callers animate a plain offset property and add it to their x, rather than x
// itself, so a shake can never fight a layout binding.
//
// Motion this shape is exactly what a vestibular reader means by "no": the
// caller is expected to gate `running` on the reduced-motion setting. The
// refusal is still carried by the field's edge and the error chip.
SequentialAnimation {
    id: root

    // The item carrying the offset property, and the property's name.
    property Item item
    property string offsetProperty: "shakeOffset"
    property real unit: 1

    readonly property real segment: 420 / 5

    component Step: NumberAnimation {
        target: root.item
        property: root.offsetProperty
        duration: root.segment
        easing.type: Easing.InOutQuad
    }

    Step {
        to: -1.0 * root.unit
    }
    Step {
        to: 0.75 * root.unit
    }
    Step {
        to: -0.45 * root.unit
    }
    Step {
        to: 0.22 * root.unit
    }
    Step {
        to: 0
    }
}
