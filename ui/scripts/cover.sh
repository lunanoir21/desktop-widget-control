#!/bin/sh
# Downloads one album cover a player named, into the cache, and prints where it is.
#
#   sh cover.sh URL
#
# Only a short list of image hosts is allowed (the same rule as ui/js/Cover.js), as a plain
# HTTPS path with no query string and no redirects followed. The download is time- and
# size-limited, and only a real PNG, JPEG or WebP is kept. The folder is private and keeps
# the newest 40 covers. Prints nothing when the address is refused or the download fails.
url=$1

printf '%s\n' "$url" | grep -Eq '^https://(i\.scdn\.co/image|i\.ytimg\.com/vi(_webp)?|lh3\.googleusercontent\.com|is[0-9]-ssl\.mzstatic\.com/image|e-cdns-images\.dzcdn\.net/images)/[A-Za-z0-9._/=-]+$' || exit 0
case "$url" in
    *..*) exit 0 ;;
esac
[ ${#url} -lt 512 ] || exit 0

dir=${XDG_CACHE_HOME:-$HOME/.cache}/desktop-widget-control/covers
mkdir -p "$dir" && chmod 700 "$dir" || exit 0
key=$(printf '%s' "$url" | sha256sum | cut -c1-40)
file=$dir/$key.img

if [ ! -s "$file" ]; then
    tmp=$(mktemp "$dir/.dl.XXXXXX") || exit 0
    trap 'rm -f "$tmp"' EXIT
    code=$(curl -sS --proto '=https' --max-time 15 --max-filesize 1048576 -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null || echo 000)
    [ "$code" = 200 ] || exit 0
    # the first bytes say what it is: PNG, JPEG, or WebP (RIFF....WEBP)
    magic=$(head -c 12 "$tmp" | od -An -tx1 | tr -d ' \n')
    case "$magic" in
        89504e47*|ffd8ff*|52494646????????57454250) ;;
        *) exit 0 ;;
    esac
    chmod 600 "$tmp" && mv "$tmp" "$file" || exit 0
    # keep the folder small
    ls -t "$dir" 2>/dev/null | tail -n +41 | while IFS= read -r old; do rm -f "$dir/$old"; done
fi
printf '%s\n' "$file"
