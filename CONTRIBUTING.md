# Contributing

Thanks for looking. The short version:

1. **Try it first:** `make sandbox` runs the project against a throwaway config directory, so your own layout is never touched. `make showcase` shows every module at every size.
2. **Adding a widget** is one QML file plus one entry in `ui/js/Modules.js`; see [docs/writing-a-widget.md](docs/writing-a-widget.md). The library, the inspector and the tests pick it up.
3. **Run the tests:** `tests/run.sh` (Qt 6's `qmltestrunner` and Python 3; no compositor needed). CI runs the same, plus ShellCheck and an end-to-end run of the installer.
4. **Both languages:** every string has an English and a Turkish entry. The tests fail when they drift.
5. **Screenshots** go through `tools/capture.sh` (it uses an empty workspace so none of your windows end up in the picture).

`AGENTS.md` has the project's conventions in full, written for people and for coding agents alike.

Bugs and ideas: open an issue with the template. For anything big, an issue first saves everyone time.
