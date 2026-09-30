import QtQuick
import "js/Layout.js" as Layout

// Base of every widget in widgets/. The card (DwcCard) loads one, sizes it to
// the card's content area and keeps `cfg` (the widget's options, defaults
// already filled in) and `sizeKey` up to date. A widget only draws itself.
Item {
    id: root

    property string wid: ""               // the store id; "" in a thumbnail
    property var cfg: ({})
    property string sizeKey: "M"
    property bool preview: false          // a library thumbnail: no real interaction
    // A look that needs its own card shape (the media pill) sets this; -1 keeps the Radius option.
    property real cardRadius: -1

    readonly property int cols: Layout.preset(sizeKey).w
    readonly property int rows: Layout.preset(sizeKey).h
    readonly property bool small: sizeKey === "S"

    // An option holding a colour choice -> the colour.
    function tone(key) {
        return DwcTheme.resolve(root.cfg[key]);
    }

    // `cfg.key` with a fallback for a value that is somehow missing.
    function opt(key, fallback) {
        var v = root.cfg[key];
        return v === undefined || v === null ? fallback : v;
    }
}
