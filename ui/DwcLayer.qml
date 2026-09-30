import QtQuick
import Quickshell
import Quickshell.Wayland
import "js/Layout.js" as Layout
import "js/Modules.js" as Modules

// The desktop itself: one click-through surface per screen, above the
// wallpaper and below every window. Only the rectangles of widgets that have
// buttons (the media player, the pomodoro, the notes) take the pointer; the
// rest of the screen belongs to whatever is underneath.
PanelWindow {
    id: win

    // Bottom is the desktop. DWC_LAYER=overlay is a debugging aid: it draws the
    // widgets above every window (still click-through) so they can be screenshotted.
    WlrLayershell.layer: Quickshell.env("DWC_LAYER") === "overlay" ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: "desktop-widget-control"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    visible: DwcStore.shown || DwcStore.editing

    readonly property string screenName: screen ? screen.name : ""

    // Ids of the widgets on this screen, and the pixel rects of the
    // interactive ones. Kept as plain properties updated only when they
    // change, so moving one widget does not rebuild the others.
    property var ids: []
    property var rects: []

    function sync() {
        var mine = [];
        var hot = [];
        for (var i = 0; i < DwcStore.order.length; i++) {
            var id = DwcStore.order[i];
            if (DwcStore.screenOf(id) !== win.screenName)
                continue;
            mine.push(id);
            var r = DwcStore.items[id];
            if (!r)
                continue;     // removed a moment ago; `order` catches up in the next change
            var m = Modules.byType(r.type);
            if (m && m.interactive) {
                var p = Layout.preset(r.size);
                var c = DwcStore.cell;
                hot.push({ x: r.x * c, y: r.y * c, w: p.w * c, h: p.h * c });
            }
        }
        if (mine.join(",") !== win.ids.join(","))
            win.ids = mine;
        if (JSON.stringify(hot) !== JSON.stringify(win.rects))
            win.rects = hot;
    }

    // The surface has no size until the compositor has configured it, so
    // until then the output's own size stands in for it.
    function report() {
        var w = win.width > 0 ? win.width : (win.screen ? win.screen.width : 0);
        var h = win.height > 0 ? win.height : (win.screen ? win.screen.height : 0);
        DwcStore.setScreen(win.screenName, w, h);
    }

    Component.onCompleted: {
        win.sync();
        win.report();
    }

    Connections {
        target: DwcStore
        function onItemsChanged() { win.sync() }
        function onOrderChanged() { win.sync() }
        function onCellChanged() { win.sync() }
    }

    onWidthChanged: win.report()
    onHeightChanged: win.report()

    mask: Region {
        DwcMaskRegion { r: win.rects[0] || null }
        DwcMaskRegion { r: win.rects[1] || null }
        DwcMaskRegion { r: win.rects[2] || null }
        DwcMaskRegion { r: win.rects[3] || null }
        DwcMaskRegion { r: win.rects[4] || null }
        DwcMaskRegion { r: win.rects[5] || null }
        DwcMaskRegion { r: win.rects[6] || null }
        DwcMaskRegion { r: win.rects[7] || null }
        DwcMaskRegion { r: win.rects[8] || null }
        DwcMaskRegion { r: win.rects[9] || null }
        DwcMaskRegion { r: win.rects[10] || null }
        DwcMaskRegion { r: win.rects[11] || null }
        DwcMaskRegion { r: win.rects[12] || null }
        DwcMaskRegion { r: win.rects[13] || null }
        DwcMaskRegion { r: win.rects[14] || null }
        DwcMaskRegion { r: win.rects[15] || null }
    }

    Repeater {
        model: win.ids
        delegate: DwcFrame {
            required property string modelData
            wid: modelData
        }
    }
}
