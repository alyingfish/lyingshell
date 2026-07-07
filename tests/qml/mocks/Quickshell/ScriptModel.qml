import QtQml
import QtQml.Models

// Test stand-in for Quickshell.ScriptModel under plain qml6. The real type
// diffs `values` by identity and emits granular insert/move/remove so a
// Repeater reuses delegates; mirror that here (reconcile in place instead of
// clear()+append()) so tests can assert delegate reuse across a re-sort.
ListModel {
    id: root

    property string objectProp: ""
    property var values: []

    dynamicRoles: true

    onValuesChanged: sync()
    Component.onCompleted: sync()

    function _key(v) {
        return objectProp && v && v[objectProp] !== undefined ? v[objectProp] : v;
    }

    function _indexOfKey(k, from) {
        for (var i = from; i < count; i++) {
            if (_key(get(i).modelData) === k) {
                return i;
            }
        }
        return -1;
    }

    function sync() {
        // Drop rows whose value is no longer present.
        for (var i = count - 1; i >= 0; i--) {
            var still = false;
            for (var j = 0; j < values.length; j++) {
                if (_key(get(i).modelData) === _key(values[j])) {
                    still = true;
                    break;
                }
            }
            if (!still) {
                remove(i);
            }
        }
        // Insert new rows and move survivors into the target order.
        for (var t = 0; t < values.length; t++) {
            var cur = _indexOfKey(_key(values[t]), t);
            if (cur === -1) {
                insert(t, { "modelData": values[t] });
            } else if (cur !== t) {
                move(cur, t, 1);
            }
        }
    }
}
