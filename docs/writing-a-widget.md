# Writing a widget

A module is one QML file in `ui/widgets/` and one entry in `ui/js/Modules.js`. The library, the inspector, the defaults and the tests all read that entry, so there is no editor code to touch.

This walks through a small one: a **Uptime** widget.

## 1. The file

`ui/widgets/Uptime.qml`:

```qml
import QtQuick
import Quickshell.Io
import ".."
import "../controls"

DwcWidget {
    id: root

    property string text: "…"

    // Ask once a minute; the process below is the only cost.
    DwcNeed { source: "clock"; interval: 60000 }
    readonly property int minuteKey: DwcData.now.getMinutes()
    onMinuteKeyChanged: proc.running = true
    Component.onCompleted: proc.running = true

    Process {
        id: proc
        command: ["uptime", "-p"]
        stdout: StdioCollector { onStreamFinished: root.text = text.trim() }
    }

    DText {
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        face: "display"
        // Scale with the card, never with a fixed pixel size.
        font.pixelSize: Math.round(root.height * 0.22)
        color: root.tone("color")       // the option defined below
        text: root.text
    }
}
```

What you get from `DwcWidget`:

| | |
|---|---|
| `cfg` | the widget's options, defaults filled in; read with `root.opt("key", fallback)` |
| `tone("key")` | an option holding a colour choice → a colour |
| `sizeKey`, `small`, `cols`, `rows` | the size preset, so one file can lay out differently when small |
| `preview` | true in a library thumbnail: do not start anything real (no network, no clicks) |
| `wid` | the store id, for a widget that writes back (`DwcStore.setCfg(root.wid, key, value)`) |

The item is sized to the card's padded content area, so use `width` and `height` and anchors, not absolute numbers. Use `DwcTheme` for every colour (`DwcTheme.fg`, `.sub`, `.muted`, `.acc`, `.track`…) so it follows the theme, and `DText` for text (`face`: `"body"`, `"display"`, `"mono"`, `"serif"`, `"dots"`).

## 2. The catalogue entry

In `ui/js/Modules.js`, add to `modules`:

```js
{
    type: "uptime", category: "system", name: T("Uptime", "Çalışma süresi"),
    sizes: ["S", "M"], size: "M", interactive: false, source: "widgets/Uptime.qml",
    opts: [
        color("color", "primary")
    ]
},
```

- `type` is the id used in `layout.json` and by `dwc add uptime`.
- `sizes` are the presets it allows; `size` is the default and must be one of them.
- `interactive: true` only if it has buttons: it makes the widget's rectangle take the pointer.
- Every option needs `key`, `type` (`toggle`, `select`, `range`, `color`, `text`, `lines`), a `label` made with `T(en, tr)` and a default `def`. `select` needs `choices`, `range` needs `min`, `max` and `step`.

## 3. Data

If you need a number many widgets might want (another sensor, say), add a source to `ui/DwcData.qml` the way `cpu` is done: a `Timer` with `running: root.active("x")` and an interval from `root.interval("x")`, so it stops when nobody asks. Then the widget says `DwcNeed { source: "x"; interval: 2000 }`. If it is private to the widget, as above, keep it in the widget.

## 4. Check it

```sh
tests/run.sh                      # the catalogue checks catch a missing file, a bad default, a missing translation
make showcase                     # every module at every size; look at yours
dwc add uptime                    # with an instance running
```

Add your strings to both languages in `ui/js/Strings.js` if the widget has any of its own (the tests fail when `en` and `tr` differ), and a line to `CHANGELOG.md`.
