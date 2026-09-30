import QtQuick
import QtTest
import "../ui/js/Modules.js" as Modules
import "../ui/js/Layout.js" as Layout

TestCase {
    name: "Modules"

    function test_types_unique() {
        var seen = {};
        for (var i = 0; i < Modules.modules.length; i++) {
            var t = Modules.modules[i].type;
            verify(!seen[t], "duplicate module type " + t);
            seen[t] = true;
        }
        verify(Modules.modules.length >= 15);
    }

    function test_each_module_is_well_formed() {
        var cats = Modules.categories.map(function (c) { return c.id; });
        for (var i = 0; i < Modules.modules.length; i++) {
            var m = Modules.modules[i];
            verify(cats.indexOf(m.category) >= 0, m.type + ": unknown category " + m.category);
            verify(m.sizes.length > 0, m.type + ": no sizes");
            for (var s = 0; s < m.sizes.length; s++)
                verify(Layout.presets[m.sizes[s]] !== undefined, m.type + ": unknown size " + m.sizes[s]);
            verify(m.sizes.indexOf(m.size) >= 0, m.type + ": default size not among sizes");
            verify(/^widgets\/[A-Za-z]+\.qml$/.test(m.source), m.type + ": odd source " + m.source);
            verify(m.name.en && m.name.tr, m.type + ": name needs en and tr");
            compare(typeof m.interactive, "boolean");
        }
    }

    function test_options_are_well_formed() {
        var kinds = ["toggle", "select", "range", "color", "text", "lines", "place"];
        for (var i = 0; i < Modules.modules.length; i++) {
            var m = Modules.modules[i];
            var keys = {};
            for (var j = 0; j < m.opts.length; j++) {
                var o = m.opts[j];
                var where = m.type + "." + o.key;
                verify(kinds.indexOf(o.type) >= 0, where + ": unknown type " + o.type);
                verify(!keys[o.key], where + ": duplicate key");
                keys[o.key] = true;
                verify(o.label.en && o.label.tr, where + ": label needs en and tr");
                verify(o.def !== undefined, where + ": no default");
                if (o.type === "select") {
                    var found = false;
                    for (var c = 0; c < o.choices.length; c++) {
                        verify(o.choices[c].label.en && o.choices[c].label.tr, where + ": choice label");
                        if (o.choices[c].v === o.def)
                            found = true;
                    }
                    verify(found, where + ": default is not one of the choices");
                } else if (o.type === "range") {
                    verify(o.def >= o.min && o.def <= o.max, where + ": default outside range");
                    verify(o.step > 0 && o.max > o.min, where + ": bad range");
                } else if (o.type === "color") {
                    verify(["primary", "secondary", "text", "muted"].indexOf(o.def) >= 0 || /^#[0-9a-f]{6}$/i.test(o.def), where + ": bad colour default");
                }
            }
        }
    }

    // A `when` must point at an option of the same module that can take that value.
    function test_when_conditions_make_sense() {
        for (var i = 0; i < Modules.modules.length; i++) {
            var m = Modules.modules[i];
            for (var j = 0; j < m.opts.length; j++) {
                var o = m.opts[j];
                if (!o.when)
                    continue;
                var where = m.type + "." + o.key;
                var dep = null;
                for (var k = 0; k < m.opts.length; k++)
                    if (m.opts[k].key === o.when.key)
                        dep = m.opts[k];
                verify(dep !== null, where + ": when refers to a missing option");
                verify(dep.type === "select" || dep.type === "toggle", where + ": when needs a select or toggle");
                var wanted = Array.isArray(o.when.eq) ? o.when.eq : [o.when.eq];
                for (var w = 0; w < wanted.length; w++)
                    if (dep.type === "select")
                        verify(dep.choices.some(function (c) { return c.v === wanted[w]; }), where + ": " + wanted[w] + " is not a choice of " + dep.key);
            }
        }
    }

    function test_applies() {
        var opt = { when: { key: "design", eq: "ring" } };
        verify(Modules.applies(opt, { design: "ring" }));
        verify(!Modules.applies(opt, { design: "classic" }));
        verify(Modules.applies({ when: { key: "design", eq: ["classic", "ring"] } }, { design: "ring" }));
        verify(!Modules.applies({ when: { key: "design", eq: ["classic", "ring"] } }, { design: "strip" }));
        verify(Modules.applies({}, {}));
    }

    function test_the_three_clock_styles() {
        var led = Modules.byType("clock-led");
        var design = led.opts.filter(function (o) { return o.key === "design"; })[0];
        compare(design.choices.map(function (c) { return c.v; }).join(","), "classic,ring,strip");
        compare(design.def, "classic");
    }

    // A module can start with its own appearance (the poster clock has no card).
    function test_module_style_overrides() {
        var poster = Modules.styleDefaults("clock-poster");
        compare(poster.background, false);
        compare(poster.radius, 16);
        compare(Modules.styleDefaults("media").background, true);
        compare(Modules.styleDefaults().background, true);
        compare(Modules.mergeStyle({}, "clock-poster").background, false);
        compare(Modules.mergeStyle({ background: true }, "clock-poster").background, true);
    }

    function test_weather_keeps_its_old_city_option_hidden() {
        var opts = Modules.byType("weather").opts;
        var place = opts.filter(function (o) { return o.key === "place"; })[0];
        var city = opts.filter(function (o) { return o.key === "city"; })[0];
        compare(place.type, "place");
        compare(place.def, null);
        compare(city.hidden, true);
    }

    function test_the_poster_clock_styles() {
        var poster = Modules.byType("clock-poster");
        var design = poster.opts.filter(function (o) { return o.key === "design"; })[0];
        compare(design.choices.map(function (c) { return c.v; }).join(","), "classic,cut,sign");
        // Spacing belongs to the letter styles, seconds and the accent to the sign.
        var by = {};
        poster.opts.forEach(function (o) { by[o.key] = o; });
        verify(Modules.applies(by.spacing, { design: "cut" }) && !Modules.applies(by.spacing, { design: "sign" }));
        verify(Modules.applies(by.seconds, { design: "sign" }) && !Modules.applies(by.seconds, { design: "classic" }));
        verify(Modules.applies(by.accent, { design: "sign" }) && !Modules.applies(by.accent, { design: "cut" }));
    }

    function test_the_media_looks() {
        var media = Modules.byType("media");
        var look = media.opts.filter(function (o) { return o.key === "look"; })[0];
        compare(look.choices.map(function (c) { return c.v; }).join(","), "card,wide,pill,scope");
        verify(media.sizes.indexOf("X") >= 0 && media.sizes.indexOf("W") >= 0);
    }

    function test_style_options() {
        var d = Modules.styleDefaults();
        compare(d.background, true);
        compare(d.bgOpacity, 0.85);
        for (var i = 0; i < Modules.styleOptions.length; i++)
            verify(d[Modules.styleOptions[i].key] !== undefined);
    }

    function test_mergeCfg_fills_and_filters() {
        var c = Modules.mergeCfg("clock-led", { seconds: true, bogus: 1 });
        compare(c.seconds, true);
        compare(c.format, "24");
        compare(c.bogus, undefined);
        // Garbage in, defaults out.
        compare(Modules.mergeCfg("clock-led", null).seconds, false);
        compare(Modules.mergeCfg("clock-led", "x").format, "24");
        compare(Object.keys(Modules.mergeCfg("no-such-module", {})).length, 0);
    }

    function test_mergeStyle() {
        var s = Modules.mergeStyle({ radius: 4, nope: 1 });
        compare(s.radius, 4);
        compare(s.padding, 14);
        compare(s.nope, undefined);
    }

    function test_pick() {
        compare(Modules.pick({ en: "a", tr: "b" }, "tr"), "b");
        compare(Modules.pick({ en: "a", tr: "b" }, "de"), "a");
        compare(Modules.pick("plain", "tr"), "plain");
        compare(Modules.pick(null, "en"), "");
    }

    function test_byType_and_category() {
        verify(Modules.byType("media") !== null);
        compare(Modules.byType("nope"), null);
        compare(Modules.inCategory("clock").length, 6);
        compare(Modules.inCategory("system").length, 5);
        compare(Modules.inCategory("media").length, 5);
    }
}
