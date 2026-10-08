// Pure helpers for the GitHub profile widget: turn what scripts/github.sh prints
// into a profile, a list of repositories and a contribution calendar, and work
// out the numbers the widget shows (streaks, totals, languages). No scene
// needed, so the tests cover it. Everything here treats its input as untrusted:
// a field of the wrong type is dropped, strings and lists are capped.

var maxRepos = 100;

// GitHub's own rule for a login: letters, digits and single hyphens, up to 39.
function validName(s) {
    return typeof s === "string" && s.length <= 39 && /^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/.test(s) && s.indexOf("--") < 0;
}

function num(v) {
    var n = Number(v);
    return isFinite(n) && n >= 0 ? Math.floor(n) : 0;
}

function str(v, max) {
    return typeof v === "string" ? v.slice(0, max) : "";
}

// "@name arg\nbody" sections -> { name: { arg, body } }
function sections(text) {
    var out = {};
    var parts = String(text).split(/^@/m);
    for (var i = 0; i < parts.length; i++) {
        var nl = parts[i].indexOf("\n");
        var head = (nl < 0 ? parts[i] : parts[i].substr(0, nl)).trim().split(" ");
        if (head[0] === "")
            continue;
        out[head[0]] = { arg: head.slice(1).join(" "), body: nl < 0 ? "" : parts[i].substr(nl + 1).trim() };
    }
    return out;
}

function parseJson(text) {
    try {
        return JSON.parse(text);
    } catch (e) {
        return null;
    }
}

function parseUser(body) {
    var j = parseJson(body);
    if (!j || typeof j !== "object" || typeof j.login !== "string")
        return null;
    return {
        login: str(j.login, 39),
        name: str(j.name, 80),
        bio: str(j.bio, 300),
        location: str(j.location, 80),
        company: str(j.company, 80),
        blog: str(j.blog, 120),
        org: j.type === "Organization",
        followers: num(j.followers),
        following: num(j.following),
        repos: num(j.public_repos),
        gists: num(j.public_gists),
        since: epoch(j.created_at)
    };
}

function epoch(v) {
    if (typeof v !== "string" || v === "")
        return 0;
    var t = Date.parse(v);
    return isNaN(t) ? 0 : Math.floor(t / 1000);
}

// The repository lines: a "{" starts one, then `"key": value,` lines, each of
// which is JSON on its own.
function parseRepos(body) {
    var out = [];
    var cur = null;
    var lines = String(body).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "{") {
            if (out.length >= maxRepos)
                break;
            cur = { name: "", desc: "", stars: 0, forks: 0, lang: "", pushed: 0, fork: false, archived: false };
            out.push(cur);
            continue;
        }
        if (!cur || line === "")
            continue;
        var kv = parseJson("{" + line.replace(/,$/, "") + "}");
        if (!kv)
            continue;
        for (var k in kv) {
            var v = kv[k];
            if (k === "name") cur.name = str(v, 100);
            else if (k === "description") cur.desc = str(v, 200);
            else if (k === "stargazers_count") cur.stars = num(v);
            else if (k === "forks_count") cur.forks = num(v);
            else if (k === "language") cur.lang = str(v, 40);
            else if (k === "pushed_at") cur.pushed = epoch(v);
            else if (k === "fork") cur.fork = v === true;
            else if (k === "archived") cur.archived = v === true;
        }
    }
    return out.filter(function (r) { return r.name !== ""; });
}

// "D date id level" + "C id count" lines -> days in date order: { date, level 0..4, count }.
function parseGraph(body) {
    var days = {};
    var order = [];
    var lines = String(body).split("\n");
    for (var i = 0; i < lines.length && i < 1200; i++) {
        var f = lines[i].trim().split(" ");
        if (f[0] === "D" && f.length === 4 && /^\d{4}-\d\d-\d\d$/.test(f[1]) && /^[0-4]$/.test(f[3])) {
            days[f[2]] = { date: f[1], level: Number(f[3]), count: 0 };
            order.push(f[2]);
        } else if (f[0] === "C" && f.length === 3 && days[f[1]]) {
            days[f[1]].count = f[2] === "No" ? 0 : num(f[2].replace(/,/g, ""));
        }
    }
    var out = order.map(function (id) { return days[id]; });
    out.sort(function (a, b) { return a.date < b.date ? -1 : (a.date > b.date ? 1 : 0); });
    return out;
}

// The GraphQL answer for the calendar: weeks[].contributionDays[] of { date, contributionCount, contributionLevel }.
var levels = { NONE: 0, FIRST_QUARTILE: 1, SECOND_QUARTILE: 2, THIRD_QUARTILE: 3, FOURTH_QUARTILE: 4 };

function parseGraphql(body) {
    var j = parseJson(body);
    var weeks = j && j.data && j.data.user && j.data.user.contributionsCollection
        && j.data.user.contributionsCollection.contributionCalendar
        && j.data.user.contributionsCollection.contributionCalendar.weeks;
    if (!Array.isArray(weeks))
        return [];
    var out = [];
    for (var w = 0; w < weeks.length && w < 60; w++) {
        var days = weeks[w] && weeks[w].contributionDays;
        if (!Array.isArray(days))
            continue;
        for (var d = 0; d < days.length && d < 7; d++) {
            var x = days[d];
            if (x && typeof x.date === "string" && /^\d{4}-\d\d-\d\d$/.test(x.date))
                out.push({ date: x.date, count: num(x.contributionCount), level: levels[x.contributionLevel] || 0 });
        }
    }
    out.sort(function (a, b) { return a.date < b.date ? -1 : (a.date > b.date ? 1 : 0); });
    return out;
}

// The calendar as columns of seven (Sunday first), the way GitHub draws it; the
// first column may start part-way down and the last stop part-way.
// `weeks` caps how many columns, newest kept.
function weeksOf(days, weeks) {
    if (days.length === 0)
        return [];
    var cols = [];
    var col = [];
    var first = weekday(days[0].date);
    for (var p = 0; p < first; p++)
        col.push(null);
    for (var i = 0; i < days.length; i++) {
        col.push(days[i]);
        if (col.length === 7) {
            cols.push(col);
            col = [];
        }
    }
    if (col.length > 0)
        cols.push(col);
    return weeks > 0 ? cols.slice(-weeks) : cols;
}

// 0 = Sunday ... 6 = Saturday, from "YYYY-MM-DD" without a time zone in the way.
function weekday(date) {
    var p = date.split("-");
    return new Date(Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2]))).getUTCDay();
}

// Numbers for the calendar: total, current and longest streak, the best day,
// the number of active days and the days of the week summed up (Sunday first).
// A streak is days with at least one contribution; today with none yet does not
// break the current streak (the day is not over).
function graphStats(days) {
    var s = { total: 0, active: 0, current: 0, longest: 0, best: null, weekdays: [0, 0, 0, 0, 0, 0, 0] };
    var run = 0;
    for (var i = 0; i < days.length; i++) {
        var d = days[i];
        s.total += d.count;
        s.weekdays[weekday(d.date)] += d.count;
        if (d.count > 0) {
            s.active += 1;
            run += 1;
            s.longest = Math.max(s.longest, run);
            if (!s.best || d.count > s.best.count)
                s.best = { date: d.date, count: d.count };
        } else {
            run = 0;
        }
    }
    var i2 = days.length - 1;
    if (i2 >= 0 && days[i2].count === 0)
        i2 -= 1;
    var cur = 0;
    while (i2 >= 0 && days[i2].count > 0) {
        cur += 1;
        i2 -= 1;
    }
    s.current = cur;
    return s;
}

// Totals and rankings from the repositories. Forks are left out unless asked
// for (a fork is rarely what the person built); archived ones still count.
function repoStats(repos, withForks) {
    var list = repos.filter(function (r) { return withForks || !r.fork; });
    var stars = 0;
    var forks = 0;
    var langs = {};
    var counted = 0;
    list.forEach(function (r) {
        stars += r.stars;
        forks += r.forks;
        if (r.lang !== "") {
            langs[r.lang] = (langs[r.lang] || 0) + 1;
            counted += 1;
        }
    });
    var ranked = Object.keys(langs).map(function (k) { return { name: k, n: langs[k] }; });
    ranked.sort(function (a, b) { return b.n - a.n || (a.name < b.name ? -1 : 1); });
    // the languages beyond the fifth are folded into "other"
    var top = ranked.slice(0, 5);
    var rest = ranked.slice(5).reduce(function (a, l) { return a + l.n; }, 0);
    if (rest > 0)
        top.push({ name: "", n: rest });
    top.forEach(function (l) { l.pct = counted > 0 ? l.n / counted : 0; });

    var byStars = list.slice().sort(function (a, b) { return b.stars - a.stars || b.pushed - a.pushed; });
    var byPush = list.slice().sort(function (a, b) { return b.pushed - a.pushed; });
    return { count: list.length, stars: stars, forks: forks, languages: top, byStars: byStars, byPush: byPush };
}

// 1234 -> "1.2k", 1500000 -> "1.5M"
function compact(n) {
    if (n < 1000)
        return String(n);
    if (n < 1000000)
        return (n < 10000 ? (n / 1000).toFixed(1) : String(Math.round(n / 1000))).replace(/\.0$/, "") + "k";
    return (n / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
}

// How long ago, as { n, unit } with unit one of "m", "h", "d", "mo", "y".
function ago(at, now) {
    var s = Math.max(0, now - at);
    if (s < 3600) return { n: Math.max(1, Math.floor(s / 60)), unit: "m" };
    if (s < 86400) return { n: Math.floor(s / 3600), unit: "h" };
    if (s < 86400 * 60) return { n: Math.floor(s / 86400), unit: "d" };
    if (s < 86400 * 730) return { n: Math.floor(s / (86400 * 30)), unit: "mo" };
    return { n: Math.floor(s / (86400 * 365)), unit: "y" };
}

// The whole reading from the script's output: { user, repos, days } or an error
// string ("notfound" | "limited" | "offline"). A missing graph is not an error:
// the widget just has no calendar to draw.
function parse(text) {
    var s = sections(text);
    if (s.error) {
        var word = s.error.arg.split(" ")[0];
        return { error: ["notfound", "limited"].indexOf(word) >= 0 ? word : "offline",
                 resetAt: word === "limited" ? num(s.error.arg.split(" ")[1]) : 0 };
    }
    var user = s.user ? parseUser(s.user.body) : null;
    if (!user)
        return { error: "offline" };
    var avatar = s.avatar && /^\/[^\n\0]+$/.test(s.avatar.arg) ? s.avatar.arg : "";
    return {
        user: user,
        repos: s.repos ? parseRepos(s.repos.body) : [],
        days: s.graphql ? parseGraphql(s.graphql.body) : (s.graph ? parseGraph(s.graph.body) : []),
        // "ok", "none" or "bad" when the gh login was asked for, else ""
        login: s.login && ["ok", "none", "bad"].indexOf(s.login.arg) >= 0 ? s.login.arg : "",
        avatar: avatar
    };
}

// Made-up numbers for a library thumbnail and for a widget with no name yet, so
// the card is not empty. The calendar is a fixed pattern ending on `now`.
function sample(now) {
    var days = [];
    var end = Math.floor(now / 86400);
    for (var i = 370; i >= 0; i--) {
        var t = new Date((end - i) * 86400 * 1000);
        var date = t.getUTCFullYear() + "-" + (t.getUTCMonth() < 9 ? "0" : "") + (t.getUTCMonth() + 1) + "-" + (t.getUTCDate() < 10 ? "0" : "") + t.getUTCDate();
        var wd = t.getUTCDay();
        var v = (i * 7919 + (i % 13) * 31 + (i % 5) * 17) % 11;
        var count = wd === 0 || wd === 6 ? Math.max(0, v - 7) : Math.max(0, v - 2);
        if (i < 9 && i > 0)
            count = 2 + (i * 3) % 7;      // a current streak to show
        days.push({ date: date, count: count, level: count === 0 ? 0 : count < 3 ? 1 : count < 6 ? 2 : count < 9 ? 3 : 4 });
    }
    return {
        user: { login: "octocat", name: "The Octocat", bio: "Building small tools, mostly for the terminal.", location: "San Francisco",
                company: "@github", blog: "", org: false, followers: 9400, following: 9, repos: 8, gists: 8, since: now - 86400 * 365 * 15 },
        repos: [
            { name: "hello-world", desc: "", stars: 2400, forks: 1900, lang: "Ruby", pushed: now - 86400 * 2, fork: false, archived: false },
            { name: "dotfiles", desc: "", stars: 1280, forks: 140, lang: "Shell", pushed: now - 3600 * 5, fork: false, archived: false },
            { name: "spoon-knife", desc: "", stars: 790, forks: 13000, lang: "HTML", pushed: now - 86400 * 40, fork: false, archived: false },
            { name: "linguist", desc: "", stars: 520, forks: 60, lang: "Ruby", pushed: now - 86400 * 9, fork: false, archived: false },
            { name: "git-sizer", desc: "", stars: 310, forks: 25, lang: "Go", pushed: now - 86400 * 120, fork: false, archived: false },
            { name: "notes", desc: "", stars: 12, forks: 1, lang: "TypeScript", pushed: now - 86400 * 300, fork: false, archived: false }
        ],
        days: days,
        avatar: ""
    };
}
