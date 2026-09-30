import QtQuick
import "controls"
import "js/Layout.js" as Layout
import "js/Modules.js" as Modules
import "js/Themes.js" as Themes
import "js/Strings.js" as Strings

// The right-hand panel: the selected widget's size, options and appearance,
// or (second tab) the settings that belong to the whole desktop.
Rectangle {
    id: panel

    property string tab: "widget"          // "widget" | "settings"
    property bool confirmReset: false

    readonly property string sel: DwcStore.selected
    readonly property var rec: DwcStore.items[sel] || null
    readonly property var module: rec ? Modules.byType(rec.type) : null
    readonly property var cfg: sel !== "" ? DwcStore.cfgOf(sel) : ({})
    readonly property var st: sel !== "" ? DwcStore.styleOf(sel) : ({})

    onSelChanged: {
        if (sel !== "")
            tab = "widget";
        confirmReset = false;
    }

    radius: 18
    color: DwcTheme.card
    border.width: 1
    border.color: DwcTheme.line


    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12

        DSegmented {
            width: parent.width
            model: [{ v: "widget", label: Str.t("ed.widget") }, { v: "settings", label: Str.t("set.title") }]
            current: panel.tab
            onPicked: v => panel.tab = v
        }
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top; topMargin: 10; bottomMargin: 6 }
        contentWidth: width
        contentHeight: body.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: body
            x: 16
            width: flick.width - 32
            implicitHeight: panel.tab === "widget" ? (panel.rec ? widgetCol.implicitHeight : empty.implicitHeight) : settingsCol.implicitHeight

            // ---- nothing selected ----
            Column {
                id: empty
                visible: panel.tab === "widget" && !panel.rec
                width: parent.width
                spacing: 6
                topPadding: 18
                DText { width: parent.width; face: "display"; font.pixelSize: 15; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; elide: Text.ElideNone; text: Str.t("ed.nothing") }
                DText { width: parent.width; color: DwcTheme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone; text: Str.t("ed.nothingSub") }
            }

            // ---- selected widget ----
            Column {
                id: widgetCol
                visible: panel.tab === "widget" && panel.rec !== null
                width: parent.width
                spacing: 4

                DText {
                    width: parent.width
                    face: "display"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    text: panel.module ? Str.pick(panel.module.name) : ""
                }
                DText {
                    width: parent.width
                    face: "mono"
                    font.pixelSize: 10
                    color: DwcTheme.muted
                    text: panel.sel + (panel.rec && panel.rec.locked ? "  ·  " + Str.t("ed.locked") : "")
                }

                Item { width: 1; height: 8 }

                Row {
                    spacing: 10
                    anchors.left: parent.left
                    DText { anchors.verticalCenter: parent.verticalCenter; color: DwcTheme.sub; text: Str.t("ed.size") }
                    DSegmented {
                        model: {
                            var out = [];
                            var sizes = panel.module ? panel.module.sizes : [];
                            for (var i = 0; i < sizes.length; i++)
                                out.push({ v: sizes[i], label: sizes[i] });
                            return out;
                        }
                        current: panel.rec ? panel.rec.size : ""
                        onPicked: v => DwcStore.setSize(panel.sel, v)
                    }
                }

                Row {
                    spacing: 8
                    anchors.left: parent.left
                    topPadding: 6
                    DText { anchors.verticalCenter: parent.verticalCenter; color: DwcTheme.sub; text: Str.t("ed.position") }
                    DButton { text: Str.t("ed.centerH"); onClicked: DwcStore.center(panel.sel, "h") }
                    DButton { text: Str.t("ed.centerV"); onClicked: DwcStore.center(panel.sel, "v") }
                }

                Item { width: 1; height: 6 }
                DText { font.pixelSize: 10; font.letterSpacing: 1.2; color: DwcTheme.muted; text: Str.t("ed.widget").toUpperCase() }

                Repeater {
                    model: panel.module ? panel.module.opts : []
                    delegate: DwcOptionRow {
                        required property var modelData
                        visible: !modelData.hidden && Modules.applies(modelData, panel.cfg)
                        opt: modelData
                        value: panel.cfg[modelData.key]
                        onChanged: v => DwcStore.setCfg(panel.sel, modelData.key, v)
                    }
                }

                Item { width: 1; height: 6 }
                DText { font.pixelSize: 10; font.letterSpacing: 1.2; color: DwcTheme.muted; text: Str.t("ed.style").toUpperCase() }

                Repeater {
                    model: Modules.styleOptions
                    delegate: DwcOptionRow {
                        required property var modelData
                        opt: modelData
                        value: panel.st[modelData.key]
                        onChanged: v => DwcStore.setStyle(panel.sel, modelData.key, v)
                    }
                }

                Item { width: 1; height: 10 }
                DButton { text: Str.t("ed.reset"); icon: "reset"; onClicked: DwcStore.resetWidget(panel.sel) }
            }

            // ---- whole-desktop settings ----
            Column {
                id: settingsCol
                visible: panel.tab === "settings"
                width: parent.width
                spacing: 10

                DText { font.pixelSize: 10; font.letterSpacing: 1.2; color: DwcTheme.muted; text: Str.t("set.theme").toUpperCase() }
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: Themes.list
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: DwcStore.themeId === modelData.id
                            width: 38
                            height: 38
                            radius: 10
                            color: modelData.card
                            border.width: on ? 2 : 1
                            border.color: on ? DwcTheme.fg : DwcTheme.lineStrong
                            Rectangle {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                radius: 7
                                color: modelData.acc
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DwcStore.setTheme(modelData.id)
                            }
                        }
                    }
                }
                DText { color: DwcTheme.sub; text: Themes.byId(DwcStore.themeId).name }

                Item { width: 1; height: 4 }
                DText { font.pixelSize: 10; font.letterSpacing: 1.2; color: DwcTheme.muted; text: Str.t("set.language").toUpperCase() }
                DSegmented {
                    model: [{ v: "auto", label: Str.t("set.langAuto") }].concat(Strings.languages)
                    current: DwcStore.language
                    onPicked: v => DwcStore.setLanguage(v)
                }

                Item { width: 1; height: 4 }
                DText { font.pixelSize: 10; font.letterSpacing: 1.2; color: DwcTheme.muted; text: Str.t("set.cell").toUpperCase() }
                DSlider {
                    width: parent.width
                    from: DwcStore.minCell
                    to: DwcStore.maxCell
                    step: 4
                    unit: " px"
                    value: DwcStore.cell
                    onMoved: v => DwcStore.setCell(v)
                }

                Item { width: 1; height: 8 }
                DButton {
                    danger: true
                    icon: "reset"
                    text: panel.confirmReset ? Str.t("set.resetConfirm") : Str.t("set.resetAll")
                    onClicked: {
                        if (panel.confirmReset) {
                            DwcStore.resetAll();
                            panel.confirmReset = false;
                        } else {
                            panel.confirmReset = true;
                        }
                    }
                }
            }
        }
    }

    // Actions for the selected widget.
    Row {
        id: foot
        visible: panel.tab === "widget" && panel.rec !== null
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
        height: visible ? 32 : 0
        spacing: 8

        DButton { icon: "copy"; text: Str.t("ed.duplicate"); onClicked: DwcStore.duplicate(panel.sel) }
        DButton {
            icon: panel.rec && panel.rec.locked ? "unlock" : "lock"
            active: panel.rec ? panel.rec.locked : false
            onClicked: DwcStore.toggleLock(panel.sel)
        }
        DButton { danger: true; icon: "trash"; text: Str.t("ed.delete"); onClicked: DwcStore.remove(panel.sel) }
    }
}
