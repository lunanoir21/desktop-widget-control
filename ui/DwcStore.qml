pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "js/Layout.js" as Layout
import "js/Modules.js" as Modules
import "js/Themes.js" as Themes

// Everything that is saved (theme, language, grid cell, the widgets and their
// options) plus the little bit of editor state the two windows share.
//
// The layout lives in one JSON file; a hand edit of it is picked up live.
// Widgets are kept as  order: [id, ...]  and  items: { id: record }  so a
// change to one widget never rebuilds the others; `items` is replaced (not
// mutated) on every change, which is what notifies the bindings.
//
// A record:  { type, size, x, y, screen, locked, cfg: {...}, st: {...} }
// x and y are grid cells; `screen` is an output name, "" meaning the primary one.
Item {
    id: root

    readonly property string dir: Quickshell.env("DWC_CONFIG_DIR")
        || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/desktop-widget-control")
    readonly property string file: dir + "/layout.json"
    readonly property int schema: 1

    // ---- saved ---------------------------------------------------------------
    property string themeId: Themes.defaultId
    property string language: "auto"      // "auto" | "en" | "tr"
    property int cell: 40                 // px per grid cell
    property var order: []
    property var items: ({})

    // ---- not saved -----------------------------------------------------------
    property bool loaded: false
    property bool fresh: false            // true when there was no saved layout
    property bool editing: false
    property bool shown: true             // false hides every widget (the `hide` IPC call)
    property string selected: ""
    property string toast: ""
    property bool onboarded: true         // false only on a first run; set by finishing or skipping the tour
    property bool tourOpen: false
    property int tourStart: 0
    property string primaryScreen: ""
    property var screenSizes: ({})        // name -> { w, h }

    readonly property int minCell: 24
    readonly property int maxCell: 64

    signal layoutChanged()

    // ---- lookups -------------------------------------------------------------

    function rec(id) {
        return root.items[id] || null;
    }

    function screenOf(id) {
        var r = root.items[id];
        return r && r.screen ? r.screen : root.primaryScreen;
    }

    function boundsOf(screenName) {
        var s = root.screenSizes[screenName || root.primaryScreen];
        return s ? Layout.boundsFor(s.w, s.h, root.cell) : { cols: 48, rows: 27 };
    }

    function rectOf(id) {
        var r = root.items[id];
        if (!r)
            return null;
        var p = Layout.preset(r.size);
        return { x: r.x, y: r.y, w: p.w, h: p.h };
    }

    // Rects of every widget on a screen, optionally leaving one out.
    function rectsOn(screenName, exceptId) {
        var out = [];
        for (var i = 0; i < root.order.length; i++) {
            var id = root.order[i];
            if (id === exceptId || root.screenOf(id) !== screenName)
                continue;
            out.push(root.rectOf(id));
        }
        return out;
    }

    function cfgOf(id) {
        var r = root.items[id];
        return r ? Modules.mergeCfg(r.type, r.cfg) : ({});
    }

    function styleOf(id) {
        var r = root.items[id];
        return r ? Modules.mergeStyle(r.st, r.type) : Modules.styleDefaults();
    }

    // ---- editing the layout --------------------------------------------------

    // A record is replaced, never edited in place: bindings that read
    // `items[id]` only notice a change when the object they hold is a new one.
    function patch(id, changes) {
        var next = Object.assign({}, root.items);
        next[id] = Object.assign({}, root.items[id], changes);
        root.items = next;
        root.saveSoon();
        root.layoutChanged();
    }

    function say(msg) {
        root.toast = msg;
        toastTimer.restart();
    }

    function select(id) {
        root.selected = id;
    }

    // Adds a widget near (x, y) cells; returns its id, or "" when the screen has no room.
    function add(type, sizeKey, x, y, screenName) {
        var m = Modules.byType(type);
        if (!m)
            return "";
        var sk = sizeKey && m.sizes.indexOf(sizeKey) >= 0 ? sizeKey : m.size;
        var p = Layout.preset(sk);
        var scr = screenName || root.primaryScreen;
        var spot = Layout.findFree(root.rectsOn(scr, ""), p.w, p.h, root.boundsOf(scr), x, y);
        if (!spot)
            return "";
        var id = Layout.nextId(type, root.order);
        var next = Object.assign({}, root.items);
        next[id] = { type: type, size: sk, x: spot.x, y: spot.y, screen: scr === root.primaryScreen ? "" : scr,
                     locked: false, cfg: Modules.cfgDefaults(type), st: Modules.styleDefaults(type) };
        root.items = next;
        root.order = root.order.concat([id]);
        root.saveSoon();
        root.layoutChanged();
        return id;
    }

    // Moves to (x, y) cells; false when that spot is taken or off-screen.
    function move(id, x, y) {
        var r = root.items[id];
        if (!r || r.locked)
            return false;
        var scr = root.screenOf(id);
        var p = Layout.preset(r.size);
        var b = root.boundsOf(scr);
        var target = Layout.clampRect({ x: x, y: y, w: p.w, h: p.h }, b);
        if (target.x === r.x && target.y === r.y)
            return true;
        if (!Layout.canPlace(target, root.rectsOn(scr, id), b))
            return false;
        root.patch(id, { x: target.x, y: target.y });
        return true;
    }

    // Changes the size preset in place, or nudges to the nearest free spot; false when nothing fits.
    function setSize(id, sizeKey) {
        var r = root.items[id];
        var m = r ? Modules.byType(r.type) : null;
        if (!r || !m || r.locked || m.sizes.indexOf(sizeKey) < 0)
            return false;
        if (r.size === sizeKey)
            return true;
        var scr = root.screenOf(id);
        var p = Layout.preset(sizeKey);
        var spot = Layout.findFree(root.rectsOn(scr, id), p.w, p.h, root.boundsOf(scr), r.x, r.y);
        if (!spot) {
            root.say(Str.t("ed.noRoom"));
            return false;
        }
        root.patch(id, { size: sizeKey, x: spot.x, y: spot.y });
        return true;
    }

    // Put a widget in the middle of its screen: axis "h" keeps its row, "v" its
    // column, "both" moves it either way. When the middle is taken it goes to the
    // nearest free spot instead.
    function center(id, axis) {
        var r = root.items[id];
        if (!r || r.locked)
            return false;
        var scr = root.screenOf(id);
        var b = root.boundsOf(scr);
        var p = Layout.preset(r.size);
        var mid = Layout.centered(p.w, p.h, b);
        var x = axis === "v" ? r.x : mid.x;
        var y = axis === "h" ? r.y : mid.y;
        if (root.move(id, x, y))
            return true;
        var spot = Layout.findFree(root.rectsOn(scr, id), p.w, p.h, b, x, y);
        if (!spot) {
            root.say(Str.t("ed.noRoom"));
            return false;
        }
        root.patch(id, { x: spot.x, y: spot.y });
        return true;
    }

    function setCfg(id, key, value) {
        var r = root.items[id];
        if (!r)
            return;
        var cfg = Object.assign({}, r.cfg);
        cfg[key] = typeof value === "string" ? value.slice(0, root.maxCfgString) : value;
        root.patch(id, { cfg: cfg });
    }

    function setStyle(id, key, value) {
        var r = root.items[id];
        if (!r)
            return;
        var st = Object.assign({}, r.st);
        st[key] = value;
        root.patch(id, { st: st });
    }

    function toggleLock(id) {
        var r = root.items[id];
        if (!r)
            return;
        root.patch(id, { locked: !r.locked });
    }

    function resetWidget(id) {
        var r = root.items[id];
        if (!r)
            return;
        root.patch(id, { cfg: Modules.cfgDefaults(r.type), st: Modules.styleDefaults(r.type) });
    }

    function remove(id) {
        if (!root.items[id])
            return;
        var next = Object.assign({}, root.items);
        delete next[id];
        root.items = next;
        root.order = root.order.filter(function (o) { return o !== id; });
        if (root.selected === id)
            root.selected = "";
        root.saveSoon();
        root.layoutChanged();
    }

    function duplicate(id) {
        var r = root.items[id];
        if (!r)
            return "";
        var nid = root.add(r.type, r.size, r.x + 1, r.y + 1, root.screenOf(id));
        if (nid === "") {
            root.say(Str.t("lib.full"));
            return "";
        }
        root.patch(nid, { cfg: Object.assign({}, r.cfg), st: Object.assign({}, r.st) });
        root.selected = nid;
        return nid;
    }

    function openTour(step) {
        root.tourStart = step || 0;
        root.tourOpen = true;
    }

    function finishTour() {
        root.tourOpen = false;
        if (!root.onboarded) {
            root.onboarded = true;
            root.saveSoon();
        }
    }

    function setTheme(id) {
        if (!Themes.exists(id))
            return;
        root.themeId = id;
        root.saveSoon();
    }

    function setLanguage(l) {
        root.language = (l === "en" || l === "tr") ? l : "auto";
        root.saveSoon();
    }

    function setCell(px) {
        root.cell = Math.max(root.minCell, Math.min(root.maxCell, Math.round(px)));
        root.fitAll();
        root.saveSoon();
    }

    function setScreen(name, w, h) {
        if (!(w > 0 && h > 0))
            return;
        var cur = root.screenSizes[name];
        if (cur && cur.w === w && cur.h === h)
            return;
        var next = Object.assign({}, root.screenSizes);
        next[name] = { w: w, h: h };
        root.screenSizes = next;
        if (root.primaryScreen === "")
            root.primaryScreen = name;
        if (root.loaded) {
            if (root.fresh && root.order.length === 0 && name === root.primaryScreen)
                root.seedDefaults();
            else
                root.fitAll();
        }
    }

    // Put the layout right for the screens we know the size of: pull widgets
    // that ended up off-screen back inside, and move one that sits on top of
    // another to the nearest free spot. Screens whose size is not known yet are
    // left alone; judging them by a guessed size once wrecked a saved layout.
    function fitAll() {
        var next = Object.assign({}, root.items);
        var changed = false;
        var byScreen = {};                    // screen -> [ids], in layout order
        for (var i = 0; i < root.order.length; i++) {
            var scr = root.screenOf(root.order[i]);
            if (root.screenSizes[scr])
                (byScreen[scr] = byScreen[scr] || []).push(root.order[i]);
        }
        for (var name in byScreen) {
            var ids = byScreen[name];
            var before = ids.map(function (id) { return root.rectOf(id); });
            var after = Layout.settle(before, root.boundsOf(name));
            for (var k = 0; k < ids.length; k++) {
                if (after[k].x === before[k].x && after[k].y === before[k].y)
                    continue;
                next[ids[k]] = Object.assign({}, next[ids[k]], { x: after[k].x, y: after[k].y });
                changed = true;
            }
        }
        if (changed) {
            root.items = next;
            root.saveSoon();
            root.layoutChanged();
        }
    }

    // The widgets a first run starts with: a short column on the right edge.
    function seedDefaults() {
        var b = root.boundsOf(root.primaryScreen);
        var x0 = Math.max(0, b.cols - 10);
        var plan = [
            { type: "clock-led", size: "M", dx: 0, row: 0 },
            { type: "cpu-graph", size: "M", dx: 0, row: 1 },
            { type: "ram-ring", size: "S", dx: 0, row: 2 },
            { type: "temp-gauge", size: "S", dx: 4, row: 2 },
            { type: "media", size: "M", dx: 0, row: 3 }
        ];
        root.items = ({});
        root.order = [];
        for (var i = 0; i < plan.length; i++)
            root.add(plan[i].type, plan[i].size, x0 + plan[i].dx, 2 + plan[i].row * 5, root.primaryScreen);
        root.fresh = false;
    }

    function resetAll() {
        root.selected = "";
        root.seedDefaults();
    }

    // ---- saving and loading --------------------------------------------------

    property string lastWritten: ""

    function serialize() {
        var widgets = [];
        for (var i = 0; i < root.order.length; i++) {
            var id = root.order[i];
            var r = root.items[id];
            widgets.push({ id: id, type: r.type, size: r.size, x: r.x, y: r.y, screen: r.screen || "",
                           locked: !!r.locked, cfg: r.cfg, st: r.st });
        }
        return JSON.stringify({ version: root.schema, theme: root.themeId, language: root.language,
                                cell: root.cell, onboarded: root.onboarded, widgets: widgets }, null, 2) + "\n";
    }

    function saveSoon() {
        if (root.loaded)
            saveTimer.restart();
    }

    function saveNow() {
        if (!root.loaded)
            return;
        var text = root.serialize();
        root.lastWritten = text;
        store.setText(text);
        Quickshell.execDetached(["sh", "-c", 'sleep 1; chmod 600 "$1" 2>/dev/null', "sh", root.file]);
    }

    function parse(text) {
        var data = JSON.parse(text);
        if (!data || typeof data !== "object" || !Array.isArray(data.widgets))
            throw new Error("not a layout file");
        var items = {};
        var order = [];
        for (var i = 0; i < data.widgets.length; i++) {
            var w = data.widgets[i];
            var m = w && typeof w.type === "string" ? Modules.byType(w.type) : null;
            if (!m)
                continue;
            var id = typeof w.id === "string" && w.id !== "" && !items[w.id] ? w.id : Layout.nextId(w.type, order);
            items[id] = {
                type: w.type,
                size: m.sizes.indexOf(w.size) >= 0 ? w.size : m.size,
                x: Math.max(0, Math.round(Number(w.x) || 0)),
                y: Math.max(0, Math.round(Number(w.y) || 0)),
                screen: typeof w.screen === "string" ? w.screen : "",
                locked: !!w.locked,
                cfg: w.cfg && typeof w.cfg === "object" ? w.cfg : ({}),
                st: w.st && typeof w.st === "object" ? w.st : ({})
            };
            order.push(id);
        }
        root.themeId = Themes.exists(data.theme) ? data.theme : Themes.defaultId;
        root.language = data.language === "en" || data.language === "tr" ? data.language : "auto";
        root.cell = Math.max(root.minCell, Math.min(root.maxCell, Math.round(Number(data.cell) || 40)));
        // A layout saved before the tour existed counts as seen; `dwc tour` shows it again.
        root.onboarded = data.onboarded !== false;
        root.items = items;
        root.order = order;
    }

    // The layout holds notes and place names: keep the folder and file private to the user.
    readonly property int maxFileBytes: 2097152
    readonly property int maxCfgString: 20000      // one option's text (a note, a city): far more than anyone types

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" && { [ ! -e "$2" ] || chmod 600 "$2"; }', "sh", root.dir, root.file])

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root.saveNow()
    }

    Timer {
        id: toastTimer
        interval: 2600
        onTriggered: root.toast = ""
    }

    FileView {
        id: store
        path: root.file
        atomicWrites: true
        watchChanges: true
        printErrors: false       // a missing file is the normal first run
        onFileChanged: reload()
        onLoaded: {
            var text = store.text();
            if (text === root.lastWritten && root.loaded)
                return;
            try {
                if (text.length > root.maxFileBytes)
                    throw new Error("file is larger than " + root.maxFileBytes + " bytes");
                root.parse(text);
                root.fresh = false;
            } catch (e) {
                console.warn("desktop-widget-control: layout.json is unreadable (" + e + "); keeping a copy as layout.json.bad");
                Quickshell.execDetached(["cp", "-f", root.file, root.file + ".bad"]);
                root.items = ({});
                root.order = [];
                root.fresh = true;
            }
            root.loaded = true;
            root.fitAll();
            if (root.fresh && root.primaryScreen !== "")
                root.seedDefaults();
        }
        onLoadFailed: {
            root.fresh = true;
            root.onboarded = false;
            root.tourOpen = true;
            root.loaded = true;
            if (root.primaryScreen !== "")
                root.seedDefaults();
        }
    }
}
