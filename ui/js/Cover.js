// Which cover-art addresses a player may hand us. A player's metadata is outside text, so
// the shell never fetches whatever it names (that was the 0.2.1 fix: no `<img>` or tracker
// URL from a track title). The few image hosts the common players really use are allowed,
// as plain HTTPS paths with no query, and only scripts/cover.sh downloads them, into the cache.
//   Spotify            https://i.scdn.co/image/<id>
//   YouTube (Chromium) https://i.ytimg.com/vi/<id>/<name>.jpg
//   YouTube Music      https://lh3.googleusercontent.com/<id>
//   Apple Music        https://is1-ssl.mzstatic.com/image/...
//   Deezer             https://e-cdns-images.dzcdn.net/images/...
// The same rule is repeated in scripts/cover.sh; a test keeps the two in step.

var hostPattern = "(i\\.scdn\\.co/image|i\\.ytimg\\.com/vi(_webp)?|lh3\\.googleusercontent\\.com|is[0-9]-ssl\\.mzstatic\\.com/image|e-cdns-images\\.dzcdn\\.net/images)";
var rule = new RegExp("^https://" + hostPattern + "/[A-Za-z0-9._/=-]+$");

function allowed(url) {
    return typeof url === "string" && url.length < 512 && url.indexOf("..") < 0 && rule.test(url);
}
