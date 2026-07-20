import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n

// M3 outlined text field for the network forms (prototype .tf): compact
// panel metrics, an optional trailing visibility eye for secrets, an error
// tint, and the failed-submit shake.
Item {
    id: control

    property alias text: field.text
    property alias placeholderText: field.placeholderText
    // Secret entry: masked with a trailing visibility toggle.
    property bool secret: false
    property bool reveal: false
    property bool error: false

    signal accepted
    signal edited

    // The floating label rides the outline's top edge, poking above the
    // field's own box; reserve that band so a clipped parent (the expando
    // body) doesn't shave the label (prototype's `.tf` margin-top).
    readonly property real topReserve: 9

    function shake() {
        shakeAnim.restart();
    }

    // Defer to the next tick rather than focusing synchronously. When a body
    // Loader auto-focuses this field from its Component.onCompleted, the
    // expando body is still clipped to zero height and hasn't rendered a
    // frame; the MD.TextField's floating label animates its rise with
    // render-thread Animators, which can't run on an unrealized item, so the
    // animation's wall-clock elapses invisibly and the label snaps to the top
    // instead of gliding. One tick lets the field realize first so the float
    // animates smoothly.
    function forceFocus() {
        Qt.callLater(field.forceActiveFocus);
    }

    width: parent ? parent.width : 0
    implicitHeight: field.implicitHeight + topReserve

    transform: Translate {
        id: shakeTx
    }

    // Prototype shakeX keyframes (.45s): -6 / +5 / -3 / +2 / 0.
    SequentialAnimation {
        id: shakeAnim

        NumberAnimation {
            target: shakeTx
            property: "x"
            to: -6
            duration: 90
        }

        NumberAnimation {
            target: shakeTx
            property: "x"
            to: 5
            duration: 112
        }

        NumberAnimation {
            target: shakeTx
            property: "x"
            to: -3
            duration: 112
        }

        NumberAnimation {
            target: shakeTx
            property: "x"
            to: 2
            duration: 81
        }

        NumberAnimation {
            target: shakeTx
            property: "x"
            to: 0
            duration: 55
        }
    }

    MD.TextField {
        id: field

        // Compact 56dp field for the panel (outlined default is 64dp), with
        // the prototype's 14px body text rather than the 16px default.
        mdState.dense: true
        typescale: MD.Token.typescale.body_medium
        width: parent.width
        y: control.topReserve
        echoMode: control.secret && !control.reveal ? TextInput.Password : TextInput.Normal

        onTextEdited: control.edited()
        onAccepted: control.accepted()

        // Failed-submit tint (prototype .tf.err): the field has no external
        // error switch — its own error state keys off validators — so drive
        // the state colors directly.
        Binding {
            target: field.mdState
            property: "outlineColor"
            value: MD.Token.color.error
            when: control.error
        }

        Binding {
            target: field.mdState
            property: "placeholderColor"
            value: MD.Token.color.error
            when: control.error
        }

        // Prototype .tf-eye visibility toggle.
        trailing: MD.IconButton {
            id: eyeBtn

            anchors.right: parent ? parent.right : undefined
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.rightMargin: 4
            visible: control.secret
            mdState.type: MD.Enum.IBtStandard
            mdState.size: MD.Enum.XS
            icon.name: control.reveal ? "visibility_off" : "visibility"
            icon.width: 19
            icon.height: 19

            // Stock IconButton only fills its glyph while checked; the
            // prototype's eye is always the filled variant.
            contentItem: Item {
                implicitWidth: 19
                implicitHeight: 19
                opacity: eyeBtn.mdState.contentOpacity

                MD.Icon {
                    anchors.centerIn: parent
                    name: eyeBtn.icon.name
                    size: 19
                    fill: true
                    color: eyeBtn.mdState.textColor
                }
            }

            onClicked: {
                control.reveal = !control.reveal;
                field.forceActiveFocus();
            }
        }
    }
}
