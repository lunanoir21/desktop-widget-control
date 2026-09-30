import QtQuick
import QtTest
import "../ui/js/Strings.js" as Strings
import "../ui/js/Themes.js" as Themes
import "../ui/js/Icons.js" as Icons
import "../ui/js/Countries.js" as Countries

TestCase {
    name: "Content"

    function test_languages_have_the_same_keys() {
        var en = Object.keys(Strings.en).sort();
        var tr = Object.keys(Strings.tr).sort();
        compare(tr.join(","), en.join(","));
    }

    function test_no_empty_strings() {
        for (var k in Strings.en) {
            verify(Strings.en[k] !== "", "en " + k);
            verify(Strings.tr[k] !== "", "tr " + k);
        }
    }

    function test_t_falls_back() {
        compare(Strings.t("tr", "ed.done"), "Bitti");
        compare(Strings.t("en", "ed.done"), "Done");
        compare(Strings.t("xx", "ed.done"), "Done");
        compare(Strings.t("en", "no.such.key"), "no.such.key");
    }

    function test_themes() {
        var seen = {};
        var fields = ["card", "alt", "fg", "sub", "muted", "acc", "onAcc", "acc2", "track"];
        for (var i = 0; i < Themes.list.length; i++) {
            var t = Themes.list[i];
            verify(!seen[t.id], "duplicate theme " + t.id);
            seen[t.id] = true;
            for (var f = 0; f < fields.length; f++)
                verify(/^#[0-9a-f]{6}$/i.test(t[fields[f]]), t.id + "." + fields[f]);
            compare(typeof t.dark, "boolean");
        }
        verify(Themes.exists(Themes.defaultId));
        compare(Themes.byId("nope").id, Themes.list[0].id);
        compare(Themes.ids().length, Themes.list.length);
    }

    // Readable text on every theme: primary text on the card and the label on
    // the accent each need at least 4.5:1 (WCAG AA for normal text).
    function lum(hex) {
        var v = [1, 3, 5].map(function (i) {
            var c = parseInt(hex.substr(i, 2), 16) / 255;
            return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
        });
        return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
    }
    function ratio(a, b) {
        var la = lum(a), lb = lum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }
    function test_theme_contrast() {
        for (var i = 0; i < Themes.list.length; i++) {
            var t = Themes.list[i];
            verify(ratio(t.fg, t.card) >= 4.5, t.id + ": text on card " + ratio(t.fg, t.card).toFixed(2));
            verify(ratio(t.onAcc, t.acc) >= 4.5, t.id + ": label on accent " + ratio(t.onAcc, t.acc).toFixed(2));
            verify(ratio(t.sub, t.card) >= 4.5, t.id + ": secondary text " + ratio(t.sub, t.card).toFixed(2));
        }
    }

    function test_icons() {
        var needed = ["plus", "x", "trash", "copy", "lock", "unlock", "search", "chevdown", "check", "reset",
                      "prev", "next", "play", "pause", "music", "sun", "partly", "cloud", "rain", "snow", "fog", "storm"];
        for (var i = 0; i < needed.length; i++)
            verify(Icons.path(needed[i]) !== "", "icon " + needed[i]);
        compare(Icons.path("nope"), "");
    }

    function test_countries() {
        var seen = {};
        for (var i = 0; i < Countries.list.length; i++) {
            var c = Countries.list[i];
            verify(/^[A-Z]{2}$/.test(c.cc), "code " + c.cc);
            verify(!seen[c.cc], "duplicate " + c.cc);
            seen[c.cc] = true;
            verify(c.en !== "" && c.tr !== "", c.cc + " needs both names");
        }
        verify(Countries.list.length >= 80);
        verify(seen["TR"] && seen["US"] && seen["DE"] && seen["JP"]);
    }

    function test_country_choices_are_sorted_in_each_language() {
        // Turkish collation needs the engine's ICU data; a minimal CI image may lack it.
        if ("ç".localeCompare("d", "tr") >= 0)
            skip("no Turkish collation in this Qt build");
        var en = Countries.choices("en");
        for (var i = 1; i < en.length; i++)
            verify(en[i - 1].label.localeCompare(en[i].label, "en") <= 0, en[i - 1].label + " before " + en[i].label);
        var tr = Countries.choices("tr");
        compare(tr.length, en.length);
        // Turkish puts "Çin" (China) after "Bulgaristan" and before "Danimarka".
        var names = tr.map(function (c) { return c.label; });
        verify(names.indexOf("Bulgaristan") < names.indexOf("Çin") && names.indexOf("Çin") < names.indexOf("Danimarka"));
        compare(Countries.byCode("TR").en, "Türkiye");
        compare(Countries.byCode("XX"), null);
    }

    function test_the_picker_strings_exist_in_both_languages() {
        var keys = ["pick.anyCountry", "pick.country", "pick.city", "pick.search", "pick.searching", "pick.nothing", "pick.none"];
        for (var i = 0; i < keys.length; i++) {
            verify(Strings.en[keys[i]] !== undefined, "en " + keys[i]);
            verify(Strings.tr[keys[i]] !== undefined, "tr " + keys[i]);
        }
    }
}
