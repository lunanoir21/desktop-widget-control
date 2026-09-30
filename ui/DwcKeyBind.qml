import QtQuick
import Quickshell
import Quickshell.Io
import "controls"

// The first-run tour's offer to bind a key to the editor (Hyprland only; other
// compositors get the lines to copy). The work is ui/scripts/bind.sh, so
// nothing is changed until the button is pressed.
Column {
    id: root

    readonly property bool hyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    // idle | busy | ok | exists | nohypr | taken | bad | fail
    property string result: "idle"
    property string keys: ""
    property string file: ""
    // "Choose key": the keys held right now, e.g. "SUPER_ALT" and "A"; Esc saves them.
    property bool capturing: false
    property string capMods: ""
    property string capKey: ""
    readonly property string capLabel: root.capKey === "" && root.capMods === "" ? ""
        : (root.capMods !== "" ? root.capMods.replace(/_/g, " + ") + " + " : "") + root.capKey

    readonly property string script: Qt.resolvedUrl("scripts/bind.sh").toString().replace("file://", "")

    spacing: 8

    signal captureEnded()
    onCapturingChanged: if (!root.capturing) root.captureEnded()

    function run(args) {
        root.result = "busy";
        proc.command = ["sh", root.script].concat(args);
        proc.running = true;
    }

    // Qt key -> the name Hyprland knows it by, or "" for a modifier or something we cannot bind.
    function keyName(k) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1);
        var named = {};
        named[Qt.Key_Space] = "space"; named[Qt.Key_Return] = "Return"; named[Qt.Key_Tab] = "Tab";
        named[Qt.Key_Comma] = "comma"; named[Qt.Key_Period] = "period"; named[Qt.Key_Slash] = "slash";
        named[Qt.Key_Semicolon] = "semicolon"; named[Qt.Key_Apostrophe] = "apostrophe";
        named[Qt.Key_Minus] = "minus"; named[Qt.Key_Equal] = "equal"; named[Qt.Key_Backslash] = "backslash";
        named[Qt.Key_Left] = "left"; named[Qt.Key_Right] = "right"; named[Qt.Key_Up] = "up"; named[Qt.Key_Down] = "down";
        return named[k] || "";
    }

    Process {
        id: proc
        command: ["sh", root.script]
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
        visible: !root.capturing && (root.result === "idle" || root.result === "busy" || root.result === "fail" || root.result === "taken" || root.result === "bad")
        spacing: 10
        DButton {
            primary: true
            enabled: root.result !== "busy"
            text: Str.t("tour.keyAdd")
            onClicked: root.run(["auto"])
        }
        DButton {
            enabled: root.result !== "busy"
            text: Str.t("tour.keyChoose")
            onClicked: { root.capMods = ""; root.capKey = ""; root.capturing = true; capture.forceActiveFocus(); }
        }
        DText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 12
            color: DwcTheme.muted
            text: root.result === "fail" ? Str.t("tour.keyFail")
                : root.result === "idle" ? Str.t("tour.keyAsk")
                : root.result === "taken" ? Str.t("tour.keyTaken")
                : root.result === "bad" ? Str.t("tour.keyBad") : ""
        }
    }

    // capture mode: whatever is held shows here; Esc saves it (Esc with nothing held cancels)
    Rectangle {
        id: capture
        visible: root.capturing
        width: parent.width
        height: 52
        radius: 10
        color: DwcTheme.alt
        border.width: 1
        border.color: DwcTheme.acc
        focus: root.capturing

        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Escape) {
                root.capturing = false;
                if (root.capKey !== "" && root.capMods !== "")
                    root.run([root.capMods, root.capKey]);
                return;
            }
            var mods = [];
            if (event.modifiers & Qt.MetaModifier) mods.push("SUPER");
            if (event.modifiers & Qt.ControlModifier) mods.push("CTRL");
            if (event.modifiers & Qt.AltModifier) mods.push("ALT");
            if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT");
            root.capMods = mods.join("_");
            var name = root.keyName(event.key);
            if (name !== "") root.capKey = name;
        }

        Column {
            anchors.centerIn: parent
            spacing: 2
            DText {
                anchors.horizontalCenter: parent.horizontalCenter
                face: "mono"
                font.pixelSize: 15
                color: DwcTheme.acc
                text: root.capLabel !== "" ? root.capLabel : "…"
            }
            DText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 11
                color: DwcTheme.muted
                text: Str.t("tour.keyCapture")
            }
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

    DText {
        visible: root.result === "nohypr"
        font.pixelSize: 12
        color: DwcTheme.muted
        text: Str.t("tour.keyNone")
    }
}
