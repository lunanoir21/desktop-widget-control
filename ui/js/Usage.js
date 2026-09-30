// Pure helpers for the usage-limits widget: turn what Codex and Claude Code
// leave behind into two windows each (the 5-hour one and the weekly one) and
// say how long until each resets. No scene needed, so the tests cover it.
//
// A window is { pct: 0..100, resets: epoch seconds, or 0 when unknown }.
// A reading is { five, week, at, source }: either window may be null, `at` is
// when it was recorded (epoch seconds), `source` says where it came from.

function num(v) {
    var n = Number(v);
    return isNaN(n) ? null : n;
}

function win(pct, resets) {
    pct = num(pct);
    if (pct === null)
        return null;
    return { pct: Math.max(0, Math.min(100, pct)), resets: num(resets) || 0 };
}

function parseJson(text) {
    try {
        return JSON.parse(text);
    } catch (e) {
        return null;
    }
}

// An ISO time or an epoch (seconds) -> epoch seconds, 0 when it is neither.
function epoch(v) {
    if (typeof v === "number")
        return v;
    if (typeof v === "string" && v !== "") {
        var t = Date.parse(v);
        return isNaN(t) ? 0 : Math.floor(t / 1000);
    }
    return 0;
}

// One `token_count` line of a Codex rollout log:
// payload.rate_limits.{primary,secondary}.{used_percent, window_minutes, resets_at}.
// Which of the two is the 5-hour one depends on the plan, so the window's own
// length decides, not its name.
function parseCodex(text) {
    var obj = parseJson(text);
    var rl = obj && obj.payload && obj.payload.rate_limits;
    if (!rl)
        return null;
    var out = { five: null, week: null, at: epoch(obj.timestamp), source: "codex" };
    ["primary", "secondary"].forEach(function (k) {
        var w = rl[k];
        if (!w)
            return;
        var minutes = num(w.window_minutes) || 0;
        var kind = minutes > 0 && minutes <= 360 ? "five" : (minutes >= 10000 ? "week" : "");
        if (kind !== "")
            out[kind] = win(w.used_percent, w.resets_at);
    });
    return out.five || out.week ? out : null;
}

// What Claude Code pipes to a status line command: rate_limits.{five_hour,seven_day}.
function parseClaudeCapture(text, mtime) {
    var obj = parseJson(text);
    var rl = obj && obj.rate_limits;
    if (!rl)
        return null;
    var f = rl.five_hour || null;
    var s = rl.seven_day || null;
    var out = {
        five: f ? win(f.used_percentage, epoch(f.resets_at)) : null,
        week: s ? win(s.used_percentage, epoch(s.resets_at)) : null,
        at: num(mtime) || 0,
        source: "capture"
    };
    return out.five || out.week ? out : null;
}

// The oauth usage endpoint: five_hour / seven_day { utilization, resets_at (ISO) }.
function parseClaudeApi(text, at) {
    var obj = parseJson(text);
    if (!obj)
        return null;
    var f = obj.five_hour || null;
    var s = obj.seven_day || null;
    var out = {
        five: f ? win(f.utilization, epoch(f.resets_at)) : null,
        week: s ? win(s.utilization, epoch(s.resets_at)) : null,
        at: num(at) || 0,
        source: "api"
    };
    return out.five || out.week ? out : null;
}

// The newer of two readings (either may be null).
function newer(a, b) {
    if (!a)
        return b;
    if (!b)
        return a;
    return b.at > a.at ? b : a;
}

// A window whose reset time has passed has rolled over: it is empty now, even
// though the reading that said otherwise is old.
function settle(w, now) {
    if (!w)
        return null;
    if (w.resets > 0 && w.resets <= now)
        return { pct: 0, resets: 0, rolled: true };
    return w;
}

// Seconds until `resets`, or -1 when unknown.
function remaining(resets, now) {
    return resets > 0 ? Math.max(0, resets - now) : -1;
}

// "2h 05m", "42m", "3d 4h"; "" when unknown.
function duration(secs) {
    if (secs < 0)
        return "";
    if (secs < 60)
        return "<1m";
    var m = Math.floor(secs / 60);
    if (m < 60)
        return m + "m";
    var h = Math.floor(m / 60);
    if (h < 48)
        return h + "h " + (m % 60 < 10 ? "0" : "") + (m % 60) + "m";
    return Math.floor(h / 24) + "d " + (h % 24) + "h";
}

// "ok" | "warn" | "full", by the percentage and the user's warning threshold.
function level(pct, warn) {
    return pct >= 100 ? "full" : (pct >= warn ? "warn" : "ok");
}

// How old a reading is, in minutes (0 when it has no time).
function ageMinutes(at, now) {
    return at > 0 ? Math.max(0, Math.floor((now - at) / 60)) : 0;
}
