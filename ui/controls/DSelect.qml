import QtQuick
import QtQuick.Controls.Basic
import ".."

// A drop-down: model is [{ v, label }], `current` is a v.
Item {
    id: root

    property var model: []
    property var current: null
    signal picked(var value)

    implicitWidth: 140
    implicitHeight: 28

    readonly property string currentLabel: {
        for (var i = 0; i < root.model.length; i++)
            if (root.model[i].v === root.current)
                return root.model[i].label;
        return "";
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: pop.opened || mouse.containsMouse ? DwcTheme.alpha(DwcTheme.fg, 0.10) : DwcTheme.alt
        border.width: 1
        border.color: pop.opened ? DwcTheme.acc : DwcTheme.line

        DText {
            anchors { left: parent.left; right: chev.left; leftMargin: 10; rightMargin: 4; verticalCenter: parent.verticalCenter }
            text: root.currentLabel
        }
        DIcon {
            id: chev
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            name: "chevdown"
            size: 12
            color: DwcTheme.sub
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pop.opened ? pop.close() : pop.open()
        }
    }

    Popup {
        id: pop
        y: root.height + 4
        width: Math.max(root.width, 150)
        height: Math.min(list.contentHeight + 8, 240)
        padding: 4
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            radius: 10
            color: DwcTheme.card
            border.width: 1
            border.color: DwcTheme.lineStrong
        }

        contentItem: ListView {
            id: list
            clip: true
            model: root.model
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: 28
                radius: 7
                color: hover.containsMouse ? DwcTheme.hover : "transparent"

                DText {
                    anchors { left: parent.left; right: tick.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: modelData.label
                    color: modelData.v === root.current ? DwcTheme.acc : DwcTheme.fg
                }
                DIcon {
                    id: tick
                    visible: modelData.v === root.current
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    name: "check"
                    size: 12
                    color: DwcTheme.acc
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.picked(modelData.v);
                        pop.close();
                    }
                }
            }
        }
    }
}
