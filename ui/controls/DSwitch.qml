import QtQuick
import ".."

// On/off switch. Emits toggled(value); it does not flip itself, the owner
// sets `checked` (so it always shows what is really stored).
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 34
    implicitHeight: 20
    radius: 10
    color: checked ? DwcTheme.acc : DwcTheme.alt
    border.width: 1
    border.color: checked ? DwcTheme.acc : DwcTheme.line

    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        y: 2
        x: root.checked ? parent.width - width - 2 : 2
        color: root.checked ? DwcTheme.onAcc : DwcTheme.muted
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
