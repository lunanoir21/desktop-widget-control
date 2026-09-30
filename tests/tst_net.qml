import QtQuick
import QtTest
import "../ui/js/Net.js" as Net

TestCase {
    name: "Net"

    function test_the_url_is_one_argument_not_part_of_a_shell_string() {
        var url = "https://example.org/?a=1;rm -rf ~&b=$(id)";
        var cmd = Net.curl(url, 10);
        compare(cmd[0], "sh");
        compare(cmd[cmd.length - 1], url);
        verify(cmd[2].indexOf("example") < 0 && cmd[2].indexOf("rm") < 0);
    }

    function test_https_only_a_time_limit_and_a_byte_cap() {
        var cmd = Net.curl("https://example.org/", 15);
        verify(cmd[2].indexOf('--proto "=https"') >= 0);
        verify(cmd[2].indexOf("--max-time") >= 0);
        verify(cmd[2].indexOf("--max-filesize") >= 0);
        verify(cmd[2].indexOf('head -c "$2"') >= 0, "a stream with no length is cut off by head");
        compare(cmd[4], "15");
        compare(cmd[5], String(Net.maxBytes));
        verify(Net.maxBytes <= 262144);
    }
}
