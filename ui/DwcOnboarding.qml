import QtQuick
import Quickshell
import Quickshell.Wayland
import "controls"
import "js/Strings.js" as Strings

// First run: what this is, how to open the editor, how to fill the desktop,
// how to change a widget, a theme. One screen at a time, each sliding in from
// the side it comes from. Enter goes forward, Esc skips. Finishing or skipping
// marks it seen; `dwc tour` shows it again.
PanelWindow {
    id: root

    readonly property int pad: 40
    readonly property int cardW: 640
    readonly property int cardH: 520
    readonly property int steps: 6
    readonly property var kinds: ["hello", "edit", "drag", "style", "theme", "done"]
    property int step: DwcStore.tourStart
    property bool closing: false

    WlrLayershell.namespace: "desktop-widget-control-tour"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    color: "transparent"

    anchors { top: true; left: true }
    margins {
        left: Math.max(0, ((screen ? screen.width : 1920) - cardW) / 2 - pad)
        top: Math.max(0, ((screen ? screen.height : 1080) - cardH) / 2 - pad)
    }
    implicitWidth: cardW + pad * 2
    implicitHeight: cardH + pad * 2
    mask: Region { item: card }

    function go(to) {
        if (to < 0 || to >= steps || to === step)
            return;
        var dir = to > step ? 1 : -1;
        step = to;
        content.x = dir * 28;
        content.opacity = 0;
        enter.restart();
    }

    function forward(skip) {
        if (skip === true || step === steps - 1) {
            closing = true;
            closeAnim.start();
        } else {
            go(step + 1);
        }
    }

    Component.onCompleted: {
        content.opacity = 0;
        fadeIn.start();
        enter.start();
    }

    NumberAnimation { id: fadeIn; target: card; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
    ParallelAnimation {
        id: enter
        NumberAnimation { target: content; property: "x"; to: 0; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 200 }
    }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 180 }
        ScriptAction { script: DwcStore.finishTour() }
    }

    // soft shadow
    Rectangle { x: root.pad - 2; y: root.pad + 6; width: root.cardW + 4; height: root.cardH + 4; radius: 26; color: Qt.rgba(0, 0, 0, 0.22) }

    Rectangle {
        id: card
        x: root.pad
        y: root.pad
        width: root.cardW
        height: root.cardH
        radius: 24
        color: DwcTheme.card
        border.width: 1
        border.color: DwcTheme.lineStrong
        clip: true

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onReturnPressed: root.forward(false)
            Keys.onEnterPressed: root.forward(false)
            Keys.onRightPressed: root.go(root.step + 1)
            Keys.onLeftPressed: root.go(root.step - 1)
            Keys.onEscapePressed: root.forward(true)
        }

        Item {
            id: content
            width: parent.width
            height: parent.height - 84

            DwcTourArt {
                id: art
                x: 28
                y: 28
                width: parent.width - 56
                height: 200
                kind: root.kinds[root.step]
            }

            Column {
                x: 36
                y: 252
                width: parent.width - 72
                spacing: 10

                DText {
                    width: parent.width
                    face: "display"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    text: Str.t("tour.t" + root.step)
                }
                DText {
                    width: parent.width
                    font.pixelSize: 14
                    color: DwcTheme.sub
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    lineHeight: 1.25
                    text: Str.t("tour.p" + root.step)
                }
                // the language, offered where it matters: on the first screen
                DSegmented {
                    visible: root.step === 0
                    model: [{ v: "auto", label: Str.t("set.langAuto") }].concat(Strings.languages)
                    current: DwcStore.language
                    onPicked: v => DwcStore.setLanguage(v)
                }
                // the two lines that open the editor from a key
                DwcKeyBind { id: keyBind; onCaptureEnded: keys.forceActiveFocus(); visible: root.step === 1 && keyBind.hyprland }
                Column {
                    visible: root.step === 1 && !keyBind.hyprland
                    spacing: 6
                    Repeater {
                        model: ["bind = SUPER, G, exec, dwc toggle   # Hyprland", "bindsym $mod+g exec dwc toggle   # Sway"]
                        delegate: Rectangle {
                            required property string modelData
                            height: 28; width: line.implicitWidth + 24; radius: 8; color: DwcTheme.alt; border.width: 1; border.color: DwcTheme.line
                            DText { id: line; anchors.centerIn: parent; face: "mono"; font.pixelSize: 11; color: DwcTheme.sub; text: modelData }
                        }
                    }
                }
            }
        }

        // footer: progress dots, skip, back, next
        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 84

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: DwcTheme.line }

            Row {
                anchors { left: parent.left; leftMargin: 36; verticalCenter: parent.verticalCenter }
                spacing: 7
                Repeater {
                    model: root.steps
                    delegate: Rectangle {
                        required property int index
                        width: index === root.step ? 22 : 7
                        height: 7
                        radius: 3.5
                        color: index === root.step ? DwcTheme.acc : DwcTheme.alpha(DwcTheme.fg, 0.2)
                        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        MouseArea { anchors { fill: parent; margins: -4 } cursorShape: Qt.PointingHandCursor; onClicked: root.go(index) }
                    }
                }
            }

            Row {
                anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                spacing: 8
                DButton { visible: root.step < root.steps - 1; text: Str.t("tour.skip"); onClicked: root.forward(true) }
                DButton { visible: root.step > 0; text: Str.t("tour.back"); onClicked: root.go(root.step - 1) }
                DButton {
                    primary: true
                    text: root.step === root.steps - 1 ? Str.t("tour.done") : Str.t("tour.next")
                    onClicked: root.forward(false)
                }
            }
        }
    }
}
