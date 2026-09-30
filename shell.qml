import QtQuick
import Quickshell
import "ui" as Dwc

// The entry point Quickshell loads. Run it on its own:
//
//     quickshell -p /path/to/desktop-widget-control
//
// or install it (./install.sh) and use `quickshell -c desktop-widget-control`.
// Inside a shell of your own, import "ui" and put one DwcHost {} in your root.
ShellRoot {
    Dwc.DwcHost {}
}
