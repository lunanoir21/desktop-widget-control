import QtQuick
import Quickshell
import Quickshell.Io
import "js/Themes.js" as Themes
import "js/Modules.js" as Modules

// The whole module: drop one `DwcHost {}` into a Quickshell root (Main.qml
// does exactly that) and the widgets appear. It creates
//   - a desktop layer on every screen (DwcLayer), always,
//   - the editor on every screen (DwcEditor), only while editing,
// and answers the IPC calls that open the editor and change the layout:
//
//     qs -c desktop-widget-control ipc call desktopWidgets toggle
Scope {
    id: host

    Binding {
        target: DwcStore
        property: "primaryScreen"
        value: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    Variants {
        model: Quickshell.screens
        delegate: DwcLayer {
            required property var modelData
            screen: modelData
        }
    }

    Loader {
        active: DwcStore.editing
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: DwcEditor {
                required property var modelData
                screen: modelData
            }
        }
    }

    Loader {
        active: DwcStore.tourOpen
        sourceComponent: DwcOnboarding {
            screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        }
    }

    IpcHandler {
        target: "desktopWidgets"

        // Show the first-run tour again (from step `n`, 0 is the first).
        function tour(n: int): void {
            DwcStore.openTour(n);
        }

        // Open the editor.
        function edit(): void {
            DwcStore.selected = "";
            DwcStore.editing = true;
        }

        // Close the editor.
        function done(): void {
            DwcStore.editing = false;
            DwcStore.finishTour();
        }

        // Open it if it is closed, close it if it is open. Bind this to a key.
        function toggle(): void {
            if (!DwcStore.editing)
                DwcStore.selected = "";
            DwcStore.editing = !DwcStore.editing;
        }

        // Add a widget (`size` may be empty for the module's default); prints its id, or nothing when there is no room.
        function add(type: string, size: string): string {
            if (!Modules.byType(type))
                return "unknown module (try: dwc modules)";
            var id = DwcStore.add(type, size, 2, 2, DwcStore.primaryScreen);
            return id !== "" ? id : "no room left on the screen";
        }

        function remove(id: string): void {
            DwcStore.remove(id);
        }

        // Select a widget in the editor (empty string deselects).
        function select(id: string): void {
            DwcStore.select(id);
        }

        // Move a widget to grid cell (x, y); prints "ok" or "blocked".
        function move(id: string, x: int, y: int): string {
            return DwcStore.move(id, x, y) ? "ok" : "blocked";
        }

        // Centre a widget on its screen: axis is h (horizontally), v (vertically) or both.
        function center(id: string, axis: string): string {
            return DwcStore.center(id, axis === "h" || axis === "v" ? axis : "both") ? "ok" : "blocked";
        }

        // Change a widget's size preset (S, M, L, W, X); prints "ok" or "blocked".
        function size(id: string, preset: string): string {
            return DwcStore.setSize(id, preset) ? "ok" : "blocked";
        }

        // Set one option: `value` is JSON, so a string needs quotes: set clock-led-1 seconds true
        function set(id: string, key: string, value: string): string {
            var r = DwcStore.rec(id);
            var m = r ? Modules.byType(r.type) : null;
            if (!m)
                return "no such widget";
            if (!m.opts.some(function (o) { return o.key === key; }))
                return "unknown option (try: " + m.opts.map(function (o) { return o.key; }).join(", ") + ")";
            try {
                DwcStore.setCfg(id, key, JSON.parse(value));
                return "ok";
            } catch (e) {
                return "bad value";
            }
        }

        // Set one appearance option (background, bgOpacity, radius, padding, shadow, border).
        function style(id: string, key: string, value: string): string {
            if (!DwcStore.rec(id))
                return "no such widget";
            if (!Modules.styleOptions.some(function (o) { return o.key === key; }))
                return "unknown option (try: " + Modules.styleOptions.map(function (o) { return o.key; }).join(", ") + ")";
            try {
                DwcStore.setStyle(id, key, JSON.parse(value));
                return "ok";
            } catch (e) {
                return "bad value";
            }
        }

        // A theme id (moss, umbra, …) or "cycle".
        function theme(id: string): void {
            if (id === "cycle") {
                var ids = Themes.ids();
                DwcStore.setTheme(ids[(ids.indexOf(DwcStore.themeId) + 1) % ids.length]);
            } else {
                DwcStore.setTheme(id);
            }
        }

        // auto, en or tr.
        function language(l: string): void {
            DwcStore.setLanguage(l);
        }

        // Back to the first-run layout.
        function reset(): void {
            DwcStore.resetAll();
        }

        // Hide every widget (the editor still shows them while it is open) / bring them back / flip. (`show` is taken by quickshell itself, hence `unhide`.)
        function hide(): void {
            DwcStore.shown = false;
        }

        function unhide(): void {
            DwcStore.shown = true;
        }

        function toggleVisible(): void {
            DwcStore.shown = !DwcStore.shown;
        }

        // Stop every data source (the widgets keep their last value) / start them again.
        function pause(): void {
            DwcData.paused = true;
        }

        function resume(): void {
            DwcData.paused = false;
        }

        // The layout as JSON.
        function list(): string {
            return DwcStore.serialize();
        }

        // The module ids `add` accepts, one per line.
        function modules(): string {
            return Modules.modules.map(function (m) { return m.type; }).join("\n");
        }

        // "editing" or "idle".
        function status(): string {
            return DwcStore.editing ? "editing" : "idle";
        }
    }
}
