import QtQuick
import QtTest
import "../ui/js/Github.js" as Github

TestCase {
    name: "Github"

    function test_names_follow_githubs_rule() {
        verify(Github.validName("octocat"));
        verify(Github.validName("a"));
        verify(Github.validName("Mona-Lisa-1"));
        verify(!Github.validName(""));
        verify(!Github.validName("-lead"));
        verify(!Github.validName("trail-"));
        verify(!Github.validName("dou--ble"));
        verify(!Github.validName("a b"));
        verify(!Github.validName("a/b"));
        verify(!Github.validName("x;rm -rf ~"));
        verify(!Github.validName(new Array(41).join("a")));
        verify(Github.validName(new Array(40).join("a")));
        verify(!Github.validName(42));
    }

    function test_sections_split_on_a_leading_at() {
        var s = Github.sections("@user\n{\"login\":\"a\"}\n@avatar /x/y z.img\n");
        compare(s.user.body, "{\"login\":\"a\"}");
        compare(s.avatar.arg, "/x/y z.img");
        compare(Github.sections("@error limited").error.arg, "limited");
    }

    function test_the_profile_keeps_only_what_it_needs_and_caps_it() {
        var u = Github.parseUser(JSON.stringify({ login: "octocat", name: "The Octocat", bio: new Array(1000).join("x"), followers: 12,
            following: "junk", public_repos: 8, created_at: "2011-01-25T18:44:36Z", type: "User", avatar_url: "https://x" }));
        compare(u.login, "octocat");
        compare(u.bio.length, 300);
        compare(u.followers, 12);
        compare(u.following, 0);
        compare(u.since, Date.parse("2011-01-25T18:44:36Z") / 1000);
        verify(!u.org);
        compare(Github.parseUser("not json"), null);
        compare(Github.parseUser(JSON.stringify({ name: "no login" })), null);
        verify(Github.parseUser(JSON.stringify({ login: "o", type: "Organization" })).org);
    }

    function test_repository_lines_become_records() {
        var body = ["{", '    "name": "linux",', '    "description": "Linux kernel \\"source\\" tree",', '    "fork": false,',
                    '    "pushed_at": "2026-10-08T15:41:09Z",', '    "stargazers_count": 251259,', '    "language": "C",',
                    '    "forks_count": 67021,', '    "archived": false', "{", '    "name": "fork-of-x",', '    "fork": true,',
                    '    "language": null,', '    "stargazers_count": 3', "{", '    "description": "a record with no name"'].join("\n");
        var r = Github.parseRepos(body);
        compare(r.length, 2);
        compare(r[0].name, "linux");
        compare(r[0].desc, 'Linux kernel "source" tree');
        compare(r[0].stars, 251259);
        compare(r[0].lang, "C");
        compare(r[1].fork, true);
        compare(r[1].lang, "");
    }

    function test_a_junk_line_does_not_stop_the_rest() {
        var r = Github.parseRepos(['{', '    "name": "a",', '    <b>not json</b>', '    "stargazers_count": 5'].join("\n"));
        compare(r.length, 1);
        compare(r[0].stars, 5);
    }

    function graphText(rows) {
        // rows: [date, level, count] -> the script's D / C lines, counts out of order on purpose
        var d = [];
        var c = [];
        rows.forEach(function (r, i) {
            d.push("D " + r[0] + " contribution-day-component-0-" + i + " " + r[1]);
            c.push("C contribution-day-component-0-" + i + " " + (r[2] === 0 ? "No" : r[2]));
        });
        return d.concat(c).join("\n");
    }

    function test_the_calendar_pairs_levels_with_counts_and_sorts_by_date() {
        var days = Github.parseGraph(graphText([["2026-10-06", 2, 4], ["2026-10-05", 0, 0], ["2026-10-07", 1, "1,234"]]));
        compare(days.length, 3);
        compare(days[0].date, "2026-10-05");
        compare(days[0].count, 0);
        compare(days[1].count, 4);
        compare(days[2].count, 1234);
        compare(days[2].level, 1);
    }

    function test_calendar_lines_with_bad_values_are_dropped() {
        var days = Github.parseGraph("D 2026-10-05 id1 9\nD yesterday id2 1\nD 2026-10-06 id3 3\nC nope 4\nC id3 7");
        compare(days.length, 1);
        compare(days[0].count, 7);
    }

    function day(date, count) {
        return { date: date, count: count, level: count > 0 ? 1 : 0 };
    }

    function test_streaks() {
        var days = [day("2026-10-01", 1), day("2026-10-02", 2), day("2026-10-03", 0), day("2026-10-04", 5), day("2026-10-05", 1), day("2026-10-06", 1)];
        var s = Github.graphStats(days);
        compare(s.total, 10);
        compare(s.active, 5);
        compare(s.longest, 3);
        compare(s.current, 3);
        compare(s.best.date, "2026-10-04");
    }

    function test_an_empty_today_does_not_break_the_streak() {
        var s = Github.graphStats([day("2026-10-03", 2), day("2026-10-04", 1), day("2026-10-05", 0)]);
        compare(s.current, 2);
        compare(Github.graphStats([day("2026-10-04", 0), day("2026-10-05", 0)]).current, 0);
        compare(Github.graphStats([]).best, null);
    }

    function test_weeks_start_on_sunday_and_keep_the_newest() {
        // 2026-10-04 is a Sunday
        var days = [];
        for (var i = 0; i < 16; i++)
            days.push(day("2026-10-" + (i + 4 < 10 ? "0" : "") + (i + 4), 1));
        var w = Github.weeksOf(days, 0);
        compare(w.length, 3);
        compare(w[0][0].date, "2026-10-04");
        compare(w[2].length, 2);
        compare(Github.weeksOf(days, 2).length, 2);
        compare(Github.weeksOf(days, 2)[1][0].date, "2026-10-18");
        // a calendar that starts on a Wednesday leaves three empty slots
        var mid = Github.weeksOf([day("2026-10-07", 1)], 0);
        compare(mid[0][0], null);
        compare(mid[0][3].date, "2026-10-07");
    }

    function repo(name, stars, lang, fork, pushed) {
        return { name: name, desc: "", stars: stars, forks: 1, lang: lang, pushed: pushed || 0, fork: fork === true, archived: false };
    }

    function test_forks_are_left_out_unless_asked_for() {
        var list = [repo("a", 10, "Go"), repo("b", 99, "Go", true), repo("c", 5, "Rust")];
        var s = Github.repoStats(list, false);
        compare(s.count, 2);
        compare(s.stars, 15);
        compare(s.byStars[0].name, "a");
        compare(Github.repoStats(list, true).stars, 114);
    }

    function test_languages_are_ranked_and_the_tail_is_folded() {
        var list = [];
        ["A", "A", "A", "B", "B", "C", "D", "E", "F", "G"].forEach(function (l, i) { list.push(repo("r" + i, i, l)); });
        list.push(repo("nolang", 1, ""));
        var langs = Github.repoStats(list, false).languages;
        compare(langs.length, 6);
        compare(langs[0].name, "A");
        compare(langs[0].n, 3);
        compare(langs[5].name, "");
        compare(langs[5].n, 2);
        var sum = 0;
        langs.forEach(function (l) { sum += l.pct; });
        verify(Math.abs(sum - 1) < 1e-9);
        compare(Github.repoStats([], false).languages.length, 0);
    }

    function test_recently_pushed_order() {
        var s = Github.repoStats([repo("old", 9, "Go", false, 10), repo("new", 1, "Go", false, 50)], false);
        compare(s.byPush[0].name, "new");
        compare(s.byStars[0].name, "old");
    }

    function test_compact_numbers() {
        compare(Github.compact(0), "0");
        compare(Github.compact(999), "999");
        compare(Github.compact(1000), "1k");
        compare(Github.compact(1234), "1.2k");
        compare(Github.compact(15300), "15k");
        compare(Github.compact(251259), "251k");
        compare(Github.compact(1500000), "1.5M");
    }

    function test_time_ago() {
        compare(Github.ago(1000, 1000).unit, "m");
        compare(Github.ago(0, 7200).n, 2);
        compare(Github.ago(0, 7200).unit, "h");
        compare(Github.ago(0, 86400 * 3).unit, "d");
        compare(Github.ago(0, 86400 * 100).unit, "mo");
        compare(Github.ago(0, 86400 * 800).unit, "y");
        compare(Github.ago(500, 100).n, 1);
    }

    function test_the_whole_reading() {
        var text = "@user\n" + JSON.stringify({ login: "octocat", followers: 3 }) + "\n@repos\n{\n    \"name\": \"a\"\n@graph\n" + graphText([["2026-10-05", 1, 2]])
            + "\n@avatar /home/x/.cache/desktop-widget-control/github-octocat.img\n";
        var r = Github.parse(text);
        compare(r.user.login, "octocat");
        compare(r.repos.length, 1);
        compare(r.days.length, 1);
        verify(r.avatar.indexOf("/") === 0);
        // no calendar or picture is fine
        var bare = Github.parse("@user\n" + JSON.stringify({ login: "o" }));
        compare(bare.days.length, 0);
        compare(bare.avatar, "");
    }

    function test_errors_and_junk() {
        compare(Github.parse("@error notfound").error, "notfound");
        compare(Github.parse("@error limited").error, "limited");
        compare(Github.parse("@error limited 1791493305").resetAt, 1791493305);
        compare(Github.parse("@error limited").resetAt, 0);
        compare(Github.parse("@error whatever").error, "offline");
        compare(Github.parse("").error, "offline");
        compare(Github.parse("@user\nnot json").error, "offline");
        compare(Github.parse("@user\n" + JSON.stringify({ login: "o" }) + "\n@avatar relative/path").avatar, "");
    }

    function test_the_graphql_calendar() {
        var body = JSON.stringify({ data: { user: { contributionsCollection: { contributionCalendar: { weeks: [
            { contributionDays: [{ date: "2026-10-05", contributionCount: 0, contributionLevel: "NONE" },
                                 { date: "2026-10-04", contributionCount: 12, contributionLevel: "FOURTH_QUARTILE" },
                                 { date: "junk", contributionCount: 3, contributionLevel: "NONE" }] }] } } } } });
        var days = Github.parseGraphql(body);
        compare(days.length, 2);
        compare(days[0].date, "2026-10-04");
        compare(days[0].count, 12);
        compare(days[0].level, 4);
        compare(days[1].level, 0);
        compare(Github.parseGraphql("not json").length, 0);
        compare(Github.parseGraphql(JSON.stringify({ errors: [] })).length, 0);
    }

    function test_a_logged_in_reading_prefers_graphql_and_reports_the_login() {
        var gql = JSON.stringify({ data: { user: { contributionsCollection: { contributionCalendar: { weeks: [
            { contributionDays: [{ date: "2026-10-04", contributionCount: 2, contributionLevel: "FIRST_QUARTILE" }] }] } } } } });
        var r = Github.parse("@user\n" + JSON.stringify({ login: "o" }) + "\n@login ok\n@graphql\n" + gql);
        compare(r.login, "ok");
        compare(r.days.length, 1);
        compare(r.days[0].count, 2);
        compare(Github.parse("@user\n" + JSON.stringify({ login: "o" })).login, "");
        compare(Github.parse("@user\n" + JSON.stringify({ login: "o" }) + "\n@login weird").login, "");
    }

    function test_the_sample_fills_every_part() {
        var s = Github.sample(1790000000);
        compare(s.days.length, 371);
        verify(Github.graphStats(s.days).current > 0);
        verify(Github.repoStats(s.repos, false).languages.length >= 3);
        compare(s.days[s.days.length - 1].date, new Date(Math.floor(1790000000 / 86400) * 86400 * 1000).toISOString().slice(0, 10));
    }
}
