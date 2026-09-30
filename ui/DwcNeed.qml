import QtQuick

// Declares that a widget needs a data source: put one inside the widget,
//
//     DwcNeed { source: "cpu"; interval: root.cfg.interval * 1000 }
//
// and the source runs for as long as the widget exists (and `enabled`).
// The matching release happens when the widget is destroyed, so removing a
// widget from the desktop stops whatever only it was using.
QtObject {
    id: need

    property string source: ""
    property int interval: 2000
    property bool enabled: true

    property string who: ""
    property string asked: ""

    function sync() {
        if (need.who === "")
            return;
        if (need.asked !== "" && (need.asked !== need.source || !need.enabled)) {
            DwcData.drop(need.asked, need.who);
            need.asked = "";
        }
        if (need.enabled && need.source !== "") {
            DwcData.want(need.source, need.who, need.interval);
            need.asked = need.source;
        }
    }

    onSourceChanged: sync()
    onIntervalChanged: sync()
    onEnabledChanged: sync()
    Component.onCompleted: {
        need.who = DwcData.nextId();
        need.sync();
    }
    Component.onDestruction: {
        if (need.asked !== "")
            DwcData.drop(need.asked, need.who);
    }
}
