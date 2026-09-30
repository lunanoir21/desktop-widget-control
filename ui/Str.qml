pragma Singleton
import QtQuick
import "js/Strings.js" as Strings
import "js/Modules.js" as Modules

// Interface language. Reading `lang` inside t() / pick() is what makes every
// binding that calls them re-evaluate when the language changes.
QtObject {
    id: root

    readonly property string lang: {
        var l = DwcStore.language;
        if (l === "en" || l === "tr")
            return l;
        return Qt.locale().name.indexOf("tr") === 0 ? "tr" : "en";
    }

    // Day and month names follow the chosen language, or the system's when it is "auto".
    readonly property var locale: DwcStore.language === "auto" ? Qt.locale()
        : Qt.locale(root.lang === "tr" ? "tr_TR" : "en_US")

    // A date in this language: fmt("dddd d MMMM", date).
    function fmt(pattern, date) {
        return date.toLocaleString(root.locale, pattern);
    }

    function t(key) {
        return Strings.t(root.lang, key);
    }

    // A { en, tr } pair from Modules.js.
    function pick(obj) {
        return Modules.pick(obj, root.lang);
    }
}
