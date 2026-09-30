import QtQuick
import Quickshell.Io
import ".."
import "../js/Countries.js" as Countries
import "../js/Net.js" as Net

// Choose a place: pick a country (or any), type a city, pick from what Open-Meteo
// finds. `value` is the chosen place ({ name, admin, country, cc, lat, lon }) or
// null; placePicked(place) is emitted when one is chosen. Nothing is searched
// until you type, and typing waits a moment so a fast typist makes one request.
Item {
    id: root

    property var value: null
    signal placePicked(var place)

    property string country: ""           // ISO code, "" = any
    property string query: ""
    property var results: []
    property string status: "idle"        // "idle" | "searching" | "none" | "offline"

    implicitHeight: col.implicitHeight
    implicitWidth: 260

    readonly property var countryChoices: {
        var out = [{ v: "", label: Str.t("pick.anyCountry") }];
        return out.concat(Countries.choices(Str.lang));
    }

    function search() {
        var q = root.query.trim();
        if (q.length < 2) {
            root.results = [];
            root.status = "idle";
            return;
        }
        root.status = "searching";
        proc.command = Net.curl("https://geocoding-api.open-meteo.com/v1/search?count=8&format=json&language=" + Str.lang
            + "&name=" + encodeURIComponent(q) + (root.country !== "" ? "&countryCode=" + root.country : ""), 10);
        proc.running = true;
    }

    Timer {
        id: wait
        interval: 380
        onTriggered: root.search()
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text);
                    var out = [];
                    var src = j.results || [];
                    for (var i = 0; i < Math.min(src.length, 8); i++)
                        out.push({ name: src[i].name, admin: src[i].admin1 || "", country: src[i].country || "",
                                   cc: src[i].country_code || "", lat: src[i].latitude, lon: src[i].longitude });
                    root.results = out;
                    root.status = out.length ? "idle" : "none";
                } catch (e) {
                    root.results = [];
                    root.status = "offline";
                }
            }
        }
    }

    function describe(p) {
        var parts = [p.name];
        if (p.admin && p.admin !== p.name)
            parts.push(p.admin);
        if (p.country)
            parts.push(p.country);
        return parts.join(", ");
    }

    Column {
        id: col
        width: parent.width
        spacing: 8

        // what is chosen now
        Rectangle {
            width: parent.width
            height: 34
            radius: 8
            color: DwcTheme.alpha(DwcTheme.acc, 0.12)
            border.width: 1
            border.color: DwcTheme.alpha(DwcTheme.acc, 0.4)
            DIcon {
                id: pin
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                name: "pin"
                size: 14
                color: DwcTheme.acc
            }
            DText {
                anchors { left: pin.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: root.value ? root.describe(root.value) : Str.t("pick.none")
                color: root.value ? DwcTheme.fg : DwcTheme.muted
            }
        }

        DText { font.pixelSize: 10; color: DwcTheme.muted; text: Str.t("pick.country").toUpperCase(); font.letterSpacing: 1 }
        DSelect {
            width: parent.width
            model: root.countryChoices
            current: root.country
            onPicked: v => {
                root.country = v;
                root.search();
            }
        }

        DText { font.pixelSize: 10; color: DwcTheme.muted; text: Str.t("pick.city").toUpperCase(); font.letterSpacing: 1 }
        DTextField {
            width: parent.width
            text: root.query
            placeholder: Str.t("pick.search")
            onEdited: t => {
                root.query = t;
                wait.restart();
            }
        }

        DText {
            visible: root.status !== "idle" || root.results.length > 0
            width: parent.width
            font.pixelSize: 11
            color: DwcTheme.muted
            text: root.status === "searching" ? Str.t("pick.searching")
                : root.status === "none" ? Str.t("pick.nothing")
                : root.status === "offline" ? Str.t("w.offline") : ""
        }

        Repeater {
            model: root.results
            delegate: Rectangle {
                required property var modelData
                width: col.width
                height: 34
                radius: 8
                color: hover.containsMouse ? DwcTheme.hover : "transparent"
                border.width: 1
                border.color: DwcTheme.line

                DText {
                    anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: root.describe(modelData)
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.placePicked(modelData);
                        root.results = [];
                        root.query = "";
                        root.status = "idle";
                    }
                }
            }
        }
    }
}
