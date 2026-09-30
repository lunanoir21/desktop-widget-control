import QtQuick
import Quickshell.Io
import ".."
import "../controls"

// Current weather and a short forecast from Open-Meteo (no key needed). The
// city is looked up once, then the forecast is refreshed every 15 minutes.
// Requests go through `curl`, with the URL passed as one argument.
DwcWidget {
    id: root

    // The place comes from the picker ({ name, lat, lon, … }); a plain `city`
    // text from an older layout is still looked up by name.
    readonly property var picked: root.opt("place", null)
    readonly property bool hasPlace: !!picked && picked.name !== undefined && isFinite(picked.lat) && isFinite(picked.lon)
    readonly property string city: root.hasPlace ? String(picked.name) : String(root.opt("city", "")).trim()
    readonly property string placeKey: root.hasPlace ? picked.lat + "," + picked.lon : root.city
    readonly property bool imperial: root.opt("units", "metric") === "imperial"
    readonly property bool showForecast: root.opt("forecast", true)
    readonly property string mode: root.small ? "s" : (root.rows >= 8 ? "l" : "m")

    // "nocity" | "loading" | "ok" | "offline" | "notfound"
    property string wstate: root.city === "" ? "nocity" : "loading"
    property var cur: null            // { t, feels, code, wind, day }
    property var days: []             // [{ date, code, hi, lo }]
    property string placeName: ""
    property string geoFor: ""
    property real lat: 0
    property real lon: 0

    // A library thumbnail (or an unset city) shows sample numbers so the card is not empty.
    readonly property bool sample: root.preview && root.city === ""
    readonly property var shownCur: root.sample ? { t: 22, feels: 21, code: 1, wind: 11, day: 1 } : root.cur
    readonly property var shownDays: root.sample ? [
        { date: "", code: 1, hi: 24, lo: 14 }, { date: "", code: 3, hi: 21, lo: 13 },
        { date: "", code: 61, hi: 18, lo: 12 }, { date: "", code: 0, hi: 25, lo: 15 },
        { date: "", code: 2, hi: 23, lo: 14 }] : root.days
    readonly property string shownState: root.sample ? "ok" : root.wstate

    // WMO weather code -> icon and label key.
    function kind(code) {
        if (code === 0) return { icon: "sun", key: "wx.clear" };
        if (code <= 2) return { icon: "partly", key: "wx.partly" };
        if (code === 3) return { icon: "cloud", key: "wx.cloudy" };
        if (code === 45 || code === 48) return { icon: "fog", key: "wx.fog" };
        if (code >= 51 && code <= 57) return { icon: "rain", key: "wx.drizzle" };
        if (code >= 61 && code <= 67) return { icon: "rain", key: "wx.rain" };
        if (code >= 71 && code <= 77) return { icon: "snow", key: "wx.snow" };
        if (code >= 80 && code <= 82) return { icon: "rain", key: "wx.showers" };
        if (code === 85 || code === 86) return { icon: "snow", key: "wx.snow" };
        if (code >= 95) return { icon: "storm", key: "wx.storm" };
        return { icon: "cloud", key: "wx.cloudy" };
    }

    function start() {
        if (root.preview || root.city === "") {
            root.wstate = root.city === "" ? "nocity" : root.wstate;
            return;
        }
        root.wstate = root.cur ? root.wstate : "loading";
        if (root.hasPlace) {
            // Already a point on the map: no lookup needed.
            root.lat = root.picked.lat;
            root.lon = root.picked.lon;
            root.placeName = String(root.picked.name);
            root.fetch();
            return;
        }
        if (root.geoFor !== root.city + "|" + Str.lang) {
            geo.command = ["curl", "-fsS", "--max-time", "15",
                "https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&language=" + Str.lang
                + "&name=" + encodeURIComponent(root.city)];
            geo.running = true;
        } else {
            root.fetch();
        }
    }

    function fetch() {
        var unit = root.imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "";
        forecast.command = ["curl", "-fsS", "--max-time", "15",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=5" + unit];
        forecast.running = true;
    }

    Timer {
        id: debounce
        interval: 800
        onTriggered: root.start()
    }
    onPlaceKeyChanged: debounce.restart()
    onImperialChanged: debounce.restart()
    Component.onCompleted: root.start()

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.city !== "" && !root.preview && !DwcData.idle
        onTriggered: root.start()
    }

    Process {
        id: geo
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text);
                    if (!j.results || j.results.length === 0) {
                        root.wstate = "notfound";
                        return;
                    }
                    root.lat = j.results[0].latitude;
                    root.lon = j.results[0].longitude;
                    root.placeName = j.results[0].name;
                    root.geoFor = root.city + "|" + Str.lang;
                    root.fetch();
                } catch (e) {
                    root.wstate = "offline";
                }
            }
        }
    }

    Process {
        id: forecast
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text);
                    root.cur = { t: Math.round(j.current.temperature_2m), feels: Math.round(j.current.apparent_temperature),
                                 code: j.current.weather_code, wind: Math.round(j.current.wind_speed_10m), day: j.current.is_day };
                    var d = [];
                    for (var i = 0; i < j.daily.time.length; i++)
                        d.push({ date: j.daily.time[i], code: j.daily.weather_code[i],
                                 hi: Math.round(j.daily.temperature_2m_max[i]), lo: Math.round(j.daily.temperature_2m_min[i]) });
                    root.days = d;
                    root.wstate = "ok";
                } catch (e) {
                    root.wstate = "offline";
                }
            }
        }
    }

    function dayName(item, i) {
        if (item.date === "")
            return ["Mon", "Tue", "Wed", "Thu", "Fri"][i];
        var p = item.date.split("-");
        return Str.fmt("ddd", new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])));
    }

    readonly property string deg: root.imperial ? "°F" : "°C"
    readonly property string speed: root.imperial ? "mph" : "km/h"

    // ---- message states ----
    Column {
        visible: root.shownState !== "ok"
        anchors.centerIn: parent
        width: parent.width
        spacing: 4
        DIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.shownState === "nocity" ? "sun" : "cloud"
            size: 26
            color: DwcTheme.muted
        }
        DText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.weight: Font.Medium
            text: root.shownState === "nocity" ? Str.t("w.pickCity")
                : root.shownState === "notfound" ? Str.t("w.notFound")
                : root.shownState === "offline" ? Str.t("w.offline") : Str.t("w.loading")
        }
        DText {
            visible: root.shownState === "nocity" && !root.small
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: DwcTheme.muted
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: Str.t("w.pickCitySub")
        }
    }

    // ---- small ----
    Column {
        visible: root.shownState === "ok" && root.mode === "s"
        anchors.fill: parent
        spacing: 0
        DIcon { name: root.kind(root.shownCur ? root.shownCur.code : 0).icon; size: Math.round(root.height * 0.28); color: root.tone("color") }
        Item { width: 1; height: Math.round(root.height * 0.05) }
        DText {
            width: parent.width
            face: "display"
            font.pixelSize: Math.round(root.height * 0.36)
            font.weight: Font.DemiBold
            text: (root.shownCur ? root.shownCur.t : "") + "°"
        }
        DText {
            width: parent.width
            font.pixelSize: 12
            color: DwcTheme.sub
            text: Str.t(root.kind(root.shownCur ? root.shownCur.code : 0).key)
        }
    }

    // ---- medium ----
    Item {
        visible: root.shownState === "ok" && root.mode === "m"
        anchors.fill: parent

        Column {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: root.showForecast ? parent.width * 0.42 : parent.width
            spacing: 0
            DText {
                width: parent.width
                face: "display"
                font.pixelSize: Math.round(root.height * 0.46)
                font.weight: Font.DemiBold
                text: (root.shownCur ? root.shownCur.t : "") + "°"
            }
            DText {
                width: parent.width
                font.pixelSize: 13
                text: Str.t(root.kind(root.shownCur ? root.shownCur.code : 0).key)
            }
            DText {
                width: parent.width
                font.pixelSize: 11
                color: DwcTheme.muted
                text: root.sample ? "Sample" : root.placeName
            }
        }

        Row {
            visible: root.showForecast
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: parent.width * 0.56
            Repeater {
                model: root.shownDays.slice(1, 5)
                delegate: Column {
                    required property var modelData
                    required property int index
                    width: parent.width / 4
                    spacing: 6
                    DText { width: parent.width; horizontalAlignment: Text.AlignHCenter; face: "mono"; font.pixelSize: 10; color: DwcTheme.muted; text: root.dayName(modelData, index + 1) }
                    DIcon { anchors.horizontalCenter: parent.horizontalCenter; name: root.kind(modelData.code).icon; size: 20; color: DwcTheme.sub }
                    DText { width: parent.width; horizontalAlignment: Text.AlignHCenter; face: "mono"; font.pixelSize: 11; text: modelData.hi + "°" }
                }
            }
        }
    }

    // ---- large ----
    Item {
        visible: root.shownState === "ok" && root.mode === "l"
        anchors.fill: parent

        Row {
            id: head
            spacing: 14
            DIcon { anchors.verticalCenter: parent.verticalCenter; name: root.kind(root.shownCur ? root.shownCur.code : 0).icon; size: 46; color: root.tone("color") }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                DText { face: "display"; font.pixelSize: 48; font.weight: Font.DemiBold; text: (root.shownCur ? root.shownCur.t : "") + "°" }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                DText { font.pixelSize: 14; font.weight: Font.Medium; text: Str.t(root.kind(root.shownCur ? root.shownCur.code : 0).key) }
                DText { font.pixelSize: 11; color: DwcTheme.muted; text: root.sample ? "Sample" : root.placeName }
            }
        }
        DText {
            anchors { top: head.bottom; topMargin: 6; left: parent.left }
            face: "mono"
            font.pixelSize: 11
            color: DwcTheme.sub
            text: Str.t("w.feels") + " " + (root.shownCur ? root.shownCur.feels : "") + "°  ·  " + Str.t("w.wind") + " " + (root.shownCur ? root.shownCur.wind : "") + " " + root.speed
        }

        Column {
            visible: root.showForecast
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            Repeater {
                model: root.shownDays
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 30
                    DText { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 44; face: "mono"; font.pixelSize: 12; color: DwcTheme.sub; text: root.dayName(modelData, index) }
                    DIcon { anchors { left: parent.left; leftMargin: 56; verticalCenter: parent.verticalCenter } name: root.kind(modelData.code).icon; size: 18; color: DwcTheme.sub }
                    DText { anchors { right: parent.right; verticalCenter: parent.verticalCenter } face: "mono"; font.pixelSize: 12; text: modelData.lo + "°  " + modelData.hi + "°" }
                }
            }
        }
    }
}
