import QtQuick
import QtTest
import "../ui/js/Layout.js" as Layout
import "../ui/js/Geometry.js" as Geometry
import "../ui/js/Dates.js" as Dates

TestCase {
    name: "Layout"

    readonly property var bounds: ({ cols: 12, rows: 8 })

    function test_overlaps() {
        compare(Layout.overlaps({ x: 0, y: 0, w: 4, h: 4 }, { x: 3, y: 3, w: 4, h: 4 }), true);
        // Touching edges is not overlapping.
        compare(Layout.overlaps({ x: 0, y: 0, w: 4, h: 4 }, { x: 4, y: 0, w: 4, h: 4 }), false);
        compare(Layout.overlaps({ x: 0, y: 0, w: 4, h: 4 }, { x: 0, y: 4, w: 4, h: 4 }), false);
    }

    function test_inside() {
        verify(Layout.inside({ x: 0, y: 0, w: 12, h: 8 }, bounds));
        verify(!Layout.inside({ x: 1, y: 0, w: 12, h: 8 }, bounds));
        verify(!Layout.inside({ x: -1, y: 0, w: 4, h: 4 }, bounds));
        verify(!Layout.inside({ x: 0, y: 0, w: 0, h: 4 }, bounds));
    }

    function test_canPlace() {
        var others = [{ x: 0, y: 0, w: 4, h: 4 }];
        verify(!Layout.canPlace({ x: 2, y: 2, w: 4, h: 4 }, others, bounds));
        verify(Layout.canPlace({ x: 4, y: 0, w: 4, h: 4 }, others, bounds));
        verify(!Layout.canPlace({ x: 10, y: 0, w: 4, h: 4 }, [], bounds));
    }

    function test_clampRect_keeps_size() {
        var c = Layout.clampRect({ x: 20, y: -3, w: 4, h: 4 }, bounds);
        compare(c.x, 8);
        compare(c.y, 0);
        compare(c.w, 4);
        compare(c.h, 4);
    }

    function test_findFree_prefers_nearest() {
        var others = [{ x: 0, y: 0, w: 4, h: 4 }];
        var f = Layout.findFree(others, 4, 4, bounds, 1, 1);
        verify(f !== null);
        verify(Layout.canPlace(f, others, bounds));
        // The closest free 4x4 to (1,1) is directly right or directly below the taken block.
        verify((f.x === 4 && f.y <= 1) || (f.y === 4 && f.x <= 1));
    }

    function test_findFree_full_screen() {
        var others = [{ x: 0, y: 0, w: 12, h: 8 }];
        compare(Layout.findFree(others, 4, 4, bounds, 0, 0), null);
    }

    function test_findFree_too_big() {
        compare(Layout.findFree([], 13, 4, bounds, 0, 0), null);
    }

    function test_nearestPreset() {
        compare(Layout.nearestPreset(["S", "M", "L"], 4, 4), "S");
        compare(Layout.nearestPreset(["S", "M", "L"], 8, 4), "M");
        compare(Layout.nearestPreset(["S", "M", "L"], 9, 9), "L");
        // Only what the module allows can be chosen.
        compare(Layout.nearestPreset(["M", "L"], 4, 4), "M");
        compare(Layout.nearestPreset(["M", "L", "W"], 12, 4), "W");
    }

    function test_boundsFor() {
        var b = Layout.boundsFor(1920, 1080, 40);
        compare(b.cols, 48);
        compare(b.rows, 27);
        // Never zero, even for a tiny or bogus size.
        compare(Layout.boundsFor(10, 10, 40).cols, 1);
    }

    function test_nextId() {
        compare(Layout.nextId("media", []), "media-1");
        compare(Layout.nextId("media", ["media-1", "media-2"]), "media-3");
        compare(Layout.nextId("media", ["media-2"]), "media-1");
    }

    function test_preset_fallback() {
        compare(Layout.preset("nonsense").w, Layout.presets.M.w);
    }

    function test_settle_leaves_a_good_layout_alone() {
        var rects = [{ x: 0, y: 0, w: 4, h: 4 }, { x: 4, y: 0, w: 4, h: 4 }];
        var out = Layout.settle(rects, bounds);
        compare(JSON.stringify(out), JSON.stringify(rects));
    }

    function test_settle_pulls_back_inside() {
        var out = Layout.settle([{ x: 20, y: 0, w: 4, h: 4 }], bounds);
        compare(out[0].x, 8);
    }

    // The bug this exists for: two widgets saved on the same cell, or clamped
    // onto each other, must come out apart.
    function test_settle_separates_stacked_widgets() {
        var out = Layout.settle([{ x: 2, y: 2, w: 4, h: 4 }, { x: 2, y: 2, w: 4, h: 4 }, { x: 3, y: 3, w: 4, h: 4 }], { cols: 20, rows: 12 });
        for (var i = 0; i < out.length; i++)
            for (var j = i + 1; j < out.length; j++)
                verify(!Layout.overlaps(out[i], out[j]), "rects " + i + " and " + j + " overlap");
        // The first keeps its place.
        compare(out[0].x, 2);
        compare(out[0].y, 2);
    }

    function test_settle_keeps_sizes_and_order() {
        var out = Layout.settle([{ x: 0, y: 0, w: 8, h: 4 }, { x: 0, y: 0, w: 4, h: 4 }], bounds);
        compare(out.length, 2);
        compare(out[0].w, 8);
        compare(out[1].w, 4);
    }

    function test_settle_with_no_room_does_not_lose_anything() {
        var out = Layout.settle([{ x: 0, y: 0, w: 12, h: 8 }, { x: 0, y: 0, w: 4, h: 4 }], bounds);
        compare(out.length, 2);
    }

    function test_outline_starts_at_top_middle_and_closes() {
        var pts = Geometry.roundedRectPoints(100, 60, 12, 2);
        compare(pts[0].x, 50);
        compare(pts[0].y, 0);
        compare(pts[pts.length - 1].x, 50);
        compare(pts[pts.length - 1].y, 0);
        // roughly the perimeter at 2 px a step
        var perimeter = 2 * (100 + 60) - 8 * 12 + 2 * Math.PI * 12;
        verify(Math.abs(pts.length - perimeter / 2) < 8, "points " + pts.length);
    }

    function test_outline_stays_inside_the_box() {
        var pts = Geometry.roundedRectPoints(100, 60, 12, 2);
        for (var i = 0; i < pts.length; i++) {
            verify(pts[i].x >= -0.001 && pts[i].x <= 100.001, "x " + pts[i].x);
            verify(pts[i].y >= -0.001 && pts[i].y <= 60.001, "y " + pts[i].y);
        }
    }

    function test_outline_goes_clockwise() {
        var pts = Geometry.roundedRectPoints(100, 60, 12, 2);
        // A quarter of the way round we are on the right-hand edge, half way on the bottom.
        var q = pts[Math.round(pts.length * 0.25)];
        var h = pts[Math.round(pts.length * 0.5)];
        verify(q.x > 90, "quarter x " + q.x);
        verify(h.y > 50, "half y " + h.y);
    }

    function test_outline_copes_with_a_radius_too_big() {
        var pts = Geometry.roundedRectPoints(40, 20, 99, 2);
        verify(pts.length > 10);
        for (var i = 0; i < pts.length; i++)
            verify(pts[i].y >= -0.001 && pts[i].y <= 20.001);
    }

    function test_prefix() {
        var pts = Geometry.roundedRectPoints(100, 60, 12, 2);
        compare(Geometry.prefix(pts, 1).length, pts.length);
        compare(Geometry.prefix(pts, 0).length, 2);
        var half = Geometry.prefix(pts, 0.5).length;
        verify(Math.abs(half - pts.length / 2) <= 2);
        verify(Geometry.prefix(pts, 2).length === pts.length);
    }

    function test_week_numbers() {
        compare(Dates.isoWeek(new Date(2026, 8, 30)), 40);
        compare(Dates.isoWeek(new Date(2026, 0, 1)), 1);
        compare(Dates.isoWeek(new Date(2024, 11, 30)), 1);      // belongs to the next year's week 1
        compare(Dates.mondayIndex(new Date(2026, 8, 28)), 0);   // a Monday
        compare(Dates.mondayIndex(new Date(2026, 9, 4)), 6);    // a Sunday
        compare(Dates.dayOfYear(new Date(2026, 0, 1)), 1);
        compare(Dates.dayOfYear(new Date(2026, 8, 30)), 273);
        compare(Dates.dayOfYear(new Date(2024, 11, 31)), 366);  // a leap year
    }

    function test_centered() {
        var c = Layout.centered(20, 4, { cols: 48, rows: 27 });
        compare(c.x, 14);                       // 14 cells on each side
        compare(c.y, 11);                       // rounded down
        compare(Layout.centered(4, 4, { cols: 9, rows: 9 }).x, 2);
        // A widget bigger than the screen sits at 0, never negative.
        compare(Layout.centered(20, 4, { cols: 12, rows: 3 }).x, 0);
        compare(Layout.centered(20, 4, { cols: 12, rows: 3 }).y, 0);
    }

    function test_the_extra_wide_preset() {
        compare(Layout.preset("X").w, 20);
        compare(Layout.preset("X").h, 4);
        compare(Layout.nearestPreset(["M", "W", "X"], 19, 4), "X");
        compare(Layout.nearestPreset(["M", "W", "X"], 12, 4), "W");
    }
}
