import QtQuick
import "controls"
import "js/Modules.js" as Modules

// The left-hand panel: every module as a live thumbnail, by category, with a
// search box. Drag a card onto the desktop, or double-click it to drop it in
// the first free spot. The drag itself is run by the editor (`editor`).
Rectangle {
    id: panel

    required property var editor

    property string category: ""           // "" = all
    property string query: ""

    readonly property var shown: {
        var q = panel.query.toLowerCase().trim();
        var out = [];
        for (var i = 0; i < Modules.modules.length; i++) {
            var m = Modules.modules[i];
            if (panel.category !== "" && m.category !== panel.category)
                continue;
            if (q !== "" && Str.pick(m.name).toLowerCase().indexOf(q) < 0 && m.type.indexOf(q) < 0)
                continue;
            out.push(m);
        }
        return out;
    }

    radius: 18
    color: DwcTheme.card
    border.width: 1
    border.color: DwcTheme.line


    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12

        Item {
            width: parent.width
            height: 32
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 10
                DText { anchors.verticalCenter: parent.verticalCenter; face: "display"; font.pixelSize: 17; font.weight: Font.DemiBold; text: Str.t("lib.title") }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: count.implicitWidth + 14
                    height: 20
                    radius: 10
                    color: "transparent"
                    border.width: 1
                    border.color: DwcTheme.line
                    DText { id: count; anchors.centerIn: parent; face: "mono"; font.pixelSize: 10; color: DwcTheme.muted; text: Modules.modules.length + " " + Str.t("lib.count") }
                }
            }
        }

        DTextField {
            width: parent.width
            text: panel.query
            placeholder: Str.t("lib.search")
            onEdited: t => panel.query = t
            onCommitted: t => panel.query = t
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: [{ id: "", name: Str.t("lib.all") }].concat(Modules.categories.map(function (c) { return { id: c.id, name: Str.pick(c.name) }; }))
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: panel.category === modelData.id
                    height: 26
                    width: chipText.implicitWidth + 22
                    radius: 13
                    color: on ? DwcTheme.fg : "transparent"
                    border.width: on ? 0 : 1
                    border.color: DwcTheme.line
                    DText {
                        id: chipText
                        anchors.centerIn: parent
                        font.pixelSize: 11
                        color: parent.on ? DwcTheme.card : DwcTheme.sub
                        text: modelData.name
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.category = modelData.id
                    }
                }
            }
        }
    }

    Flickable {
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top; margins: 16; topMargin: 14; bottomMargin: 8 }
        contentWidth: width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Grid {
            id: grid
            width: parent.width
            columns: 2
            spacing: 10

            Repeater {
                model: panel.shown
                delegate: DwcLibCard {
                    required property var modelData
                    module: modelData
                    editor: panel.editor
                    width: (grid.width - grid.spacing) / 2
                }
            }
        }

        DText {
            visible: panel.shown.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30
            color: DwcTheme.muted
            text: Str.t("lib.none")
        }
    }

    Column {
        id: foot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
        spacing: 3
        DText { width: parent.width; font.pixelSize: 11; color: DwcTheme.muted; text: Str.t("lib.hint") }
        DText { width: parent.width; font.pixelSize: 10; color: DwcTheme.faint; wrapMode: Text.WordWrap; elide: Text.ElideNone; text: Str.t("ed.keys") }
    }
}
