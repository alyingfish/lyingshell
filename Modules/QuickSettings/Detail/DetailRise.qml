import QtQuick
import qs.Material
import "../../../Material/Motion.js" as Motion

// Detail-list entrance (prototype dvIn keyframes): the target drops in from
// -8px and fades up after a 35ms/order stagger. The caller owns a Translate
// in its transform list and restarts this on Component.onCompleted:
//   transform: Translate { id: ty }
//   Component.onCompleted: rise.restart()
//   DetailRise { id: rise; target: row; translate: ty; order: row.order }
SequentialAnimation {
    id: rise

    required property Item target
    // The Translate the caller placed in target.transform.
    required property Translate translate
    // Index in the page's entrance stagger.
    property int order: 0

    running: false

    ScriptAction {
        script: {
            rise.target.opacity = 0;
            rise.translate.y = -8;
        }
    }

    PauseAnimation {
        // order goes to -1 while a delegate tears down; clamp so the
        // stagger never asks for a negative duration.
        duration: Math.max(0, rise.order * 35)
    }

    ParallelAnimation {
        MotionAnimation {
            target: rise.translate
            property: "y"
            to: 0
        }

        MotionAnimation {
            target: rise.target
            property: "opacity"
            to: 1
            spring: Motion.effectsDefault
        }

    }

}
