import QtQuick
import QtQuick.Shapes
import "controls"
import "js/Themes.js" as Themes

// The little picture above each step of the first-run tour, drawn from plain
// shapes in the current theme. Animations only run while the tour is on screen.
Rectangle {
    id: art

    property string kind: "hello"

    radius: 16
    color: DwcTheme.alpha(DwcTheme.fg, 0.045)
    border.width: 1
    border.color: DwcTheme.line
    clip: true

    // a faint grid, the way the editor draws it
    Repeater {
        model: Math.ceil(art.width / 28)
        delegate: Rectangle { required property int index; x: index * 28; width: 1; height: art.height; color: DwcTheme.alpha(DwcTheme.fg, 0.05) }
    }
    Repeater {
        model: Math.ceil(art.height / 28)
        delegate: Rectangle { required property int index; y: index * 28; width: art.width; height: 1; color: DwcTheme.alpha(DwcTheme.fg, 0.05) }
    }

    // a card as the desktop draws one
    component MiniCard: Rectangle {
        radius: 12
        color: DwcTheme.card
        border.width: 1
        border.color: DwcTheme.line
    }

    // ---- hello: three widgets appear one after another ----
    Item {
        visible: art.kind === "hello"
        anchors.fill: parent
        property real tt: 0
        SequentialAnimation on tt {
            running: art.kind === "hello" && art.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 3; duration: 1500; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 2200 }
        }
        MiniCard {
            x: art.width / 2 - 215; y: 56; width: 140; height: 78
            opacity: Math.min(1, parent.tt); scale: 0.85 + 0.15 * Math.min(1, parent.tt)
            DText { anchors.centerIn: parent; face: "dots"; font.pixelSize: 34; font.weight: Font.Black; color: DwcTheme.acc; text: "21:59" }
        }
        MiniCard {
            x: art.width / 2 - 62; y: 56; width: 78; height: 78
            opacity: Math.max(0, Math.min(1, parent.tt - 1)); scale: 0.85 + 0.15 * Math.max(0, Math.min(1, parent.tt - 1))
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: DwcTheme.track; strokeWidth: 7; fillColor: "transparent"; PathAngleArc { centerX: 39; centerY: 39; radiusX: 26; radiusY: 26; startAngle: -90; sweepAngle: 359.9 } }
                ShapePath { strokeColor: DwcTheme.acc; strokeWidth: 7; capStyle: ShapePath.RoundCap; fillColor: "transparent"; PathAngleArc { centerX: 39; centerY: 39; radiusX: 26; radiusY: 26; startAngle: -90; sweepAngle: 230 } }
            }
        }
        MiniCard {
            x: art.width / 2 + 34; y: 56; width: 140; height: 78
            opacity: Math.max(0, Math.min(1, parent.tt - 2)); scale: 0.85 + 0.15 * Math.max(0, Math.min(1, parent.tt - 2))
            Row {
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: [16, 28, 40, 24, 34, 18, 30, 22]
                    delegate: Rectangle { required property int modelData; width: 7; height: modelData; radius: 3; anchors.bottom: parent.bottom; color: modelData > 32 ? DwcTheme.acc2 : DwcTheme.acc }
                }
            }
        }
    }

    // ---- edit: a key press opens the editor ----
    Item {
        visible: art.kind === "edit"
        anchors.fill: parent
        property real pulse: 0
        SequentialAnimation on pulse {
            running: art.kind === "edit" && art.visible
            loops: Animation.Infinite
            PauseAnimation { duration: 700 }
            NumberAnimation { from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 1600 }
            NumberAnimation { from: 1; to: 0; duration: 300 }
        }
        Row {
            x: 56; anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Repeater {
                model: ["SUPER", "G"]
                delegate: Rectangle {
                    required property string modelData
                    width: modelData.length > 1 ? 86 : 54; height: 54; radius: 10
                    color: DwcTheme.alt
                    border.width: 1; border.color: DwcTheme.lineStrong
                    y: parent.parent.pulse * 3
                    DText { anchors.centerIn: parent; face: "mono"; font.pixelSize: 15; text: modelData }
                }
            }
        }
        // the editor appearing on the right
        Item {
            x: art.width - 290; y: 26; width: 250; height: art.height - 52
            opacity: parent.pulse
            Rectangle { anchors.fill: parent; radius: 10; color: "transparent"; border.width: 1; border.color: DwcTheme.lineStrong }
            Rectangle { x: 10; y: 10; width: 120; height: 12; radius: 6; color: DwcTheme.acc }
            Rectangle { x: 10; y: 32; width: 86; height: 42; radius: 8; color: DwcTheme.card; border.width: 2; border.color: DwcTheme.acc }
            Rectangle { x: 104; y: 32; width: 60; height: 42; radius: 8; color: DwcTheme.card; border.width: 1; border.color: DwcTheme.line }
            Rectangle { x: 10; y: 82; width: 154; height: 34; radius: 8; color: DwcTheme.card; border.width: 1; border.color: DwcTheme.line }
            Rectangle { x: 176; y: 10; width: 64; height: parent.height - 20; radius: 8; color: DwcTheme.card; border.width: 1; border.color: DwcTheme.line }
        }
    }

    // ---- drag: a card travels from the library onto the grid ----
    Item {
        visible: art.kind === "drag"
        anchors.fill: parent
        Rectangle {
            x: 40; y: 22; width: 104; height: art.height - 44; radius: 10; color: DwcTheme.card; border.width: 1; border.color: DwcTheme.line
            Column {
                x: 10; y: 10; spacing: 8
                Repeater {
                    model: 3
                    delegate: Rectangle { required property int index; width: 84; height: 38; radius: 8; color: DwcTheme.alt; border.width: 1; border.color: DwcTheme.line
                        Rectangle { anchors.centerIn: parent; width: 40 + index * 8; height: 6; radius: 3; color: index === 0 ? DwcTheme.acc : DwcTheme.muted } }
                }
            }
        }
        // where it will land
        Rectangle { x: art.width - 230; y: 40; width: 140; height: 78; radius: 12; color: DwcTheme.alpha(DwcTheme.acc, 0.12); border.width: 2; border.color: DwcTheme.acc }
        Rectangle {
            id: ghost
            width: 140; height: 78; radius: 12; color: DwcTheme.card; border.width: 1; border.color: DwcTheme.lineStrong
            DText { anchors.centerIn: parent; face: "dots"; font.pixelSize: 30; font.weight: Font.Black; color: DwcTheme.acc; text: "21:59" }
            SequentialAnimation {
                running: art.kind === "drag" && art.visible
                loops: Animation.Infinite
                ParallelAnimation {
                    PropertyAction { target: ghost; property: "x"; value: 50 }
                    PropertyAction { target: ghost; property: "y"; value: 34 }
                    PropertyAction { target: ghost; property: "opacity"; value: 0.0 }
                }
                PauseAnimation { duration: 500 }
                NumberAnimation { target: ghost; property: "opacity"; to: 1; duration: 160 }
                ParallelAnimation {
                    NumberAnimation { target: ghost; property: "x"; to: art.width - 230; duration: 1100; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: ghost; property: "y"; to: 40; duration: 1100; easing.type: Easing.InOutCubic }
                }
                PauseAnimation { duration: 1300 }
            }
        }
    }

    // ---- style: one card, five looks ----
    Item {
        id: styleArt
        visible: art.kind === "style"
        anchors.fill: parent
        property int idx: 0
        readonly property var tones: [DwcTheme.acc, DwcTheme.acc2, "#6ab0f3", "#c39bd3", "#e5484d"]
        Timer { interval: 1100; repeat: true; running: art.kind === "style" && art.visible; onTriggered: styleArt.idx = (styleArt.idx + 1) % 5 }
        MiniCard {
            x: art.width / 2 - 90; y: 30; width: 180; height: 92
            DText { x: 14; y: 12; font.pixelSize: 12; color: DwcTheme.muted; text: "CPU" }
            DText { x: 14; y: 28; face: "display"; font.pixelSize: 26; font.weight: Font.DemiBold; color: styleArt.tones[styleArt.idx]; text: "14%" }
            Row {
                anchors { right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: 12 }
                spacing: 4
                Repeater {
                    model: [10, 16, 26, 14, 22, 34, 18]
                    delegate: Rectangle { required property int modelData; width: 6; height: modelData; radius: 3; anchors.bottom: parent.bottom; color: styleArt.tones[styleArt.idx] }
                }
            }
        }
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 18 }
            spacing: 12
            Repeater {
                model: 5
                delegate: Rectangle { required property int index; width: 22; height: 22; radius: 11; color: styleArt.tones[index]
                    border.width: index === styleArt.idx ? 3 : 0; border.color: DwcTheme.fg }
            }
        }
    }

    // ---- theme: the real swatches; click one ----
    Item {
        visible: art.kind === "theme"
        anchors.fill: parent
        Flow {
            anchors.centerIn: parent
            width: Math.min(art.width - 40, 9 * 52)
            spacing: 8
            Repeater {
                model: Themes.list
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: DwcStore.themeId === modelData.id
                    width: 44; height: 44; radius: 12
                    color: modelData.card
                    border.width: on ? 3 : 1
                    border.color: on ? DwcTheme.fg : DwcTheme.lineStrong
                    Rectangle { anchors.centerIn: parent; width: 16; height: 16; radius: 8; color: modelData.acc }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: DwcStore.setTheme(modelData.id) }
                }
            }
        }
    }

    // ---- done ----
    Item {
        visible: art.kind === "done"
        anchors.fill: parent
        Rectangle { x: art.width / 2 - 34; y: 26; width: 68; height: 68; radius: 34; color: DwcTheme.acc
            DIcon { anchors.centerIn: parent; name: "check"; size: 34; strokeWidth: 2.6; color: DwcTheme.onAcc } }
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
            spacing: 10
            Repeater {
                model: ["dwc toggle", "dwc help", "layout.json"]
                delegate: Rectangle { required property string modelData; height: 30; width: chipText.implicitWidth + 24; radius: 15; color: DwcTheme.alt; border.width: 1; border.color: DwcTheme.line
                    DText { id: chipText; anchors.centerIn: parent; face: "mono"; font.pixelSize: 12; color: DwcTheme.sub; text: modelData } }
            }
        }
    }
}
