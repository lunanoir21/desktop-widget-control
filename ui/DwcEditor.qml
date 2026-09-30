import QtQuick
import Quickshell
import Quickshell.Wayland
import "controls"
import "js/Layout.js" as Layout
import "js/Modules.js" as Modules

// Edit mode: one full-screen surface per screen, above every window. It draws
// the grid, puts a handle over each widget, and (on the primary screen) the
// library, the inspector and a small bar. The widgets underneath keep being
// drawn by the desktop layer, so what moves here is what is saved.
//
// The panels stay out of the way of the desktop: they slide off the screen
// whenever you are dragging something, the inspector sits on the side away
// from the widget it is editing, and the bar's buttons (or Tab) bring them
// back or send them away.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desktop-widget-control-editor"
    WlrLayershell.keyboardFocus: win.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"

    readonly property string screenName: screen ? screen.name : ""
    readonly property bool primary: screenName === DwcStore.primaryScreen

    property var ids: []

    function sync() {
        var mine = [];
        for (var i = 0; i < DwcStore.order.length; i++)
            if (DwcStore.screenOf(DwcStore.order[i]) === win.screenName)
                mine.push(DwcStore.order[i]);
        if (mine.join(",") !== win.ids.join(","))
            win.ids = mine;
    }

    Component.onCompleted: win.sync()
    Connections {
        target: DwcStore
        function onOrderChanged() { win.sync() }
    }

    FocusScope {
        id: root
        anchors.fill: parent
        focus: true

        // ---- panels: what the user asked for, and what is shown right now ----
        property bool libOpen: true
        property bool inspOpen: false
        property bool panelsHidden: false      // Tab
        property bool busy: false              // dragging a card, a widget or a grip

        // The inspector goes to the side away from the selected widget, so the
        // widget is never hidden behind the panel that edits it.
        readonly property string inspSide: {
            var r = DwcStore.selected !== "" ? DwcStore.rectOf(DwcStore.selected) : null;
            if (!r)
                return "right";
            var centre = (r.x + r.w / 2) * DwcStore.cell;
            return centre > win.width / 2 ? "left" : "right";
        }

        readonly property bool libShown: libOpen && !busy && !panelsHidden
        readonly property bool inspShown: inspOpen && !busy && !panelsHidden

        // Two panels never share a side: opening one closes the other if they would collide.
        function openLibrary() {
            root.panelsHidden = false;
            root.libOpen = true;
            if (root.inspSide === "left")
                root.inspOpen = false;
        }
        function openInspector() {
            root.panelsHidden = false;
            root.inspOpen = true;
            if (root.inspSide === "left")
                root.libOpen = false;
        }

        Connections {
            target: DwcStore
            function onSelectedChanged() {
                if (DwcStore.selected !== "")
                    root.openInspector();
                else if (inspector.tab === "widget")
                    root.inspOpen = false;
            }
        }

        // ---- keys ----
        // Esc first abandons a drag in progress, then closes the editor.
        Keys.onEscapePressed: {
            if (root.dragType !== "")
                root.cancelDrag();
            else
                DwcStore.editing = false;
        }
        Keys.onTabPressed: event => { root.panelsHidden = !root.panelsHidden; event.accepted = true; }
        Keys.onDeletePressed: if (DwcStore.selected !== "") DwcStore.remove(DwcStore.selected)
        Keys.onPressed: event => {
            var id = DwcStore.selected;
            if (id === "")
                return;
            var r = DwcStore.rec(id);
            if (event.key === Qt.Key_Left) DwcStore.move(id, r.x - 1, r.y);
            else if (event.key === Qt.Key_Right) DwcStore.move(id, r.x + 1, r.y);
            else if (event.key === Qt.Key_Up) DwcStore.move(id, r.x, r.y - 1);
            else if (event.key === Qt.Key_Down) DwcStore.move(id, r.x, r.y + 1);
            else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) DwcStore.duplicate(id);
            else return;
            event.accepted = true;
        }

        // ---- the library drag ----
        property string dragType: ""
        property string dragSize: ""
        property point dragPos: Qt.point(0, 0)

        readonly property var dragDims: dragType !== "" ? Layout.preset(dragSize) : ({ w: 1, h: 1 })
        readonly property var dragCell: {
            if (dragType === "")
                return { x: 0, y: 0, ok: false };
            var b = DwcStore.boundsOf(win.screenName);
            var raw = {
                x: Math.round((dragPos.x - dragDims.w * DwcStore.cell / 2) / DwcStore.cell),
                y: Math.round((dragPos.y - dragDims.h * DwcStore.cell / 2) / DwcStore.cell),
                w: dragDims.w, h: dragDims.h
            };
            var c = Layout.clampRect(raw, b);
            return { x: c.x, y: c.y, ok: Layout.canPlace(c, DwcStore.rectsOn(win.screenName, ""), b) };
        }

        // The panels slide away for the whole drag, so the drop can land anywhere,
        // including where the library was.
        function beginDrag(type, size) {
            root.dragSize = size;
            root.dragType = type;
            root.busy = true;
        }
        function moveDrag(p) {
            root.dragPos = p;
        }
        function endDrag() {
            var t = root.dragType;
            var size = root.dragSize;
            var cell = root.dragCell;          // read before dragType is cleared: it is empty without one
            root.dragType = "";
            root.busy = false;
            if (t === "")
                return;
            var id = DwcStore.add(t, size, cell.x, cell.y, win.screenName);
            if (id === "")
                DwcStore.say(Str.t("lib.full"));
            else
                DwcStore.select(id);
        }
        // The drag ended without a drop (focus lost, Esc): put everything back.
        function cancelDrag() {
            root.dragType = "";
            root.busy = false;
        }
        function quickAdd(type) {
            var id = DwcStore.add(type, "", 2, 2, win.screenName);
            if (id === "")
                DwcStore.say(Str.t("lib.full"));
            else
                DwcStore.select(id);
        }

        // ---- stage ----
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.26)
        }

        // Empty desktop: a click deselects.
        MouseArea {
            anchors.fill: parent
            onPressed: DwcStore.select("")
        }

        Repeater {
            model: Math.ceil(win.width / DwcStore.cell) + 1
            delegate: Rectangle {
                required property int index
                x: index * DwcStore.cell
                width: 1
                height: win.height
                color: DwcTheme.alpha("#ffffff", 0.07)
            }
        }
        Repeater {
            model: Math.ceil(win.height / DwcStore.cell) + 1
            delegate: Rectangle {
                required property int index
                y: index * DwcStore.cell
                width: win.width
                height: 1
                color: DwcTheme.alpha("#ffffff", 0.07)
            }
        }

        Repeater {
            model: win.ids
            delegate: DwcHandle {
                required property string modelData
                wid: modelData
                editor: root
            }
        }

        // Where the dragged widget would land.
        Rectangle {
            visible: root.dragType !== ""
            x: root.dragCell.x * DwcStore.cell + 4
            y: root.dragCell.y * DwcStore.cell + 4
            width: root.dragDims.w * DwcStore.cell - 8
            height: root.dragDims.h * DwcStore.cell - 8
            radius: 16
            color: DwcTheme.alpha(root.dragCell.ok ? DwcTheme.acc : DwcTheme.danger, 0.14)
            border.width: 2
            border.color: root.dragCell.ok ? DwcTheme.acc : DwcTheme.danger
        }

        // ---- panels ----
        DwcLibrary {
            id: library
            // Stays visible for the whole drag: hiding an item that holds the
            // pointer grab would cancel the drag half way (and freeze the editor).
            visible: win.primary && (x > -width || root.busy)
            editor: root
            y: 72
            width: 312
            height: parent.height - 88
            x: root.libShown ? 16 : -width - 24
            opacity: root.libShown ? 1 : 0

            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        DwcInspector {
            id: inspector
            visible: win.primary && ((x > -width && x < parent.width) || root.busy)
            y: 72
            width: 300
            height: parent.height - 88
            x: root.inspShown
                ? (root.inspSide === "left" ? 16 : parent.width - width - 16)
                : (root.inspSide === "left" ? -width - 24 : parent.width + 24)
            opacity: root.inspShown ? 1 : 0

            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // ---- the bar: panels and Done ----
        Rectangle {
            visible: win.primary
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 16 }
            height: 44
            width: barRow.implicitWidth + 20
            radius: 22
            color: DwcTheme.card
            border.width: 1
            border.color: DwcTheme.line
            z: 20

            Row {
                id: barRow
                anchors.centerIn: parent
                spacing: 6

                DButton {
                    icon: "grid"
                    text: Str.t("lib.title")
                    active: root.libShown
                    onClicked: root.libShown ? root.libOpen = false : root.openLibrary()
                }
                DButton {
                    icon: "gear"
                    text: Str.t("set.title")
                    active: root.inspShown && inspector.tab === "settings"
                    onClicked: {
                        if (root.inspShown && inspector.tab === "settings") {
                            root.inspOpen = false;
                        } else {
                            inspector.tab = "settings";
                            root.openInspector();
                        }
                    }
                }
                DButton {
                    primary: true
                    text: Str.t("ed.done")
                    onClicked: DwcStore.editing = false
                }
            }
        }

        // The dragged widget under the pointer.
        Item {
            visible: root.dragType !== ""
            x: root.dragPos.x - width / 2
            y: root.dragPos.y - height / 2
            width: root.dragDims.w * DwcStore.cell
            height: root.dragDims.h * DwcStore.cell
            opacity: 0.85
            z: 50

            Loader {
                active: root.dragType !== ""
                anchors.fill: parent
                sourceComponent: DwcCard {
                    type: root.dragType
                    sizeKey: root.dragSize
                    cfg: Modules.cfgDefaults(root.dragType)
                    preview: true
                }
            }
        }

        // ---- messages ----
        Rectangle {
            visible: DwcStore.toast !== "" && win.primary
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 36 }
            height: 38
            width: toastText.implicitWidth + 34
            radius: 19
            color: DwcTheme.card
            border.width: 1
            border.color: DwcTheme.lineStrong
            DText { id: toastText; anchors.centerIn: parent; text: DwcStore.toast }
        }
    }
}
