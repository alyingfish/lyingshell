pragma Singleton

import QtQml

// Test stand-in for qs.Commons.I18n under plain qml6. Serves the real
// English bundle (loaded synchronously over XHR) so visual dumps read like
// the product; falls back to the raw token when the bundle or key is
// missing.
QtObject {
    id: root

    readonly property bool isLoaded: true

    property var bundle: null

    Component.onCompleted: {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../../../../../../Commons/I18n/locales/en.json"), false);
        request.send();
        if (request.status === 200 || request.status === 0) {
            try {
                bundle = JSON.parse(request.responseText);
            } catch (error) {
                bundle = null;
            }
        }
    }

    function t(token, values) {
        let node = bundle;
        for (const part of token.split(".")) {
            if (!node || typeof node !== "object") {
                return token;
            }
            node = node[part];
        }
        if (typeof node !== "string") {
            return token;
        }
        return node.replace(/\{(\w+)\}/g, (match, key) => values && key in values ? values[key] : match);
    }
}
