#!/bin/sh
# Reads what the GitHub profile widget shows, from public pages (and, only when
# asked, with the token of the GitHub CLI). Prints sections, each starting with a
# line "@name [arg]":
#
#   @user      the profile, raw JSON            (api.github.com/users/NAME)
#   @repos     one "{" per repository, then the few keys the widget uses
#   @graph     "D date id level" and "C id count" lines of the contribution graph
#   @graphql   the contribution calendar as GraphQL JSON (only when logged in)
#   @avatar    path of the cached picture (only with avatar=1)
#   @login     "ok", "none" (gh missing or not logged in) or "bad" (token refused)
#   @error     "notfound", "limited [epoch it lifts]" or "offline", and nothing else follows
#
#   sh github.sh NAME [1|0] [1|0]    whether to fetch the avatar, whether to use the `gh` login
#
# With the third argument the token of the GitHub CLI (`gh auth token`) is sent to
# api.github.com only: 5,000 reads an hour instead of 60, and a calendar that counts
# the private contributions you chose to show. The token goes in on stdin, never on the
# command line where `ps` would show it. It is only read when asked for.

# Everything read is bounded: HTTPS only, a time limit, a size limit on what curl
# will download and a second cut on what is printed. The name is checked against
# GitHub's own rule before it goes anywhere near a URL. The pages are reduced to
# the lines we need here, so the widget never parses a whole HTML page.
name=$1
want_avatar=${2:-0}
use_login=${3:-0}

case "$name" in
    ''|-*|*[!A-Za-z0-9-]*) echo "@error notfound"; exit 0 ;;
esac
[ ${#name} -le 39 ] || { echo "@error notfound"; exit 0; }

tmp=$(mktemp -d) || { echo "@error offline"; exit 0; }
trap 'rm -rf "$tmp"' EXIT

token=""
login=""
if [ "$use_login" = 1 ]; then
    if command -v gh >/dev/null 2>&1; then
        token=$(gh auth token 2>/dev/null | head -c 255)
    fi
    case "$token" in
        ''|*[!A-Za-z0-9_]*) token=""; login=none ;;
        *) login=ok ;;
    esac
fi

# get URL FILE LIMIT [auth] -> prints the HTTP status ("000" when curl itself failed).
# "auth" sends the token, and only ever to api.github.com.
get() {
    if [ "$4" = auth ] && [ -n "$token" ]; then
        printf 'Authorization: Bearer %s\n' "$token" | curl -sS --proto '=https' --max-time 15 --max-filesize "$3" -H @- \
            -H 'Accept: application/vnd.github+json' -D "$2.h" -o "$2" -w '%{http_code}' "$1" 2>/dev/null || echo 000
    else
        curl -sS --proto '=https' --max-time 15 --max-filesize "$3" -H 'Accept-Language: en' \
            -H 'Accept: application/vnd.github+json' -D "$2.h" -o "$2" -w '%{http_code}' "$1" 2>/dev/null || echo 000
    fi
}

code=$(get "https://api.github.com/users/$name" "$tmp/user" 65536 auth)
# a token GitHub refuses is dropped and the read is made without it
if [ "$code" = 401 ] && [ -n "$token" ]; then
    token=""
    login=bad
    code=$(get "https://api.github.com/users/$name" "$tmp/user" 65536)
fi
case "$code" in
    200) ;;
    404) echo "@error notfound"; exit 0 ;;
    403|429)
        # when the limit lifts, so the card can say so (the header holds only digits)
        reset=$(grep -i '^x-ratelimit-reset:' "$tmp/user.h" 2>/dev/null | tr -dc '0-9' | head -c 12)
        echo "@error limited $reset"
        exit 0 ;;
    *) echo "@error offline"; exit 0 ;;
esac
printf '@user\n'
head -c 32768 "$tmp/user"
printf '\n'
[ -n "$login" ] && printf '@login %s\n' "$login"

# The newest hundred repositories. The JSON is pretty-printed, so a repository's own
# keys are the ones indented four spaces (an owner's are indented six).
code=$(get "https://api.github.com/users/$name/repos?per_page=100&sort=pushed" "$tmp/repos" 1048576 auth)
if [ "$code" = 200 ]; then
    printf '@repos\n'
    sed -n -e 's/^  {$/{/p' \
        -e '/^    "\(name\|description\|stargazers_count\|forks_count\|language\|pushed_at\|fork\|archived\)": /p' \
        "$tmp/repos" | head -c 131072
fi

# The calendar. Logged in: GraphQL, which also counts private contributions when the
# profile shows them. Otherwise (or when that fails) GitHub's own calendar page: a page of
# small tables, one cell per day.
have_graph=0
if [ -n "$token" ]; then
    printf '{"query":"query($u:String!){user(login:$u){contributionsCollection{contributionCalendar{weeks{contributionDays{date contributionCount contributionLevel}}}}}}","variables":{"u":"%s"}}' "$name" > "$tmp/q.json"
    code=$(printf 'Authorization: Bearer %s\n' "$token" | curl -sS --proto '=https' --max-time 15 --max-filesize 1048576 -H @- \
        -H 'Content-Type: application/json' -d @"$tmp/q.json" -o "$tmp/gql" -w '%{http_code}' https://api.github.com/graphql 2>/dev/null || echo 000)
    if [ "$code" = 200 ] && grep -q '"contributionDays"' "$tmp/gql" 2>/dev/null; then
        printf '@graphql\n'
        head -c 131072 "$tmp/gql"
        printf '\n'
        have_graph=1
    fi
fi
if [ "$have_graph" = 0 ]; then
    code=$(get "https://github.com/users/$name/contributions" "$tmp/graph" 1048576)
    if [ "$code" = 200 ]; then
        printf '@graph\n'
        sed -n -e 's/.*data-date="\([0-9-]*\)" id="\(contribution-day-component-[0-9]*-[0-9]*\)" data-level="\([0-9]\)".*/D \1 \2 \3/p' \
            -e 's/.*for="\(contribution-day-component-[0-9]*-[0-9]*\)".*>\(No\|[0-9][0-9,]*\) contributions\{0,1\} on .*/C \1 \2/p' \
            "$tmp/graph" | head -c 65536
    fi
fi

if [ "$want_avatar" = 1 ]; then
    dir=${XDG_CACHE_HOME:-$HOME/.cache}/desktop-widget-control
    mkdir -p "$dir" && chmod 700 "$dir"
    pic=$dir/github-$name.img
    # once a day is plenty for a picture
    if [ -z "$(find "$pic" -mmin -1440 2>/dev/null)" ]; then
        code=$(curl -sSL --proto '=https' --proto-redir '=https' --max-time 15 --max-filesize 524288 -o "$tmp/pic" -w '%{http_code}' \
            "https://github.com/$name.png?size=160" 2>/dev/null || echo 000)
        # only a PNG or a JPEG is kept (the first bytes say which)
        magic=$(head -c 3 "$tmp/pic" 2>/dev/null | od -An -tx1 | tr -d ' \n')
        if [ "$code" = 200 ]; then
            case "$magic" in
                89504e|ffd8ff) mv "$tmp/pic" "$pic" && chmod 600 "$pic" ;;
            esac
        fi
    fi
    [ -r "$pic" ] && printf '@avatar %s\n' "$pic"
fi
exit 0
