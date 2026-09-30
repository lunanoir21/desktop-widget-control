# Working on this project

Desktop widgets and their editor for Quickshell. The QML is the product; there is no build step, Quickshell reloads the files on save. This file is the contract for anyone (human or agent) changing things here.

## Shape of the code

- `ui/` is the whole module and must stay **self-contained**: nothing in it may reach outside its own folder, import another shell's files, or contain a path that belongs to one machine (a test checks for the last one). The project has to run for anyone with only Quickshell installed.
- Pure logic (grid maths, the catalogue, themes, strings) lives in `ui/js/` as plain script files so it can be unit-tested without a QML engine. They are deliberately **not** `.pragma library`: Quickshell keeps library scripts cached across a hot reload, so a change to the catalogue (a new option, say) would not show up until the whole shell was restarted. Keep new logic there when it does not need the scene.
- A module is `ui/widgets/X.qml` plus one entry in `ui/js/Modules.js`. Do not special-case a module in the editor; if the inspector cannot express an option, extend the option *types* so every module benefits.
- The store replaces records (`DwcStore.patch`) instead of mutating them: a QML binding on `items[id]` does not see an in-place change.
- Data sources run only while a widget asks for them (`DwcNeed`). A new poller must follow that, and widgets must not start `Process`es or `Timer`s that run when nothing is visible.
- Sizes scale with the card (`root.height * 0.2`), never a fixed pixel size; every module has to look right at each size it lists.

## Before every commit

1. **Tests:** `tests/run.sh` must pass. Add a test with the change when it touches `ui/js/` or the file layout.
2. **Both languages:** every string has an `en` and a `tr` entry (`ui/js/Strings.js`, option labels via `T(en, tr)`). The tests fail when they drift.
3. **Changelog:** add to the top entry of `CHANGELOG.md` in terms of what it does for the person using it.
4. **Look at it.** Run `make showcase` (every module at every size) and, when the editor changed, open it.
5. **Screenshots** with `tools/capture.sh`, never a raw `grim` of the working screen: it starts its own instance, goes to an empty workspace so none of your windows are in the picture, and comes back. Use an empty workspace for any screenshot of the desktop.

## Conventions

- Comments explain *why* (a quirk of Quickshell, a decision), not what the next line does.
- Colours come from `DwcTheme`; text is `DText`; icons are `DIcon` paths in `js/Icons.js` (20×20 grid, one stroke weight). No emoji in the interface.
- The names `left`, `top`, `state` and similar are already properties of `Item`; a widget property with one of those names fails with "Cannot override FINAL property".
- Never hide or destroy an item that holds the pointer grab (a card being dragged): the drag is cancelled half way and the full-screen editor is left waiting for a release that never comes. Keep it visible, and handle `onCanceled` wherever a drag is started.
- `DWC_CONFIG_DIR` points the project at a scratch directory; always use it when testing so a real layout is never touched.
