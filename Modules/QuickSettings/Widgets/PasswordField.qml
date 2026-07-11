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

    function shake() {
        shakeAnim.restart();
    }

    function forceFocus() {
        field.forceActiveFocus();
    }

    width: parent ? parent.width : 0
    implicitHeight: field.implicitHeight

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

        // Compact 56dp field for the panel (outlined default is 64dp).
        mdState.dense: true
        width: parent.width
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
            anchors.right: parent ? parent.right : undefined
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.rightMargin: 4
            visible: control.secret
            mdState.type: MD.Enum.IBtStandard
            mdState.size: MD.Enum.XS
            icon.name: control.reveal ? "visibility_off" : "visibility"
            icon.width: 19
            icon.height: 19

            onClicked: {
                control.reveal = !control.reveal;
                field.forceActiveFocus();
            }
        }
    }
}
