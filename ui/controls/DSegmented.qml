import QtQuick
import ".."

// A row of mutually exclusive choices: model is [{ v, label }], `current` is a v.
Rectangle {
    id: root

    property var model: []
    property var current: null

    signal picked(var value)

    implicitHeight: 28
    implicitWidth: row.implicitWidth + 4
    radius: 9
    color: DwcTheme.alt

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.model
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData.v === root.current

                height: root.height - 4
                width: lbl.implicitWidth + 20
                radius: 7
                color: on ? DwcTheme.acc : (hover.containsMouse ? DwcTheme.hover : "transparent")

                DText {
                    id: lbl
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.on ? DwcTheme.onAcc : DwcTheme.sub
                    font.weight: parent.on ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.v)
                }
            }
        }
    }
}
