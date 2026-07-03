#!/usr/bin/env python3
"""Minimal StatusNotifierItem for tray e2e tests.

Registers one tray item on the session bus and prints a line for every
interaction so tests can assert the full quickshell -> dbus -> app path:

    [FakeTray <id>] Registered
    [FakeTray <id>] Activate 10,20
    [FakeTray <id>] SecondaryActivate 10,20
    [FakeTray <id>] ContextMenu 10,20
    [FakeTray <id>] Scroll 120 vertical
    [FakeTray <id>] MenuEvent 1 clicked

Usage: fake_tray_app.py --id myapp --title "My App" [--icon folder] [--menu]
"""

from __future__ import annotations

import argparse
import os
import sys

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

SNI_IFACE = "org.kde.StatusNotifierItem"
MENU_IFACE = "com.canonical.dbusmenu"
WATCHER_NAME = "org.kde.StatusNotifierWatcher"
ITEM_PATH = "/StatusNotifierItem"
MENU_PATH = "/TrayMenu"


def log(item_id: str, message: str) -> None:
    print(f"[FakeTray {item_id}] {message}", flush=True)


class TrayMenu(dbus.service.Object):
    """Minimal com.canonical.dbusmenu: root + two entries (Ping, Quit)."""

    def __init__(self, bus: dbus.SessionBus, item_id: str, loop: GLib.MainLoop):
        super().__init__(bus, MENU_PATH)
        self.item_id = item_id
        self.loop = loop

    def _entry(self, entry_id: int, label: str):
        props = dbus.Dictionary({"label": label, "enabled": True, "visible": True}, signature="sv")
        return dbus.Struct(
            (dbus.Int32(entry_id), props, dbus.Array([], signature="v")),
            signature="ia{sv}av",
        )

    @dbus.service.method(MENU_IFACE, in_signature="iias", out_signature="u(ia{sv}av)")
    def GetLayout(self, parent_id, recursion_depth, property_names):
        log(self.item_id, f"MenuGetLayout {int(parent_id)}")
        children = dbus.Array([], signature="v")
        if parent_id == 0:
            children = dbus.Array(
                [self._entry(1, "Ping"), self._entry(2, "Quit")], signature="v"
            )
        root_props = dbus.Dictionary({"children-display": "submenu"}, signature="sv")
        root = dbus.Struct((dbus.Int32(0), root_props, children), signature="ia{sv}av")
        return dbus.UInt32(1), root

    @dbus.service.method(MENU_IFACE, in_signature="aias", out_signature="a(ia{sv})")
    def GetGroupProperties(self, ids, property_names):
        entries = {
            1: {"label": "Ping", "enabled": True, "visible": True},
            2: {"label": "Quit", "enabled": True, "visible": True},
        }
        result = []
        for entry_id in ids:
            props = entries.get(int(entry_id))
            if props is not None:
                result.append(
                    (dbus.Int32(entry_id), dbus.Dictionary(props, signature="sv"))
                )
        return result

    @dbus.service.method(MENU_IFACE, in_signature="isvu")
    def Event(self, entry_id, event_id, data, timestamp):
        log(self.item_id, f"MenuEvent {int(entry_id)} {event_id}")
        if int(entry_id) == 2 and event_id == "clicked":
            GLib.idle_add(self.loop.quit)

    @dbus.service.method(MENU_IFACE, in_signature="i", out_signature="b")
    def AboutToShow(self, entry_id):
        return False

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        return self.GetAll(interface).get(prop, dbus.UInt32(0))

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return dbus.Dictionary(
            {
                "Version": dbus.UInt32(3),
                "Status": "normal",
                "TextDirection": "ltr",
                "IconThemePath": dbus.Array([], signature="s"),
            },
            signature="sv",
        )


class StatusNotifierItem(dbus.service.Object):
    def __init__(self, bus, item_id: str, title: str, icon: str, icon_path: str, has_menu: bool, loop):
        super().__init__(bus, ITEM_PATH)
        self.bus = bus
        self.item_id = item_id
        self.title = title
        self.icon = icon
        self.icon_path = icon_path
        self.has_menu = has_menu
        self.loop = loop

    @dbus.service.method(SNI_IFACE, in_signature="ii")
    def Activate(self, x, y):
        log(self.item_id, f"Activate {int(x)},{int(y)}")

    @dbus.service.method(SNI_IFACE, in_signature="ii")
    def SecondaryActivate(self, x, y):
        log(self.item_id, f"SecondaryActivate {int(x)},{int(y)}")

    @dbus.service.method(SNI_IFACE, in_signature="ii")
    def ContextMenu(self, x, y):
        log(self.item_id, f"ContextMenu {int(x)},{int(y)}")

    @dbus.service.method(SNI_IFACE, in_signature="is")
    def Scroll(self, delta, orientation):
        log(self.item_id, f"Scroll {int(delta)} {orientation}")

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        return self.GetAll(interface).get(prop, "")

    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        tooltip = dbus.Struct(
            ("", dbus.Array([], signature="(iiay)"), self.title, f"{self.title} fake tray item"),
            signature="sa(iiay)ss",
        )
        return dbus.Dictionary(
            {
                "Category": "ApplicationStatus",
                "Id": self.item_id,
                "Title": self.title,
                "Status": "Active",
                "IconName": self.icon,
                "IconThemePath": self.icon_path,
                "ItemIsMenu": False,
                "Menu": dbus.ObjectPath(MENU_PATH if self.has_menu else "/"),
                "ToolTip": tooltip,
                "WindowId": dbus.Int32(0),
            },
            signature="sv",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True)
    parser.add_argument("--title", default=None)
    parser.add_argument("--icon", default="dialog-information")
    parser.add_argument("--icon-path", default="", help="SNI IconThemePath directory")
    parser.add_argument("--menu", action="store_true")
    args = parser.parse_args()
    title = args.title or args.id

    DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    bus = dbus.SessionBus()

    bus_name = dbus.service.BusName(
        f"org.kde.StatusNotifierItem-{os.getpid()}-1", bus
    )
    StatusNotifierItem(bus, args.id, title, args.icon, args.icon_path, args.menu, loop)
    if args.menu:
        TrayMenu(bus, args.id, loop)

    def register() -> bool:
        try:
            watcher = bus.get_object(WATCHER_NAME, "/StatusNotifierWatcher")
            watcher.RegisterStatusNotifierItem(
                bus_name.get_name(), dbus_interface=WATCHER_NAME
            )
            log(args.id, "Registered")
        except dbus.DBusException as error:
            log(args.id, f"RegisterFailed {error.get_dbus_name()}")
        return False

    def on_owner_changed(name, old, new):
        if name == WATCHER_NAME and new:
            register()

    bus.add_signal_receiver(
        on_owner_changed,
        signal_name="NameOwnerChanged",
        dbus_interface="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
    )
    GLib.idle_add(register)
    loop.run()
    log(args.id, "Exit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
