import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Services

// Session menu behind the header power button. Leading icons are
// color-coded by consequence so the options scan apart.
MD.Menu {
    id: root

    // The panel closes before the session action runs.
    signal panelCloseRequested

    // One level above the panel so the popup reads as elevated over it.
    mdState.backgroundColor: MD.Token.color.surface_container_high
    mdState.elevation: MD.Token.elevation.level3

    MD.MenuItem {
        text: I18n.t("quickSettings.lock")
        icon.name: "lock"
        font.family: Theme.textTypeface
        leadingIconColor: MD.Token.color.on_surface_variant

        onTriggered: {
            root.panelCloseRequested();
            Session.lock();
        }
    }

    MD.MenuItem {
        text: I18n.t("quickSettings.session.suspend")
        icon.name: "mode_standby"
        font.family: Theme.textTypeface
        leadingIconColor: MD.Token.color.tertiary

        onTriggered: {
            root.panelCloseRequested();
            Session.suspend();
        }
    }

    MD.MenuItem {
        text: I18n.t("quickSettings.session.restart")
        icon.name: "restart_alt"
        font.family: Theme.textTypeface
        leadingIconColor: MD.Token.color.primary

        onTriggered: {
            root.panelCloseRequested();
            Session.reboot();
        }
    }

    MD.MenuItem {
        text: I18n.t("quickSettings.session.powerOff")
        icon.name: "power_settings_new"
        font.family: Theme.textTypeface
        leadingIconColor: MD.Token.color.error

        onTriggered: {
            root.panelCloseRequested();
            Session.powerOff();
        }
    }

    MD.MenuItem {
        text: I18n.t("quickSettings.session.logOut")
        icon.name: "logout"
        font.family: Theme.textTypeface
        leadingIconColor: MD.Token.color.secondary

        onTriggered: {
            root.panelCloseRequested();
            Session.logOut();
        }
    }
}
