# Architecture

Desktop Widget Control is one QML module (`ui/`) plus a two-line entry point (`shell.qml`). Nothing in it depends on any other shell, and nothing outside `ui/` is loaded at run time.

## The pieces

```
                        ┌───────────────┐
   IPC / keys ───────▶  │   DwcHost     │  one per shell; creates the surfaces, answers `desktopWidgets` IPC
                        └──────┬────────┘
            always             │              only while editing
   ┌───────────────────────────┴──────────────┐
   ▼                                          ▼
 DwcLayer  (per screen, layer Bottom)       DwcEditor (per screen, layer Overlay)
   │  DwcFrame ─ DwcCard ─ widgets/*.qml      │  grid, DwcHandle per widget,
   │                                          │  DwcLibrary, DwcInspector, drag preview
   └─────────────┬────────────────────────────┘
                 ▼
   DwcStore (layout, theme, language)   DwcData (shared system readers)   DwcTheme   Str
```

The **layer** draws; the **editor** only holds handles over what the layer draws. A drag in the editor changes the store, the store notifies, and the layer's widget glides to its new place. That is why what you see while editing is what is saved, and why the desktop never has to be rebuilt to open or close the editor.

### Singletons

| | Holds | Notes |
|---|---|---|
| `DwcStore` | `order`, `items`, theme, language, cell size, editor state | Persists to `layout.json`. Records are *replaced*, never edited in place: a QML binding on `items[id]` only notices a change when it is handed a new object (`patch()`). |
| `DwcData` | CPU, memory, network, temperature, disk, the clock | Reference-counted: a source runs only while at least one `DwcNeed` asks for it, at the fastest interval asked. Exposes helpers for formatting bytes and rates. |
| `DwcTheme` | colours (from `js/Themes.js`), fonts | `resolve("primary")` turns an option value into a colour. |
| `Str` | interface language, `t(key)`, `pick({en,tr})`, `fmt(pattern, date)` | Reading `lang` inside `t()` is what makes bindings re-evaluate on a language change. |

### Pure logic

`ui/js/` holds everything that needs no QML engine and is unit-tested (plain scripts, not `.pragma library`, so a hot reload picks up changes to them):

- `Layout.js`: grid maths (overlap, `canPlace`, `findFree`, `nearestPreset`, bounds, ids) and the size presets S/M/L/W.
- `Modules.js`: the **catalogue**: each module's type, category, sizes, source file and option schema, plus the defaults and merge helpers.
- `Themes.js`, `Strings.js`, `Icons.js`: data.

## `layout.json`

```json
{
  "version": 1,
  "theme": "moss",
  "language": "auto",
  "cell": 40,
  "widgets": [
    { "id": "media-1", "type": "media", "size": "M", "x": 38, "y": 17,
      "screen": "", "locked": false,
      "cfg": { "art": true }, "st": { "radius": 20 } }
  ]
}
```

- `x`, `y` are grid cells. `size` is a preset key the module allows.
- `screen` is an output name; `""` means the primary one.
- `cfg` holds only what differs from the module's defaults or was set by the user; unknown keys are dropped and missing ones filled on load, so adding an option to a module never breaks an old file.
- `st` is the appearance (`background`, `bgOpacity`, `radius`, `padding`, `shadow`, `border`), merged the same way.
- The file is watched. Saving it by hand reloads it; the store ignores the echo of its own writes by comparing the text it last wrote. A file that does not parse is copied to `layout.json.bad` and replaced by the first-run layout.

## A widget's life

1. `DwcLayer.sync()` lists the ids on its screen; a `Repeater` makes a `DwcFrame` for each.
2. `DwcFrame` positions itself from the record (`x * cell`) and hands `cfg` and `st` to a `DwcCard`. It only passes them on when their JSON differs, so editing one widget does not make its neighbours re-layout.
3. `DwcCard` draws the background, the two-rectangle shadow and loads the module's file into the padded area with a `Loader`, then keeps `cfg` and `sizeKey` up to date on the loaded item.
4. The module (a `DwcWidget`) draws itself from `cfg` and whatever it reads from `DwcData`, and declares what it needs with `DwcNeed { source: "cpu"; interval: 2000 }`. When the widget is destroyed, `DwcNeed` releases the source.

The library's thumbnails are the same `DwcCard` with `preview: true` and default options, scaled down. There is no second set of "preview art" to keep in step.

## Input

The desktop layer is a full-screen surface whose input region is the union of a few rectangles: the widgets whose catalogue entry says `interactive: true`. `DwcLayer` holds sixteen `DwcMaskRegion` slots bound to those rectangles; unused slots are empty. Everything else falls through to the windows and wallpaper underneath.

The editor is a separate overlay surface with exclusive keyboard focus on the primary screen, so keys go to it and nowhere else while it is open.

## Editing

- **Drag.** `DwcHandle` converts pointer movement to whole cells and calls `DwcStore.move`, which refuses a spot that is off-screen or taken; the widget simply stays at its last valid cell.
- **Resize.** The grip maps the pointer to a cols × rows footprint and picks the nearest preset the module allows (`nearestPreset`); `setSize` keeps the widget where it is or finds the nearest free spot.
- **Library drag.** A card starts a drag after 8 px; the editor draws the widget under the pointer and the snapped landing cell (green when free, red when not). Dropping over a panel cancels; elsewhere it calls `add`, which places the widget at the nearest free cell.
- **Panels.** The library and the inspector slide off-screen while anything is being dragged (`busy`), so a drop can land where a panel was. The inspector takes the side away from the selected widget, and two panels never share a side; the bar at the top and Tab open, close and hide them.
- **Inspector.** Built from the schema: `DwcOptionRow` picks a control by the option's `type`. The control emits a change, the store saves it, and the value comes back through the binding; a control never holds state of its own.

## Data sources

| Source | Read from | Default rate |
|---|---|---|
| `clock`, `clock.sec` | Quickshell `SystemClock` (minute / second precision) | |
| `cpu` | `/proc/stat` | 2 s |
| `mem` | `/proc/meminfo` | 2 s |
| `net` | `/proc/net/dev` | 1 s |
| `temp` | `hwmon` (`k10temp`, `coretemp`, …) or a thermal zone, found once | 3 s |
| `disk` | `df` | 60 s |
| `spectrum` | `cava` (raw ascii, 24 bands, 30 fps), only while a media widget with the visualizer is playing; skipped if cava is missing | 33 ms |

The media player reads Quickshell's MPRIS service directly; the weather widget and the world clock run `curl` and `date` themselves (arguments are passed as an argv, never spliced into a shell string).

## Debugging

- `DWC_CONFIG_DIR=/some/dir` keeps your real layout untouched.
- `DWC_LAYER=overlay` draws the widgets above every window so they can be screenshotted; `tools/capture.sh` does the whole thing on an empty workspace.
- `tools/pointer.py` is a virtual mouse (needs write access to `/dev/uinput`) for driving drags and resizes by hand: `tools/pointer.py drag X1 Y1 X2 Y2`.
- `tools/showcase.py` writes a layout with every module at every size.
