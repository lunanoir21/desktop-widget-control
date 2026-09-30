pragma Singleton
import QtQuick
import "js/Themes.js" as Themes

// Colours, fonts and the helpers widgets use to turn an option value
// ("primary", "secondary", "#e0a458") into a colour.
Item {
    id: root

    FontLoader { id: syne;      source: Qt.resolvedUrl("fonts/Syne.ttf") }
    FontLoader { id: instr;     source: Qt.resolvedUrl("fonts/InstrumentSans.ttf") }
    FontLoader { id: mono;      source: Qt.resolvedUrl("fonts/DMMono-Regular.ttf") }
    FontLoader { id: monoMed;   source: Qt.resolvedUrl("fonts/DMMono-Medium.ttf") }
    FontLoader { id: serifIt;   source: Qt.resolvedUrl("fonts/Newsreader-Italic.ttf") }
    FontLoader { id: jost;      source: Qt.resolvedUrl("fonts/Jost.ttf") }
    FontLoader { id: dotMatrix; source: Qt.resolvedUrl("fonts/Doto.ttf") }

    // Family names come from the loaded files; the fallbacks keep text
    // readable on the frame before a font has finished loading.
    readonly property string display: syne.status === FontLoader.Ready ? syne.name : "sans-serif"
    readonly property string body: instr.status === FontLoader.Ready ? instr.name : "sans-serif"
    readonly property string mono: mono.status === FontLoader.Ready ? mono.name : "monospace"
    readonly property string serif: serifIt.status === FontLoader.Ready ? serifIt.name : "serif"
    readonly property string geo: jost.status === FontLoader.Ready ? jost.name : "sans-serif"
    readonly property string dots: dotMatrix.status === FontLoader.Ready ? dotMatrix.name : "monospace"

    readonly property var current: Themes.byId(DwcStore.themeId)

    readonly property bool dark: current.dark
    readonly property color card: current.card
    readonly property color alt: current.alt
    readonly property color fg: current.fg
    readonly property color sub: current.sub
    readonly property color muted: current.muted
    readonly property color acc: current.acc
    readonly property color onAcc: current.onAcc
    readonly property color acc2: current.acc2
    readonly property color track: current.track

    readonly property color faint: mix(fg, card, 0.32)
    readonly property color line: alpha(fg, 0.11)
    readonly property color lineStrong: alpha(fg, 0.22)
    readonly property color hover: alpha(fg, 0.07)
    readonly property color danger: "#e7907b"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r * t + b.r * (1 - t), a.g * t + b.g * (1 - t), a.b * t + b.b * (1 - t), 1);
    }

    // Option value → colour. Tokens follow the theme; anything else is taken
    // as a colour literal, and a bad literal falls back to the accent.
    function resolve(key) {
        switch (key) {
        case "primary": return acc;
        case "secondary": return acc2;
        case "text": return fg;
        case "muted": return muted;
        }
        if (typeof key === "string" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(key))
            return key;
        return acc;
    }
}
