import QtQuick
import ".."

// One-line text input. Emits committed(text) on Enter or when focus leaves.
Rectangle {
    id: root

    property string text: ""
    property string placeholder: ""
    signal committed(string text)
    signal edited(string text)

    implicitWidth: 170
    implicitHeight: 28
    radius: 8
    color: DwcTheme.alt
    border.width: 1
    border.color: input.activeFocus ? DwcTheme.acc : DwcTheme.line

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
        verticalAlignment: TextInput.AlignVCenter
        color: DwcTheme.fg
        selectionColor: DwcTheme.acc
        selectedTextColor: DwcTheme.onAcc
        font.family: DwcTheme.body
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        text: root.text

        onEditingFinished: root.committed(input.text)
        onAccepted: input.focus = false
        onTextEdited: root.edited(input.text)
        Keys.onEscapePressed: event => { input.focus = false; event.accepted = true; }
    }

    // Keep showing the stored value unless the user is typing.
    onTextChanged: if (!input.activeFocus) input.text = root.text

    DText {
        visible: input.text === "" && !input.activeFocus
        anchors { left: parent.left; right: parent.right; leftMargin: 9; rightMargin: 9; verticalCenter: parent.verticalCenter }
        text: root.placeholder
        color: DwcTheme.muted
    }
}
