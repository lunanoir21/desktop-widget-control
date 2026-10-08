
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
    { id: "crimson",  name: "Crimson",  dark: true,  card: "#130a0b", alt: "#241214", fg: "#f8e9ea", sub: "#d0b3b6", muted: "#9c7c7f", acc: "#e5484d", onAcc: "#2a0a0c", acc2: "#e0a458", track: "#321a1d" },
    { id: "ocean",     name: "Ocean",     dark: true, card: "#0b1118", alt: "#131c27", fg: "#eaf1f8", sub: "#b4c2d1", muted: "#8394a6", acc: "#6ab0f3", onAcc: "#07131f", acc2: "#c39bd3", track: "#1e2a38" },
    { id: "violet",    name: "Violet",    dark: true, card: "#100d17", alt: "#1b1626", fg: "#f1ecf8", sub: "#c3b9d2", muted: "#928aa3", acc: "#b69cf0", onAcc: "#140d24", acc2: "#f0a6c2", track: "#2a2238" },
    { id: "mint",      name: "Mint",      dark: true, card: "#0a1412", alt: "#12211e", fg: "#e8f5f1", sub: "#b1cdc6", muted: "#7fa097", acc: "#5cc8b4", onAcc: "#04201a", acc2: "#e6d36f", track: "#1c2f2a" },
    { id: "rose",      name: "Rose",      dark: true, card: "#170d11", alt: "#25151b", fg: "#f9eaee", sub: "#d3b4bd", muted: "#9f7f89", acc: "#f27ca1", onAcc: "#2b0916", acc2: "#f3c58b", track: "#36202a" },
    { id: "sunset",    name: "Sunset",    dark: true, card: "#150e0a", alt: "#251811", fg: "#fbeee3", sub: "#d6baa4", muted: "#a1856f", acc: "#ff7a45", onAcc: "#2a0f02", acc2: "#ffc15e", track: "#35241a" },
    { id: "dusk",      name: "Dusk",      dark: false, card: "#f4f1f8", alt: "#e6e0ef", fg: "#1d1830", sub: "#4a4262", muted: "#6e6687", acc: "#5b3fd1", onAcc: "#ffffff", acc2: "#c4457a", track: "#dcd5e8" },
    { id: "sky",       name: "Sky",       dark: false, card: "#f2f7fc", alt: "#e0ebf5", fg: "#0f2233", sub: "#3b5469", muted: "#557088", acc: "#1769c2", onAcc: "#ffffff", acc2: "#e07b00", track: "#d4e1ed" },
    { id: "matcha",    name: "Matcha",    dark: false, card: "#f3f6ec", alt: "#e2e8d4", fg: "#1c2412", sub: "#475536", muted: "#67775a", acc: "#3f7d1f", onAcc: "#ffffff", acc2: "#b8741a", track: "#d6dec5" },
    { id: "ink",       name: "Ink",       dark: true, card: "#0c0c0c", alt: "#1a1a1a", fg: "#f2f2f2", sub: "#c2c2c2", muted: "#8f8f8f", acc: "#ffffff", onAcc: "#000000", acc2: "#9a9a9a", track: "#262626" },
    { id: "chalk",     name: "Chalk",     dark: false, card: "#f6f6f6", alt: "#e6e6e6", fg: "#101010", sub: "#444444", muted: "#6a6a6a", acc: "#101010", onAcc: "#f6f6f6", acc2: "#7a7a7a", track: "#dcdcdc" },
    { id: "phosphor",  name: "Phosphor",  dark: true, card: "#040a05", alt: "#0b160d", fg: "#c8ffd0", sub: "#8fe09c", muted: "#5faa6c", acc: "#3dff6a", onAcc: "#021205", acc2: "#28b34a", track: "#123017" },
    { id: "termamber", name: "Terminal Amber", dark: true, card: "#0a0700", alt: "#171000", fg: "#ffd89a", sub: "#e0b05c", muted: "#a8803a", acc: "#ffb000", onAcc: "#1a1000", acc2: "#c98600", track: "#2e2000" },
    { id: "blueprint", name: "Blueprint", dark: true, card: "#04101a", alt: "#0a1c2c", fg: "#cdeeff", sub: "#8cc8e6", muted: "#5e97b5", acc: "#4fd0ff", onAcc: "#021622", acc2: "#2a8fb8", track: "#123049" },
    { id: "sepia",     name: "Sepia",     dark: false, card: "#f5ecdc", alt: "#e8dbc2", fg: "#2a1d0e", sub: "#5a4528", muted: "#7d6642", acc: "#3a2610", onAcc: "#f5ecdc", acc2: "#8a6a3c", track: "#dccdb0" }
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
