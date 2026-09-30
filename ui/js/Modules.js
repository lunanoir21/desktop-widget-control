
// The widget catalogue as plain data. The library panel, the inspector, the
// store's defaults and the tests all read this one list, so a new module is a
// QML file in ../widgets plus one entry here; no editor code changes.
//
// Every option becomes a control in the inspector:
//   toggle   on / off
//   select   one of `choices` ({ v, label })
//   range    a slider, min..max in `step`s
//   color    a theme colour token or a fixed swatch
//   text     one line
//   when: { key, eq }  shows the option only while another option has that value
//   lines    several lines
//   place    a country + city picker (Open-Meteo); the value is { name, lat, lon, … } or null
// Labels are { en, tr } pairs (see T).

function T(en, tr) {
    return { en: en, tr: tr || en };
}

var colorTokens = [
    { v: "primary",   label: T("Primary", "Birincil") },
    { v: "secondary", label: T("Secondary", "İkincil") },
    { v: "text",      label: T("Text", "Yazı") },
    { v: "muted",     label: T("Muted", "Soluk") }
];

// Fixed swatches offered next to the theme tokens.
var colorSwatches = ["#e0a458", "#e5484d", "#6ab0f3", "#c39bd3", "#5cc8b4"];

var categories = [
    { id: "clock",  name: T("Clock", "Saat") },
    { id: "system", name: T("System", "Sistem") },
    { id: "media",  name: T("Media & tools", "Medya ve araçlar") }
];

// Options every widget has; stored per widget under `st`.
var styleOptions = [
    { key: "background", type: "toggle", label: T("Background", "Arka plan"), def: true },
    { key: "bgOpacity",  type: "range",  label: T("Opacity", "Opaklık"), def: 0.85, min: 0, max: 1, step: 0.05 },
    { key: "radius",     type: "range",  label: T("Radius", "Yarıçap"), def: 16, min: 0, max: 32, step: 1 },
    { key: "padding",    type: "range",  label: T("Padding", "Dolgu"), def: 14, min: 0, max: 32, step: 1 },
    { key: "shadow",     type: "toggle", label: T("Shadow", "Gölge"), def: true },
    { key: "border",     type: "toggle", label: T("Outline", "Çerçeve"), def: false }
];

var fmtChoices = [
    { v: "24", label: T("24 hour", "24 saat") },
    { v: "12", label: T("12 hour", "12 saat") }
];
var dateChoices = [
    { v: "none",  label: T("None", "Yok") },
    { v: "short", label: T("Short", "Kısa") },
    { v: "long",  label: T("Long", "Uzun") }
];
var intervalChoices = [
    { v: 1, label: T("1 s", "1 sn") },
    { v: 2, label: T("2 s", "2 sn") },
    { v: 5, label: T("5 s", "5 sn") }
];

function color(key, def, label, when) {
    var o = { key: key, type: "color", label: label || T("Colour", "Renk"), def: def };
    if (when)
        o.when = when;
    return o;
}

var modules = [
    // ---- clocks ----
    {
        type: "clock-led", category: "clock", name: T("LED pixel", "LED piksel"),
        sizes: ["M", "L", "W"], size: "M", interactive: false, source: "widgets/ClockLed.qml",
        opts: [
            { key: "design", type: "select", label: T("Style", "Stil"), def: "classic", choices: [
                { v: "classic", label: T("Classic", "Klasik") },
                { v: "ring",    label: T("Ring", "Halka") },
                { v: "strip",   label: T("Day strip", "Gün şeridi") }
            ] },
            { key: "ringOf",  type: "select", label: T("Ring shows", "Halka neyi gösterir"), def: "seconds",
              when: { key: "design", eq: "ring" }, choices: [
                { v: "seconds", label: T("Seconds", "Saniyeyi") },
                { v: "minutes", label: T("Minutes of the hour", "Saatin dakikasını") }
            ] },
            { key: "format",  type: "select", label: T("Format", "Biçim"), def: "24", choices: fmtChoices },
            { key: "seconds", type: "toggle", label: T("Seconds", "Saniye"), def: false },
            { key: "date",    type: "select", label: T("Date", "Tarih"), def: "short", choices: dateChoices,
              when: { key: "design", eq: ["classic", "ring"] } },
            color("color", "primary")
        ]
    },
    {
        type: "clock-analog", category: "clock", name: T("Analog", "Analog"),
        sizes: ["S", "M", "L"], size: "S", interactive: false, source: "widgets/ClockAnalog.qml",
        opts: [
            { key: "seconds", type: "toggle", label: T("Second hand", "Saniye ibresi"), def: false },
            { key: "ticks",   type: "select", label: T("Ticks", "Çizgiler"), def: "all", choices: [
                { v: "none", label: T("None", "Yok") },
                { v: "quarters", label: T("Quarters", "Çeyrekler") },
                { v: "all", label: T("All", "Hepsi") }
            ] },
            { key: "date",    type: "toggle", label: T("Date", "Tarih"), def: true },
            color("color", "text"),
            color("accent", "primary", T("Accent", "Vurgu"))
        ]
    },
    {
        type: "clock-serif", category: "clock", name: T("Serif", "Serif"),
        sizes: ["M", "L", "W"], size: "M", interactive: false, source: "widgets/ClockSerif.qml",
        opts: [
            { key: "format", type: "select", label: T("Format", "Biçim"), def: "24", choices: fmtChoices },
            { key: "date",   type: "select", label: T("Date", "Tarih"), def: "long", choices: dateChoices },
            color("color", "text")
        ]
    },
    {
        type: "clock-poster", category: "clock", name: T("Poster", "Poster"),
        sizes: ["M", "L", "W"], size: "W", interactive: false, source: "widgets/ClockPoster.qml",
        style: { background: false, shadow: false },
        opts: [
            { key: "design",   type: "select", label: T("Style", "Stil"), def: "classic", choices: [
                { v: "classic", label: T("Classic", "Klasik") },
                { v: "cut",     label: T("Cut letters", "Kesik harfler") },
                { v: "sign",    label: T("Sign", "Afiş") }
            ] },
            { key: "format",   type: "select", label: T("Format", "Biçim"), def: "24", choices: fmtChoices },
            { key: "spacing",  type: "select", label: T("Letter spacing", "Harf aralığı"), def: "wide",
              when: { key: "design", eq: ["classic", "cut"] }, choices: [
                { v: "tight",  label: T("Tight", "Dar") },
                { v: "normal", label: T("Normal", "Normal") },
                { v: "wide",   label: T("Wide", "Geniş") }
            ] },
            { key: "showDate", type: "toggle", label: T("Date", "Tarih"), def: true },
            { key: "showTime", type: "toggle", label: T("Time", "Saat"), def: true },
            { key: "seconds",  type: "toggle", label: T("Seconds", "Saniye"), def: false,
              when: { key: "design", eq: "sign" } },
            color("color", "text"),
            color("accent", "secondary", T("Accent", "Vurgu"), { key: "design", eq: "sign" })
        ]
    },
    {
        type: "clock-mono", category: "clock", name: T("Mono + seconds", "Mono + saniye"),
        sizes: ["S", "M"], size: "M", interactive: false, source: "widgets/ClockMono.qml",
        opts: [
            { key: "format",  type: "select", label: T("Format", "Biçim"), def: "24", choices: fmtChoices },
            { key: "seconds", type: "toggle", label: T("Seconds", "Saniye"), def: true },
            { key: "bar",     type: "toggle", label: T("Second bar", "Saniye çubuğu"), def: true },
            { key: "date",    type: "select", label: T("Date", "Tarih"), def: "short", choices: dateChoices },
            color("color", "primary")
        ]
    },
    {
        type: "clock-world", category: "clock", name: T("World clock", "Dünya saati"),
        sizes: ["M", "L"], size: "M", interactive: false, source: "widgets/ClockWorld.qml",
        opts: [
            { key: "zones",  type: "text", label: T("Time zones", "Saat dilimleri"), def: "Europe/London,Asia/Tokyo,America/New_York",
              hint: T("IANA names, comma separated", "IANA adları, virgülle ayır") },
            { key: "format", type: "select", label: T("Format", "Biçim"), def: "24", choices: fmtChoices },
            color("color", "primary")
        ]
    },

    // ---- system ----
    {
        type: "cpu-graph", category: "system", name: T("CPU graph", "CPU grafik"),
        sizes: ["S", "M", "L"], size: "M", interactive: false, source: "widgets/CpuGraph.qml",
        opts: [
            { key: "design",   type: "select", label: T("Style", "Stil"), def: "bars", choices: [
                { v: "bars", label: T("Bars (btop)", "Çubuk (btop)") },
                { v: "line", label: T("Line", "Çizgi") }
            ] },
            { key: "scale",    type: "select", label: T("Scale", "Ölçek"), def: "auto", choices: [
                { v: "auto",  label: T("Auto", "Otomatik") },
                { v: "fixed", label: T("0 – 100 %", "0 – %100") }
            ] },
            { key: "gradient", type: "toggle", label: T("Colour by load", "Yüke göre renk"), def: true,
              when: { key: "design", eq: "bars" } },
            { key: "series2",  type: "select", label: T("Second line", "İkinci çizgi"), def: "temp", choices: [
                { v: "none", label: T("None", "Yok") },
                { v: "temp", label: T("Temperature", "Sıcaklık") },
                { v: "mem",  label: T("Memory", "Bellek") }
            ] },
            { key: "interval", type: "select", label: T("Refresh", "Yenileme"), def: 2, choices: intervalChoices },
            { key: "fill",     type: "toggle", label: T("Filled", "Dolgulu"), def: false,
              when: { key: "design", eq: "line" } },
            { key: "label",    type: "toggle", label: T("Label", "Etiket"), def: true },
            color("color", "primary", T("Line 1", "Çizgi 1")),
            color("color2", "secondary", T("Line 2", "Çizgi 2"))
        ]
    },
    {
        type: "ram-ring", category: "system", name: T("RAM ring", "RAM halka"),
        sizes: ["S", "M"], size: "S", interactive: false, source: "widgets/RamRing.qml",
        opts: [
            { key: "swap",     type: "toggle", label: T("Show swap", "Swap göster"), def: true },
            { key: "interval", type: "select", label: T("Refresh", "Yenileme"), def: 2, choices: intervalChoices },
            { key: "label",    type: "toggle", label: T("Label", "Etiket"), def: true },
            color("color", "primary")
        ]
    },
    {
        type: "disk", category: "system", name: T("Disk", "Disk"),
        sizes: ["S", "M"], size: "M", interactive: false, source: "widgets/DiskBars.qml",
        opts: [
            { key: "mounts", type: "text", label: T("Mount points", "Bağlama noktaları"), def: "/",
              hint: T("Comma separated", "Virgülle ayır") },
            { key: "warn",   type: "range", label: T("Warn above", "Uyarı eşiği"), def: 85, min: 50, max: 99, step: 1, unit: "%" },
            color("color", "primary")
        ]
    },
    {
        type: "net", category: "system", name: T("Network", "Ağ"),
        sizes: ["S", "M", "W"], size: "M", interactive: false, source: "widgets/NetSpark.qml",
        opts: [
            { key: "design",   type: "select", label: T("Style", "Stil"), def: "bars", choices: [
                { v: "bars", label: T("Bars (btop)", "Çubuk (btop)") },
                { v: "line", label: T("Line", "Çizgi") }
            ] },
            { key: "iface",    type: "text", label: T("Interface", "Arayüz"), def: "auto",
              hint: T("auto or a name like wlan0", "auto ya da wlan0 gibi bir ad") },
            { key: "unit",     type: "select", label: T("Unit", "Birim"), def: "bytes", choices: [
                { v: "bytes", label: T("Bytes", "Bayt") },
                { v: "bits",  label: T("Bits", "Bit") }
            ] },
            { key: "interval", type: "select", label: T("Refresh", "Yenileme"), def: 1, choices: intervalChoices },
            color("color", "primary", T("Down", "İndirme")),
            color("color2", "secondary", T("Up", "Yükleme"))
        ]
    },
    {
        type: "temp-gauge", category: "system", name: T("Temperature", "Sıcaklık"),
        sizes: ["S", "M"], size: "S", interactive: false, source: "widgets/TempGauge.qml",
        opts: [
            { key: "max",  type: "range", label: T("Scale top", "Ölçek üst sınırı"), def: 100, min: 60, max: 120, step: 5, unit: "°" },
            { key: "warn", type: "range", label: T("Warn above", "Uyarı eşiği"), def: 70, min: 40, max: 110, step: 1, unit: "°" },
            { key: "crit", type: "range", label: T("Critical above", "Kritik eşik"), def: 85, min: 50, max: 120, step: 1, unit: "°" },
            color("color", "primary")
        ]
    },

    // ---- media & tools ----
    {
        type: "media", category: "media", name: T("Media player", "Müzik"),
        sizes: ["S", "M", "L", "W", "X"], size: "M", interactive: true, source: "widgets/MediaPlayer.qml",
        opts: [
            { key: "look",     type: "select", label: T("Style", "Stil"), def: "card", choices: [
                { v: "card",  label: T("Card", "Kart") },
                { v: "wide",  label: T("Wide strip", "Geniş şerit") },
                { v: "pill",  label: T("Pill", "Hap") },
                { v: "scope", label: T("Oscilloscope", "Osiloskop") }
            ] },
            { key: "player",   type: "text", label: T("Player", "Oynatıcı"), def: "",
              hint: T("Empty = whichever is playing", "Boş = çalan oynatıcı") },
            { key: "viz",      type: "select", label: T("Visualizer (needs cava)", "Görselleştirici (cava gerekir)"), def: "wave", choices: [
                { v: "wave",     label: T("In the progress bar", "İlerleme çubuğunda") },
                { v: "backdrop", label: T("Behind the card", "Kartın arkasında") },
                { v: "both",     label: T("Both", "İkisi birden") },
                { v: "off",      label: T("Off", "Kapalı") }
            ] },
            { key: "art",      type: "toggle", label: T("Cover art", "Kapak"), def: true },
            { key: "progress", type: "toggle", label: T("Progress bar", "İlerleme çubuğu"), def: true },
            color("color", "primary")
        ]
    },
    {
        type: "usage-limits", category: "media", name: T("AI limits", "YZ limitleri"),
        sizes: ["M", "W"], size: "M", interactive: false, source: "widgets/UsageLimits.qml",
        opts: [
            { key: "look", type: "select", label: T("Style", "Stil"), def: "rings", choices: [
                { v: "rings", label: T("Twin rings", "Çift halka") },
                { v: "led",   label: T("LED dots", "LED nokta") }
            ] },
            { key: "show", type: "select", label: T("Show", "Göster"), def: "both", choices: [
                { v: "both",   label: T("Claude and Codex", "Claude ve Codex") },
                { v: "claude", label: T("Claude only", "Yalnızca Claude") },
                { v: "codex",  label: T("Codex only", "Yalnızca Codex") }
            ] },
            { key: "warn", type: "range", label: T("Warn above", "Uyarı eşiği"), def: 90, min: 50, max: 99, step: 1, unit: "%" },
            { key: "claudeApi", type: "toggle", label: T("Claude: official API", "Claude: resmi API"), def: false,
              hint: T("Reads the token Claude Code keeps and asks api.anthropic.com every 5 minutes. Off: only the status line capture.",
                      "Claude Code'un token'ını okuyup 5 dakikada bir api.anthropic.com'a sorar. Kapalı: yalnızca status line yakalaması.") },
            color("color", "primary", T("Codex colour", "Codex rengi")),
            color("color2", "secondary", T("Claude colour", "Claude rengi"))
        ]
    },
    {
        type: "calendar", category: "media", name: T("Calendar", "Takvim"),
        sizes: ["M", "L"], size: "L", interactive: false, source: "widgets/Calendar.qml",
        opts: [
            { key: "firstDay", type: "select", label: T("Week starts on", "Hafta başlangıcı"), def: "mon", choices: [
                { v: "mon", label: T("Monday", "Pazartesi") },
                { v: "sun", label: T("Sunday", "Pazar") }
            ] },
            { key: "weeks", type: "toggle", label: T("Week numbers", "Hafta numaraları"), def: false },
            color("color", "primary")
        ]
    },
    {
        type: "weather", category: "media", name: T("Weather", "Hava"),
        sizes: ["S", "M", "L"], size: "M", interactive: false, source: "widgets/Weather.qml",
        opts: [
            { key: "place",    type: "place", label: T("Place", "Yer"), def: null },
            // Older layouts stored a plain city name; it still works but is no longer shown.
            { key: "city",     type: "text", label: T("City", "Şehir"), def: "", hidden: true },
            { key: "units",    type: "select", label: T("Units", "Birim"), def: "metric", choices: [
                { v: "metric",   label: T("°C · km/h", "°C · km/sa") },
                { v: "imperial", label: T("°F · mph", "°F · mph") }
            ] },
            { key: "forecast", type: "toggle", label: T("Forecast", "Tahmin"), def: true },
            color("color", "primary")
        ]
    },
    {
        type: "pomodoro", category: "media", name: T("Pomodoro", "Pomodoro"),
        sizes: ["S", "M"], size: "S", interactive: true, source: "widgets/Pomodoro.qml",
        opts: [
            { key: "focus",  type: "range", label: T("Focus", "Odak"), def: 25, min: 5, max: 90, step: 5, unit: " min" },
            { key: "rest",   type: "range", label: T("Break", "Mola"), def: 5, min: 1, max: 30, step: 1, unit: " min" },
            { key: "notify", type: "toggle", label: T("Notify when done", "Bitince bildir"), def: true },
            color("color", "primary")
        ]
    },
    {
        type: "notes", category: "media", name: T("Notes", "Notlar"),
        sizes: ["M", "L"], size: "M", interactive: true, source: "widgets/Notes.qml",
        opts: [
            { key: "title", type: "text", label: T("Title", "Başlık"), def: "Notes" },
            { key: "lines", type: "lines", label: T("Items", "Maddeler"), def: "- [ ] First thing\n- [ ] Second thing\n- [x] Install Desktop Widget Control",
              hint: T("One per line: - [ ] todo, - [x] done", "Satır başına bir madde: - [ ] yapılacak, - [x] bitti") },
            color("color", "primary")
        ]
    }
];

function byType(type) {
    for (var i = 0; i < modules.length; i++)
        if (modules[i].type === type)
            return modules[i];
    return null;
}

function inCategory(cat) {
    var out = [];
    for (var i = 0; i < modules.length; i++)
        if (modules[i].category === cat)
            out.push(modules[i]);
    return out;
}

// Default cfg object for a module: { key: def, ... }
function cfgDefaults(type) {
    var m = byType(type);
    var out = {};
    if (!m)
        return out;
    for (var i = 0; i < m.opts.length; i++)
        out[m.opts[i].key] = m.opts[i].def;
    return out;
}

// Appearance defaults; a module may override some in its `style` (the poster
// clock starts without a card, for instance).
function styleDefaults(type) {
    var out = {};
    for (var i = 0; i < styleOptions.length; i++)
        out[styleOptions[i].key] = styleOptions[i].def;
    var m = type ? byType(type) : null;
    if (m && m.style)
        for (var k in m.style)
            out[k] = m.style[k];
    return out;
}

// Stored values over the defaults; unknown keys are dropped, missing ones filled.
function mergeCfg(type, stored) {
    var out = cfgDefaults(type);
    if (stored && typeof stored === "object")
        for (var k in out)
            if (stored[k] !== undefined && stored[k] !== null)
                out[k] = stored[k];
    return out;
}

function mergeStyle(stored, type) {
    var out = styleDefaults(type);
    if (stored && typeof stored === "object")
        for (var k in out)
            if (stored[k] !== undefined && stored[k] !== null)
                out[k] = stored[k];
    return out;
}

// Does an option apply given the widget's values? `when` is { key, eq } where eq is a value or a list of values.
function applies(opt, cfg) {
    if (!opt.when)
        return true;
    var v = cfg[opt.when.key];
    return Array.isArray(opt.when.eq) ? opt.when.eq.indexOf(v) >= 0 : v === opt.when.eq;
}

function pick(obj, lang) {
    if (!obj)
        return "";
    if (typeof obj === "string")
        return obj;
    return obj[lang] || obj.en || "";
}
