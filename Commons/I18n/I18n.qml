pragma Singleton

import Quickshell
import Quickshell.Io
import qs.Commons.Settings

Singleton {
    id: root

    property bool isLoaded: false
    property int version: 0 // Invalidate I18n.t() bindings when translations change.
    property bool usingFallback: false
    property var translations: ({})
    property var fallbackTranslations: ({})

    readonly property string fallbackLocale: "en"
    readonly property string locale: normalizeLocale(Settings.language)
    readonly property bool needsFallbackFile: Settings.isLoaded && locale !== fallbackLocale

    FileView {
        id: activeLocaleFile

        path: Settings.isLoaded ? root.localePath(root.locale) : ""
        blockLoading: true
        printErrors: false
        watchChanges: true

        onLoaded: root.loadActiveTranslations()
        onFileChanged: reload()
        onLoadFailed: root.publishTranslations(root.fallbackTranslations, true)
    }

    FileView {
        id: fallbackLocaleFile

        path: root.needsFallbackFile ? root.localePath(root.fallbackLocale) : ""
        blockLoading: true
        printErrors: false
        watchChanges: root.needsFallbackFile

        onLoaded: root.loadFallbackTranslations()
        onFileChanged: reload()
        onLoadFailed: {
            root.fallbackTranslations = ({});
            if (root.usingFallback) {
                root.publishTranslations(root.fallbackTranslations, true);
                return;
            }

            version += 1;
        }
    }

    function loadActiveTranslations() {
        var parsed = parseTranslations(activeLocaleFile);
        if (parsed === undefined) {
            publishTranslations(fallbackTranslations, true);
            return;
        }

        if (locale === fallbackLocale) {
            fallbackTranslations = parsed;
        }

        publishTranslations(parsed, false);
    }

    function loadFallbackTranslations() {
        var parsed = parseTranslations(fallbackLocaleFile);
        fallbackTranslations = parsed === undefined ? ({}) : parsed;

        if (usingFallback) {
            publishTranslations(fallbackTranslations, true);
            return;
        }

        version += 1;
    }

    function publishTranslations(nextTranslations, nextUsingFallback) {
        translations = nextTranslations;
        usingFallback = nextUsingFallback;
        isLoaded = true;
        version += 1;
    }

    function t(token, values) {
        // Plain JS token maps are not enough to invalidate all QML bindings.
        root.version;

        var value = resolveToken(translations, token);
        if (value === undefined && translations !== fallbackTranslations) {
            value = resolveToken(fallbackTranslations, token);
        }

        if (typeof value !== "string") {
            return "[" + token + "]";
        }

        return values ? interpolate(value, values) : value;
    }

    function normalizeLocale(value) {
        if (typeof value !== "string" || value.length === 0) {
            return fallbackLocale;
        }

        if (value === "en" || value === "zh-CN") {
            return value;
        }

        if (value.indexOf("zh") === 0) {
            return "zh-CN";
        }

        return fallbackLocale;
    }

    function localePath(localeName) {
        return Quickshell.shellDir + "/Commons/I18n/locales/" + localeName + ".json";
    }

    function parseTranslations(file) {
        try {
            return JSON.parse(file.text());
        } catch (error) {
            return undefined;
        }
    }

    function resolveToken(bundle, token) {
        if (!bundle || typeof bundle !== "object") {
            return undefined;
        }

        var parts = token.split(".");
        var current = bundle;
        for (var index = 0; index < parts.length; index++) {
            if (!current || typeof current !== "object" || current[parts[index]] === undefined) {
                return undefined;
            }

            current = current[parts[index]];
        }

        return current;
    }

    function interpolate(value, values) {
        var result = value;
        for (var key in values) {
            result = result.split("{" + key + "}").join(String(values[key]));
        }

        return result;
    }
}
