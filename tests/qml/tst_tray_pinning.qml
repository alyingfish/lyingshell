import QtQml
import "../../Modules/Bar/Widgets/TrayPinning.js" as TrayPinning

QtObject {
    id: root

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function verifyEqual(actual, expected, message) {
        if (JSON.stringify(actual) !== JSON.stringify(expected))
            throw new Error(message + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
    }

    function item(id, title) {
        return { "id": id, "title": title || id };
    }

    Component.onCompleted: {
        try {
            const syncthing = item("syncthing", "Syncthing");
            const steam = item("steam", "Steam");
            const nm = item("nm-applet", "Network");
            const items = [steam, syncthing, nm];

            // --- partition ---
            let split = TrayPinning.partition(items, ["syncthing"]);
            verifyEqual(split.pinned.map(i => i.id), ["syncthing"], "default regex pins syncthing");
            verifyEqual(split.overflow.map(i => i.id), ["steam", "nm-applet"], "overflow keeps service order");

            split = TrayPinning.partition(items, ["^nm", "Steam"]);
            verifyEqual(split.pinned.map(i => i.id), ["nm-applet", "steam"], "pinned order follows regex order");
            verify(TrayPinning.regexMatchesItem("network", nm), "title matches case-insensitively");
            verify(!TrayPinning.regexMatchesItem("[", nm), "invalid regex is skipped, not thrown");

            split = TrayPinning.partition(items, []);
            verifyEqual(split.pinned.length, 0, "no regexes pins nothing");

            // --- overflow order ---
            split = TrayPinning.partition(items, ["syncthing"], ["nm-applet", "steam"]);
            verifyEqual(split.overflow.map(i => i.id), ["nm-applet", "steam"], "overflow follows order list");
            split = TrayPinning.partition(items, ["syncthing"], ["nm-applet", "gone"]);
            verifyEqual(split.overflow.map(i => i.id), ["nm-applet", "steam"], "unlisted items trail in service order, stale ids ignored");

            // --- orderAfterDrop ---
            const overflow = [steam, nm];
            verifyEqual(TrayPinning.orderAfterDrop(overflow, nm, 0), ["nm-applet", "steam"], "reorder to head");
            verifyEqual(TrayPinning.orderAfterDrop(overflow, steam, 2), ["nm-applet", "steam"], "reorder past self adjusts index");
            verifyEqual(TrayPinning.orderAfterDrop(overflow, syncthing, 1), ["steam", "syncthing", "nm-applet"], "unpinned item inserts at drop position");

            // --- pinAt ---
            let regexes = TrayPinning.pinAt(["syncthing"], items, steam, 0);
            verifyEqual(regexes, ["^steam$", "syncthing"], "pin at head inserts before neighbor regex");
            verifyEqual(TrayPinning.partition(items, regexes).pinned.map(i => i.id),
                        ["steam", "syncthing"], "pin at head lands at head");

            regexes = TrayPinning.pinAt(["syncthing"], items, steam, 1);
            verifyEqual(regexes, ["syncthing", "^steam$"], "pin at tail appends");

            // Reorder: move syncthing after steam; its old regex is replaced.
            regexes = TrayPinning.pinAt(["syncthing", "^steam$"], items, syncthing, 1);
            verifyEqual(regexes, ["^steam$", "^syncthing$"], "reorder drops old regex and reinserts");

            // --- unpin ---
            verifyEqual(TrayPinning.unpin(["syncthing", "^steam$"], steam), ["syncthing"], "unpin drops matching regex");
            verifyEqual(TrayPinning.unpin(["syncthing"], steam), ["syncthing"], "unpin of unpinned item is a no-op");

            // --- row insertion ---
            // cells: 32 wide, 4 spacing => step 36
            verifyEqual(TrayPinning.rowInsertionIndex(-10, 32, 4, 3), 0, "row: before first cell");
            verifyEqual(TrayPinning.rowInsertionIndex(20, 32, 4, 3), 1, "row: past first cell midpoint");
            verifyEqual(TrayPinning.rowInsertionIndex(500, 32, 4, 3), 3, "row: clamped to count");
            verifyEqual(TrayPinning.rowInsertionIndex(10, 32, 4, 0), 0, "row: empty row");

            // --- grid insertion (4 columns) ---
            verifyEqual(TrayPinning.gridInsertionIndex(0, 0, 32, 32, 4, 4, 6), 0, "grid: top-left");
            verifyEqual(TrayPinning.gridInsertionIndex(70, 0, 32, 32, 4, 4, 6), 2, "grid: mid first row");
            verifyEqual(TrayPinning.gridInsertionIndex(500, 0, 32, 32, 4, 4, 6), 4, "grid: row end clamps to columns");
            verifyEqual(TrayPinning.gridInsertionIndex(20, 40, 32, 32, 4, 4, 6), 5, "grid: second row");
            verifyEqual(TrayPinning.gridInsertionIndex(500, 500, 32, 32, 4, 4, 6), 6, "grid: clamped to count");

            // --- classifyDrag ---
            // Layout: bar strip 0..40; overflow button at x 100..140; pinned
            // row at x 140..212 (2 items, 36 cells); popover card at
            // (300, 48, 152x80) with grid origin (308, 56); 5 overflow items.
            function geo(fromPinned) {
                return {
                    "fromPinned": fromPinned,
                    "barBottom": 40,
                    "button": { "x": 100, "width": 40, "visible": true },
                    "row": { "x": 140, "width": 72 },
                    "pinnedCount": 2,
                    "overflowCount": 5,
                    "card": { "x": 300, "y": 48, "width": 152, "height": 80, "visible": true },
                    "grid": { "x": 308, "y": 56 },
                    "cellWidth": 36,
                    "cellHeight": 36
                };
            }
            let drop = TrayPinning.classifyDrag(150, 20, geo(false));
            verifyEqual(drop.zone, "pinned", "overflow item over pinned row pins");
            verifyEqual(drop.index, 0, "insertion at row head");
            drop = TrayPinning.classifyDrag(211, 20, geo(false));
            verifyEqual(drop.index, 2, "insertion at row tail");
            drop = TrayPinning.classifyDrag(120, 20, geo(false));
            verifyEqual(drop.zone, "blocked", "overflow item over overflow button is blocked");
            drop = TrayPinning.classifyDrag(120, 20, geo(true));
            verifyEqual(drop.zone, "unpinBtn", "pinned item over overflow button unpins");
            drop = TrayPinning.classifyDrag(320, 60, geo(true));
            verifyEqual(drop.zone, "overflow", "pinned item over card unpins");
            verifyEqual(drop.index, 0, "grid insertion at head");
            drop = TrayPinning.classifyDrag(430, 100, geo(true));
            verifyEqual(drop.zone, "overflow", "second grid row hit");
            verifyEqual(drop.index, 5, "grid insertion clamped to count");
            drop = TrayPinning.classifyDrag(320, 60, geo(false));
            verifyEqual(drop.zone, "overflow", "overflow item over card stays in own zone");
            verifyEqual(drop.index, 0, "own-zone drop carries a reorder insertion point");
            drop = TrayPinning.classifyDrag(600, 400, geo(true));
            verifyEqual(drop.zone, "blocked", "empty space blocks");
            drop = TrayPinning.classifyDrag(150, 20, geo(true));
            verifyEqual(drop.zone, "pinned", "pinned item over pinned row reorders");

            console.log("tst_tray_pinning: all assertions passed");
            Qt.exit(0);
        } catch (error) {
            console.log("tst_tray_pinning: failed: " + error);
            Qt.exit(1);
        }
    }
}
