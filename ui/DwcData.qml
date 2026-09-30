pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The one place system numbers are read.
//
// A source only runs while at least one widget has asked for it, at the
// fastest refresh any of them asked for, so ten widgets showing the CPU cost
// one read of /proc/stat, and a desktop without a disk widget never runs `df`.
// Widgets ask through DwcNeed (DwcNeed.qml); nothing here polls on its own.
Item {
    id: root

    // Set by the IPC `pause` call: every source stops, widgets keep their last value.
    property bool paused: false
    // Hidden widgets need no numbers either.
    readonly property bool idle: paused || !DwcStore.shown

    // key -> { consumerId: intervalMs }
    property var wants: ({})
    property int serial: 0

    function nextId() {
        root.serial += 1;
        return "n" + root.serial;
    }

    function want(key, who, ms) {
        var cur = Object.assign({}, root.wants[key] || {});
        cur[who] = ms;
        var next = Object.assign({}, root.wants);
        next[key] = cur;
        root.wants = next;
    }

    function drop(key, who) {
        if (!root.wants[key] || root.wants[key][who] === undefined)
            return;
        var cur = Object.assign({}, root.wants[key]);
        delete cur[who];
        var next = Object.assign({}, root.wants);
        next[key] = cur;
        root.wants = next;
    }

    // Fastest refresh asked for, in ms; 0 when nobody wants the source.
    function interval(key) {
        var c = root.wants[key];
        if (!c)
            return 0;
        var best = 0;
        for (var who in c)
            if (best === 0 || c[who] < best)
                best = c[who];
        return best;
    }

    function active(key) {
        return !root.idle && root.interval(key) > 0;
    }

    function push(arr, v) {
        var h = arr.slice(-59);
        h.push(v);
        return h;
    }

    // ---- clock ---------------------------------------------------------------
    // "clock" for minute precision, "clock.sec" when something shows seconds.
    readonly property date now: clock.date

    SystemClock {
        id: clock
        enabled: !root.idle && (root.interval("clock") > 0 || root.interval("clock.sec") > 0)
        precision: root.interval("clock.sec") > 0 ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ---- cpu -----------------------------------------------------------------
    property real cpuUsage: 0
    property var cpuHistory: []
    property var lastCpu: null

    Timer {
        interval: Math.max(500, root.interval("cpu"))
        running: root.active("cpu")
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuFile.reload()
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        onLoaded: {
            var line = cpuFile.text().split("\n")[0].trim().split(/\s+/);
            var v = [];
            for (var i = 1; i < line.length && i < 9; i++)
                v.push(Number(line[i]));
            var total = v.reduce(function (a, b) { return a + b; }, 0);
            var idle = v[3] + (v[4] || 0);
            if (root.lastCpu) {
                var dt = total - root.lastCpu.total;
                var di = idle - root.lastCpu.idle;
                if (dt > 0) {
                    root.cpuUsage = Math.max(0, Math.min(1, 1 - di / dt));
                    root.cpuHistory = root.push(root.cpuHistory, root.cpuUsage);
                }
            }
            root.lastCpu = { total: total, idle: idle };
        }
    }

    // ---- memory --------------------------------------------------------------
    property real memTotal: 0     // bytes
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real memFrac: memTotal > 0 ? memUsed / memTotal : 0
    property var memHistory: []

    Timer {
        interval: Math.max(500, root.interval("mem"))
        running: root.active("mem")
        repeat: true
        triggeredOnStart: true
        onTriggered: memFile.reload()
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            var got = {};
            var lines = memFile.text().split("\n");
            for (var i = 0; i < lines.length; i++) {
                var m = lines[i].match(/^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)/);
                if (m)
                    got[m[1]] = Number(m[2]) * 1024;
            }
            if (got.MemTotal === undefined)
                return;
            root.memTotal = got.MemTotal;
            root.memUsed = got.MemTotal - (got.MemAvailable || 0);
            root.swapTotal = got.SwapTotal || 0;
            root.swapUsed = (got.SwapTotal || 0) - (got.SwapFree || 0);
            root.memHistory = root.push(root.memHistory, root.memFrac);
        }
    }

    // ---- network -------------------------------------------------------------
    // netRates: { iface: { rx, tx } } in bytes per second; "auto" is every
    // physical-looking interface added together.
    property var netRates: ({})
    property var netIfaces: []
    property var lastNet: null
    signal netUpdated()

    Timer {
        interval: Math.max(500, root.interval("net"))
        running: root.active("net")
        repeat: true
        triggeredOnStart: true
        onTriggered: netFile.reload()
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            var now = Date.now();
            var cur = {};
            var lines = netFile.text().split("\n");
            for (var i = 2; i < lines.length; i++) {
                var m = lines[i].match(/^\s*([^:\s]+):\s*(.*)$/);
                if (!m)
                    continue;
                var f = m[2].trim().split(/\s+/);
                cur[m[1]] = { rx: Number(f[0]), tx: Number(f[8]) };
            }
            var names = Object.keys(cur);
            if (root.lastNet) {
                var dt = (now - root.lastNet.at) / 1000;
                var rates = {};
                var autoRx = 0;
                var autoTx = 0;
                for (var k = 0; k < names.length; k++) {
                    var n = names[k];
                    var prev = root.lastNet.v[n];
                    if (!prev || dt <= 0)
                        continue;
                    var rx = Math.max(0, (cur[n].rx - prev.rx) / dt);
                    var tx = Math.max(0, (cur[n].tx - prev.tx) / dt);
                    rates[n] = { rx: rx, tx: tx };
                    if (n !== "lo" && !/^(docker|veth|br-|virbr|tun|tap)/.test(n)) {
                        autoRx += rx;
                        autoTx += tx;
                    }
                }
                rates.auto = { rx: autoRx, tx: autoTx };
                root.netRates = rates;
                root.netUpdated();
            }
            root.netIfaces = names.filter(function (n) { return n !== "lo"; });
            root.lastNet = { at: now, v: cur };
        }
    }

    // ---- temperature ---------------------------------------------------------
    property real temp: 0         // °C
    property bool tempAvailable: false
    property string tempPath: ""
    property bool tempProbed: false
    property var tempHistory: []

    Timer {
        interval: Math.max(1000, root.interval("temp"))
        running: root.active("temp") && root.tempPath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: tempFile.reload()
    }

    // Finds the CPU sensor once: the usual hwmon drivers first, then any thermal zone.
    Process {
        id: tempProbe
        command: ["sh", "-c",
            'for d in /sys/class/hwmon/hwmon*; do n=$(cat "$d/name" 2>/dev/null); '
            + 'case "$n" in k10temp|coretemp|zenpower|cpu_thermal|acpitz) '
            + 'f="$d/temp1_input"; [ -r "$f" ] && echo "$f" && exit 0;; esac; done; '
            + 'for f in /sys/class/thermal/thermal_zone*/temp; do [ -r "$f" ] && echo "$f" && exit 0; done']
        stdout: StdioCollector {
            onStreamFinished: {
                root.tempPath = text.trim();
                root.tempAvailable = root.tempPath !== "";
            }
        }
    }

    FileView {
        id: tempFile
        path: root.tempPath
        onLoaded: {
            var v = Number(tempFile.text().trim());
            if (!isNaN(v)) {
                root.temp = v / 1000;
                root.tempHistory = root.push(root.tempHistory, root.temp);
            }
        }
    }

    Connections {
        target: root
        function onWantsChanged() {
            if (!root.tempProbed && root.interval("temp") > 0) {
                root.tempProbed = true;
                tempProbe.running = true;
            }
        }
    }

    // ---- disk ----------------------------------------------------------------
    property var disks: []        // [{ target, used, size }] in bytes

    Timer {
        interval: Math.max(5000, root.interval("disk"))
        running: root.active("disk")
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!dfProc.running)
                dfProc.running = true;
        }
    }

    Process {
        id: dfProc
        command: ["df", "-B1", "--output=target,used,size", "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs", "-x", "overlay", "-x", "efivarfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = text.split("\n");
                for (var i = 1; i < lines.length; i++) {
                    var m = lines[i].match(/^(.+?)\s+(\d+)\s+(\d+)\s*$/);
                    if (m && Number(m[3]) > 0)
                        out.push({ target: m[1], used: Number(m[2]), size: Number(m[3]) });
                }
                root.disks = out;
            }
        }
    }

    // ---- audio spectrum (cava) -------------------------------------------------
    // Runs `cava` only while a media widget with the visualizer on is playing,
    // and is skipped altogether when cava is not installed. The config is
    // written to the runtime dir; bands come back as 0..1 values, 24 per frame.
    property var spectrum: []
    property bool cavaAvailable: false

    Process {
        command: ["sh", "-c", "command -v cava"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.cavaAvailable = text.trim() !== "" }
    }

    Process {
        id: cavaProc
        running: root.cavaAvailable && root.active("spectrum")
        command: ["sh", "-c",
            'cfg="${XDG_RUNTIME_DIR:-/tmp}/desktop-widget-control-cava.conf"; '
            + 'printf "%s\n" "[general]" "bars = 24" "framerate = 30" "[output]" "method = raw" '
            + '"raw_target = /dev/stdout" "data_format = ascii" "ascii_max_range = 100" "channels = mono" '
            + '"[smoothing]" "monstercat = 1" "waves = 0" > "$cfg"; exec cava -p "$cfg"']
        stdout: SplitParser {
            onRead: line => {
                var parts = line.split(";");
                var out = [];
                for (var i = 0; i < parts.length; i++)
                    if (parts[i] !== "")
                        out.push(Math.min(1, Number(parts[i]) / 100));
                if (out.length > 0)
                    root.spectrum = out;
            }
        }
        onRunningChanged: if (!running) root.spectrum = []
    }

    // ---- formatting helpers the widgets share --------------------------------

    function bytes(n, digits) {
        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        var v = n;
        while (v >= 1000 && i < u.length - 1) {
            v /= 1000;
            i++;
        }
        return v.toFixed(i === 0 ? 0 : (digits === undefined ? (v < 10 ? 1 : 0) : digits)) + " " + u[i];
    }

    function rate(bytesPerSec, bits) {
        var v = bits ? bytesPerSec * 8 : bytesPerSec;
        var u = bits ? ["b/s", "Kb/s", "Mb/s", "Gb/s"] : ["B/s", "KB/s", "MB/s", "GB/s"];
        var i = 0;
        while (v >= 1000 && i < u.length - 1) {
            v /= 1000;
            i++;
        }
        return v.toFixed(i === 0 || v >= 100 ? 0 : 1) + " " + u[i];
    }
}
