import QtQuick
import "js/Layout.js" as Layout
import "js/Modules.js" as Modules

// A DwcCard bound to one record of the store: it sits at the record's grid
// position, follows its options, and glides while the editor moves it.
Item {
    id: frame

    required property string wid

    readonly property var rec: DwcStore.items[wid] || null

    property var cfg: ({})
    property var st: Modules.styleDefaults()

    // The store replaces `items` on every change; only pass a widget its own
    // options on when they really differ, so an edit to one widget does not
    // make its neighbours re-lay themselves out.
    function refresh() {
        var c = DwcStore.cfgOf(wid);
        if (JSON.stringify(c) !== JSON.stringify(frame.cfg))
            frame.cfg = c;
        var s = DwcStore.styleOf(wid);
        if (JSON.stringify(s) !== JSON.stringify(frame.st))
            frame.st = s;
    }

    Component.onCompleted: refresh()

    Connections {
        target: DwcStore
        function onItemsChanged() { frame.refresh() }
    }

    x: rec ? rec.x * DwcStore.cell : 0
    y: rec ? rec.y * DwcStore.cell : 0
    width: card.width
    height: card.height

    Behavior on x { enabled: DwcStore.editing; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: DwcStore.editing; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    DwcCard {
        id: card
        wid: frame.wid
        type: frame.rec ? frame.rec.type : ""
        sizeKey: frame.rec ? frame.rec.size : "M"
        cfg: frame.cfg
        st: frame.st
    }
}
