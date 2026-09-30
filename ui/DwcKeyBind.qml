import QtQuick
import Quickshell
import Quickshell.Io
import "controls"

// The first-run tour's offer to bind a key to the editor (Hyprland only; other
// compositors get the lines to copy). The work is ui/scripts/keybind.sh, so
// nothing is changed until the button is pressed.
Column {
    id: root

    readonly property bool hyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    // idle | busy | ok | exists | lua | nohypr | fail
    property string result: "idle"
    property string keys: ""
    property string file: ""

    spacing: 8

    Process {
        id: proc
        command: ["sh", Qt.resolvedUrl("scripts/keybind.sh").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split("|");
                root.result = p[0] || "fail";
                root.keys = p[1] || "";
                root.file = p[2] || "";
            }
        }
        onExited: if (root.result === "busy") root.result = "fail"
    }

    Row {
        visible: root.result === "idle" || root.result === "busy" || root.result === "fail"
        spacing: 12
        DButton {
            primary: true
            enabled: root.result !== "busy"
            text: Str.t("tour.keyAdd")
            onClicked: { root.result = "busy"; proc.running = true; }
        }
        DText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 12
            color: DwcTheme.muted
            text: root.result === "fail" ? Str.t("tour.keyFail") : Str.t("tour.keyAsk")
        }
    }

    DText {
        visible: root.result === "ok" || root.result === "exists"
        width: parent.width
        font.pixelSize: 13
        color: DwcTheme.acc
        wrapMode: Text.WordWrap
        text: root.result === "ok" ? Str.t("tour.keyOk").replace("%1", root.keys).replace("%2", root.file.replace(/^.*\//, ""))
                                   : Str.t("tour.keyExists")
    }

    Column {
        visible: root.result === "lua"
        spacing: 6
        DText { font.pixelSize: 12; color: DwcTheme.muted; text: Str.t("tour.keyLua") }
        Rectangle {
            height: 28; width: luaLine.implicitWidth + 24; radius: 8; color: DwcTheme.alt; border.width: 1; border.color: DwcTheme.line
            DText { id: luaLine; anchors.centerIn: parent; face: "mono"; font.pixelSize: 11; color: DwcTheme.sub; text: root.keys }
        }
    }

    DText {
        visible: root.result === "nohypr"
        font.pixelSize: 12
        color: DwcTheme.muted
        text: Str.t("tour.keyNone")
    }
}
