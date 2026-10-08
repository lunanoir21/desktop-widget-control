import QtQuick
import QtTest
import "../ui/js/Cover.js" as Cover

TestCase {
    name: "Cover"

    function test_the_hosts_the_common_players_use_are_allowed() {
        verify(Cover.allowed("https://i.scdn.co/image/ab67616d0000b273b1f99ea4d9bf47dd43ad600f"));
        verify(Cover.allowed("https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"));
        verify(Cover.allowed("https://lh3.googleusercontent.com/aBcD-123_xyz=w544-h544-l90-rj"));
        verify(Cover.allowed("https://is1-ssl.mzstatic.com/image/thumb/Music/v4/ab/cd/ef/cover.jpg"));
        verify(Cover.allowed("https://e-cdns-images.dzcdn.net/images/cover/abcdef/500x500.jpg"));
    }

    function test_anything_else_is_refused() {
        verify(!Cover.allowed("http://i.scdn.co/image/abc"));                       // not HTTPS
        verify(!Cover.allowed("https://evil.example/image/abc"));
        verify(!Cover.allowed("https://i.scdn.co.evil.example/image/abc"));          // look-alike host
        verify(!Cover.allowed("https://evil.example/i.scdn.co/image/abc"));
        verify(!Cover.allowed("https://i.scdn.co/image/abc?track=1"));               // no query string (a tracker)
        verify(!Cover.allowed("https://i.scdn.co/image/../../etc/passwd"));
        verify(!Cover.allowed("https://user@i.scdn.co/image/abc"));
        verify(!Cover.allowed("https://i.scdn.co/image/abc def"));
        verify(!Cover.allowed("https://i.scdn.co/image/<img src=x>"));
        verify(!Cover.allowed("file:///etc/passwd"));
        verify(!Cover.allowed("data:image/png;base64,AAAA"));
        verify(!Cover.allowed(""));
        verify(!Cover.allowed(null));
        verify(!Cover.allowed("https://i.scdn.co/image/" + new Array(600).join("a")));
    }
}
