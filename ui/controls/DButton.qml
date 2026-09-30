import QtQuick
import ".."

// A push button: text, an icon, or both. `primary` fills with the accent,
// `danger` tints the label.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    property bool active: false       // a toggled-on look for icon buttons
    property bool enabled: true

    signal clicked()

    implicitHeight: 32
    implicitWidth: row.implicitWidth + (text !== "" ? 28 : 20)
    radius: height / 2
    opacity: enabled ? 1 : 0.4

    readonly property color ink: primary ? DwcTheme.onAcc : (danger ? DwcTheme.danger : DwcTheme.fg)

    color: primary ? DwcTheme.acc
        : (active ? DwcTheme.alpha(DwcTheme.acc, 0.22) : (mouse.containsMouse ? DwcTheme.hover : "transparent"))
    border.width: primary || active ? 0 : 1
    border.color: DwcTheme.line

    Behavior on color { ColorAnimation { duration: 110 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        DIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            color: root.ink
            size: 15
        }
        DText {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.ink
            font.weight: root.primary ? Font.DemiBold : Font.Medium
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
