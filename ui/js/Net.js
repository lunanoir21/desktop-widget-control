// The one way the widgets run `curl`: HTTPS only, a time limit, and a hard cap
// on how many bytes are read back (the answers we expect are a few kilobytes).
// `head -c` enforces the cap even when a server sends no length or keeps
// streaming, which --max-filesize alone does not. The URL is one argument,
// never spliced into a shell string.

var maxBytes = 131072;

function curl(url, seconds) {
    return ["sh", "-c",
        'curl -fsS --proto "=https" --max-time "$1" --max-filesize "$2" "$3" | head -c "$2"',
        "sh", String(seconds), String(maxBytes), url];
}
