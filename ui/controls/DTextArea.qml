import QtQuick
import ".."

// Several lines of text. Emits committed(text) when focus leaves.
Rectangle {
    id: root

    property string text: ""
    property int maxLength: 20000
    signal committed(string text)

    implicitWidth: 170
    implicitHeight: 96
    radius: 8
    color: DwcTheme.alt
    border.width: 1
    border.color: edit.activeFocus ? DwcTheme.acc : DwcTheme.line

    Flickable {
        id: flick
        anchors { fill: parent; margins: 8 }
        contentWidth: width
        contentHeight: edit.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: edit
            width: flick.width
            color: DwcTheme.fg
            selectionColor: DwcTheme.acc
            selectedTextColor: DwcTheme.onAcc
            font.family: DwcTheme.body
            font.pixelSize: 12
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            text: root.text
            onTextChanged: if (edit.length > root.maxLength) edit.remove(root.maxLength, edit.length)
            onActiveFocusChanged: if (!activeFocus) root.committed(edit.text)
            Keys.onEscapePressed: event => { edit.focus = false; event.accepted = true; }
        }
    }

    onTextChanged: if (!edit.activeFocus) edit.text = root.text
}
