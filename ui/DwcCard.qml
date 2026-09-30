import QtQuick
import "js/Layout.js" as Layout
import "js/Modules.js" as Modules

// One widget as it looks on the desktop: the card (background, shadow,
// outline) with the module's own QML loaded inside. It knows nothing about the
// store, so the library can draw live thumbnails with the same component.
Item {
    id: card

    property string wid: ""
    property string type: ""
    property string sizeKey: "M"
    property var cfg: ({})
    property var st: Modules.styleDefaults()
    property real cellPx: DwcStore.cell
    property bool preview: false

    readonly property var dims: Layout.preset(sizeKey)
    readonly property real inset: Math.max(2, Math.round(cellPx * 0.1))
    readonly property var module: Modules.byType(type)

    width: dims.w * cellPx
    height: dims.h * cellPx

    // Cheap drop shadow: two soft rectangles, no offscreen blur pass.
    Rectangle {
        visible: card.st.shadow && card.st.background
        x: bg.x - 1
        y: bg.y + 2
        width: bg.width + 2
        height: bg.height + 2
        radius: bg.radius + 1
        color: Qt.rgba(0, 0, 0, DwcTheme.dark ? 0.26 : 0.12)
    }
    Rectangle {
        visible: card.st.shadow && card.st.background
        x: bg.x - 4
        y: bg.y + 3
        width: bg.width + 8
        height: bg.height + 8
        radius: bg.radius + 4
        color: Qt.rgba(0, 0, 0, DwcTheme.dark ? 0.10 : 0.05)
    }

    Rectangle {
        id: bg
        x: card.inset
        y: card.inset
        width: card.width - card.inset * 2
        height: card.height - card.inset * 2
        radius: loader.item && loader.item.cardRadius >= 0 ? loader.item.cardRadius : card.st.radius
        color: card.st.background ? DwcTheme.alpha(DwcTheme.card, card.st.bgOpacity) : "transparent"
        border.width: card.st.border ? 1 : 0
        border.color: DwcTheme.line
    }

    Loader {
        id: loader
        x: bg.x + card.st.padding
        y: bg.y + card.st.padding
        width: bg.width - card.st.padding * 2
        height: bg.height - card.st.padding * 2
        source: card.module ? Qt.resolvedUrl(card.module.source) : ""
        clip: true

        onLoaded: {
            item.wid = card.wid;
            item.cfg = card.cfg;
            item.sizeKey = card.sizeKey;
            item.preview = card.preview;
        }
    }

    onCfgChanged: if (loader.item) loader.item.cfg = card.cfg
    onSizeKeyChanged: if (loader.item) loader.item.sizeKey = card.sizeKey
}
