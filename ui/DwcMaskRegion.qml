import Quickshell

// One slot of the desktop layer's input mask: the rectangle of one widget
// that has buttons in it, or nothing at all when `r` is null.
Region {
    property var r: null

    x: r ? r.x : 0
    y: r ? r.y : 0
    width: r ? r.w : 0
    height: r ? r.h : 0
}
