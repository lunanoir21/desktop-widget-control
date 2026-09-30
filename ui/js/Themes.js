
// One entry per theme. Everything the widgets and the editor draw is taken
// from these fields, so adding a theme is adding one object here.
//
//   card   widget / panel surface          alt    raised surface inside a card
//   fg     primary text                    sub    secondary text
//   muted  tertiary text, captions         acc    the accent ("primary" colour)
//   onAcc  text drawn on top of acc        acc2   second series colour ("secondary")
//   track  empty part of bars and rings
//   dark   true when the surface is dark (decides scrim / shadow strength)
var list = [
    { id: "moss",     name: "Moss",     dark: true,  card: "#11120e", alt: "#1b1d16", fg: "#f3f2ea", sub: "#c4c4b8", muted: "#93948a", acc: "#b7e36a", onAcc: "#121d04", acc2: "#e0a458", track: "#26281f" },
    { id: "umbra",    name: "Umbra",    dark: true,  card: "#070707", alt: "#171717", fg: "#f5f2ec", sub: "#c1bdb5", muted: "#918d86", acc: "#eeeae2", onAcc: "#050505", acc2: "#a39e94", track: "#242424" },
    { id: "black",    name: "Black",    dark: true,  card: "#15161a", alt: "#22242a", fg: "#fafafa", sub: "#c6c8cd", muted: "#9498a2", acc: "#f2f3f5", onAcc: "#0b0c0f", acc2: "#9aa0ab", track: "#303239" },
    { id: "graphite", name: "Graphite", dark: true,  card: "#44474f", alt: "#52555e", fg: "#ffffff", sub: "#d4d6dc", muted: "#adb0b9", acc: "#f4f5f7", onAcc: "#24262b", acc2: "#c9ccd3", track: "#5d606a" },
    { id: "paper",    name: "Paper",    dark: false, card: "#ffffff", alt: "#ebedf0", fg: "#111318", sub: "#3f434b", muted: "#676c76", acc: "#181a1f", onAcc: "#ffffff", acc2: "#6b7280", track: "#dfe2e6" },
    { id: "sand",     name: "Sand",     dark: false, card: "#f8f1e7", alt: "#ebdfce", fg: "#2f2620", sub: "#544537", muted: "#7b6a58", acc: "#5c4433", onAcc: "#f8f1e7", acc2: "#a0856a", track: "#e2d4bf" },
    { id: "gold",     name: "Gold",     dark: true,  card: "#120d08", alt: "#221a10", fg: "#f8ecd8", sub: "#cdb896", muted: "#96836a", acc: "#f0b93c", onAcc: "#241a08", acc2: "#c9b48a", track: "#2d2215" },
    { id: "amber",    name: "Amber",    dark: true,  card: "#141110", alt: "#241c15", fg: "#f7ede0", sub: "#cdbba5", muted: "#978672", acc: "#ff9f1c", onAcc: "#241202", acc2: "#a9c2b2", track: "#2f251b" },
    { id: "crimson",  name: "Crimson",  dark: true,  card: "#130a0b", alt: "#241214", fg: "#f8e9ea", sub: "#d0b3b6", muted: "#9c7c7f", acc: "#e5484d", onAcc: "#2a0a0c", acc2: "#e0a458", track: "#321a1d" }
];

var defaultId = "moss";

function byId(id) {
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id)
            return list[i];
    return list[0];
}

function ids() {
    var out = [];
    for (var i = 0; i < list.length; i++)
        out.push(list[i].id);
    return out;
}

function exists(id) {
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id)
            return true;
    return false;
}
