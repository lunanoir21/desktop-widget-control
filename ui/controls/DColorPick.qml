import QtQuick
import ".."
import "../js/Modules.js" as Modules

// Colour choice: the four theme tokens, then a few fixed swatches. `current`
// is a token name ("primary") or a "#rrggbb" literal.
Flow {
    id: root

    property string current: "primary"
    signal picked(string value)

    spacing: 6

    readonly property var choices: {
        var out = [];
        for (var i = 0; i < Modules.colorTokens.length; i++)
            out.push(Modules.colorTokens[i].v);
        for (var j = 0; j < Modules.colorSwatches.length; j++)
            out.push(Modules.colorSwatches[j]);
        return out;
    }

    Repeater {
        model: root.choices
        delegate: Rectangle {
            required property string modelData
            readonly property bool on: modelData.toLowerCase() === String(root.current).toLowerCase()

            width: 21
            height: 21
            radius: 11
            color: DwcTheme.resolve(modelData)
            border.width: on ? 2 : 1
            border.color: on ? DwcTheme.fg : DwcTheme.lineStrong

            // A token that follows the theme gets a small dot so it reads as "theme colour".
            Rectangle {
                visible: modelData.charAt(0) !== "#"
                anchors.centerIn: parent
                width: 4
                height: 4
                radius: 2
                color: DwcTheme.dark ? DwcTheme.card : DwcTheme.fg
                opacity: 0.55
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(modelData)
            }
        }
    }
}
