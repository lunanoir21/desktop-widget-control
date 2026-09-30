import QtQuick
import QtTest
import "../ui/js/Usage.js" as Usage

TestCase {
    name: "Usage"

    // a Codex rollout line; the 5-hour window can be primary or secondary
    function codexLine(primary, secondary) {
        return JSON.stringify({ timestamp: "2026-08-17T10:00:02.000Z", type: "event_msg",
            payload: { type: "token_count", rate_limits: { primary: primary, secondary: secondary } } });
    }

    function test_codex_windows_are_told_apart_by_their_length() {
        var r = Usage.parseCodex(codexLine({ used_percent: 93, window_minutes: 10080, resets_at: 1787256462 },
                                            { used_percent: 40, window_minutes: 300, resets_at: 1787017800 }));
        compare(r.five.pct, 40);
        compare(r.five.resets, 1787017800);
        compare(r.week.pct, 93);
        compare(r.source, "codex");
        verify(r.at > 0);
        var only = Usage.parseCodex(codexLine({ used_percent: 12, window_minutes: 300, resets_at: 5 }, null));
        compare(only.five.pct, 12);
        compare(only.week, null);
    }

    function test_codex_lines_without_limits_or_with_junk_give_nothing() {
        compare(Usage.parseCodex("not json"), null);
        compare(Usage.parseCodex(JSON.stringify({ payload: {} })), null);
        compare(Usage.parseCodex(codexLine({ used_percent: 1, window_minutes: 0 }, null)), null);
    }

    function test_claude_status_line_capture() {
        var r = Usage.parseClaudeCapture(JSON.stringify({ rate_limits: {
            five_hour: { used_percentage: 63, resets_at: 1787017800 },
            seven_day: { used_percentage: 72, resets_at: 1787097600 } } }), "1787000000");
        compare(r.five.pct, 63);
        compare(r.week.resets, 1787097600);
        compare(r.at, 1787000000);
        compare(Usage.parseClaudeCapture(JSON.stringify({ model: {} }), "1"), null);
    }

    function test_claude_api_answer_with_iso_times() {
        var r = Usage.parseClaudeApi(JSON.stringify({ five_hour: { utilization: 73.0, resets_at: "2026-09-15T18:00:00Z" },
                                                      seven_day: { utilization: 7.0, resets_at: null } }), 100);
        compare(r.five.pct, 73);
        compare(r.five.resets, Date.parse("2026-09-15T18:00:00Z") / 1000);
        compare(r.week.resets, 0);
        compare(r.source, "api");
    }

    function test_percentages_are_clamped() {
        var r = Usage.parseClaudeApi(JSON.stringify({ five_hour: { utilization: 250 }, seven_day: { utilization: -4 } }), 1);
        compare(r.five.pct, 100);
        compare(r.week.pct, 0);
    }

    function test_the_newer_reading_wins() {
        var a = { at: 10 }, b = { at: 20 };
        compare(Usage.newer(a, b), b);
        compare(Usage.newer(b, a), b);
        compare(Usage.newer(null, a), a);
        compare(Usage.newer(null, null), null);
    }

    function test_a_window_that_has_reset_reads_empty() {
        var s = Usage.settle({ pct: 93, resets: 1000 }, 2000);
        compare(s.pct, 0);
        compare(s.rolled, true);
        compare(Usage.settle({ pct: 50, resets: 3000 }, 2000).pct, 50);
        compare(Usage.settle({ pct: 50, resets: 0 }, 2000).pct, 50);
        compare(Usage.settle(null, 1), null);
    }

    function test_durations() {
        compare(Usage.duration(-1), "");
        compare(Usage.duration(20), "<1m");
        compare(Usage.duration(42 * 60), "42m");
        compare(Usage.duration(2 * 3600 + 5 * 60), "2h 05m");
        compare(Usage.duration(3 * 86400 + 4 * 3600), "3d 4h");
        compare(Usage.remaining(0, 100), -1);
        compare(Usage.remaining(150, 100), 50);
    }

    function test_levels() {
        compare(Usage.level(50, 90), "ok");
        compare(Usage.level(90, 90), "warn");
        compare(Usage.level(100, 90), "full");
    }
}
