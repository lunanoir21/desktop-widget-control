
// Icons as SVG path data on a 20×20 grid, drawn by controls/DIcon.qml. Stroke
// icons share one weight; the four transport icons are meant to be filled.
var paths = {
    plus:      "M10 4v12M4 10h12",
    x:         "M5 5l10 10M15 5L5 15",
    trash:     "M4 6h12M8 6V4h4v2M6 6l.7 10h6.6L14 6",
    copy:      "M7 7h9v9H7zM4 13V4h9",
    lock:      "M5 9h10v7H5zM7 9V6.5a3 3 0 0 1 6 0V9",
    unlock:    "M5 9h10v7H5zM7 9V6.5a3 3 0 0 1 5.6-1.5",
    search:    "M9 3.5a5.5 5.5 0 1 0 0 11a5.5 5.5 0 1 0 0-11zM13.2 13.2L17 17",
    chevdown:  "M6 8l4 4 4-4",
    chevright: "M8 6l4 4-4 4",
    check:     "M4 10.5l4 4 8-9",
    grid:      "M3 3h14v14H3zM3 10h14M10 3v14",
    reset:     "M4 10a6 6 0 1 0 2-4.5M4 4v3.5h3.5",
    gear:      "M10 7a3 3 0 1 0 0 6a3 3 0 1 0 0-6zM10 2.5v2M10 15.5v2M2.5 10h2M15.5 10h2M4.7 4.7l1.4 1.4M13.9 13.9l1.4 1.4M4.7 15.3l1.4-1.4M13.9 6.1l1.4-1.4",
    prev:      "M5 5h2v10H5zM15 5v10l-8-5z",
    next:      "M13 5h2v10h-2zM5 5v10l8-5z",
    play:      "M7 4.5v11l9-5.5z",
    pause:     "M6 5h3v10H6zM11 5h3v10h-3z",
    music:     "M8 15V5l8-2v10M8 15a2 2 0 1 1-4 0a2 2 0 0 1 4 0zM16 13a2 2 0 1 1-4 0a2 2 0 0 1 4 0z",
    sun:       "M10 6.6a3.4 3.4 0 1 0 0 6.8a3.4 3.4 0 1 0 0-6.8zM10 2.5v2M10 15.5v2M2.5 10h2M15.5 10h2M4.7 4.7l1.4 1.4M13.9 13.9l1.4 1.4M4.7 15.3l1.4-1.4M13.9 6.1l1.4-1.4",
    partly:    "M13.5 3v1.5M17.6 6.4l-1.1 1M18.5 10.5H17M9.4 6.4l1.1 1M13.5 6.6a3 3 0 0 1 2.9 3.7M5.5 16a3.2 3.2 0 0 1 0-6.4a4.2 4.2 0 0 1 8 1.3a2.6 2.6 0 0 1-.4 5.1z",
    cloud:     "M5.5 15a3.5 3.5 0 0 1 0-7a4.5 4.5 0 0 1 8.6 1.4A2.8 2.8 0 0 1 14 15z",
    rain:      "M5.5 12.5a3.5 3.5 0 0 1 0-7a4.5 4.5 0 0 1 8.6 1.4A2.8 2.8 0 0 1 14 12.5zM7 15l-1 2.5M11 15l-1 2.5M15 15l-1 2.5",
    snow:      "M5.5 12.5a3.5 3.5 0 0 1 0-7a4.5 4.5 0 0 1 8.6 1.4A2.8 2.8 0 0 1 14 12.5zM7 15.5h.01M10 17h.01M13 15.5h.01",
    fog:       "M3 7h14M3 10.5h14M5 14h10",
    storm:     "M5.5 12.5a3.5 3.5 0 0 1 0-7a4.5 4.5 0 0 1 8.6 1.4A2.8 2.8 0 0 1 14 12.5zM10.5 12l-2 3.5h3l-2 3",
    pin:       "M10 17s5-4.6 5-8.5a5 5 0 0 0-10 0C5 12.4 10 17 10 17zM10 6.8a1.8 1.8 0 1 0 0 3.6a1.8 1.8 0 1 0 0-3.6z",
    note:      "M5 3h10v14H5zM8 7h4M8 10h4"
};

function path(name) {
    return paths[name] || "";
}
