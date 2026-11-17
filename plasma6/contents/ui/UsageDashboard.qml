import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

ColumnLayout {
    id: dashboard
    property bool compact: false
    property string status: "loading"
    property var fiveHour: null
    property var weekly: null
    property bool stale: false
    property int nowSeconds: 0
    signal settingsRequested()
    spacing: compact ? 2 : 12

    function resetText(item) {
        if (!item || !item.resets_at) return "Reset time unavailable"
        var seconds = Math.max(0, item.resets_at - nowSeconds)
        if (seconds < 60) return "Resets in <1 min"
        var minutes = Math.ceil(seconds / 60)
        var days = Math.floor(minutes / 1440)
        var hours = Math.floor((minutes % 1440) / 60)
        var mins = minutes % 60
        if (days) return "Resets in " + days + "d " + hours + "h"
        if (hours) return "Resets in " + hours + "h " + mins + "m"
        return "Resets in " + mins + "m"
    }

    Controls.Label {
        text: "Codex usage"
        visible: !dashboard.compact
        font.bold: true
        font.pixelSize: 18
        Layout.alignment: Qt.AlignHCenter
    }
    RowLayout {
        visible: dashboard.status === "ok"
        Layout.alignment: Qt.AlignHCenter
        spacing: dashboard.compact ? 8 : 30
        Ring { remaining: dashboard.fiveHour ? dashboard.fiveHour.remaining : null; ringColor: "#3b82f6"; Layout.preferredWidth: dashboard.compact ? 42 : 92; Layout.preferredHeight: Layout.preferredWidth }
        Ring { remaining: dashboard.weekly ? dashboard.weekly.remaining : null; ringColor: "#a855f7"; Layout.preferredWidth: dashboard.compact ? 42 : 92; Layout.preferredHeight: Layout.preferredWidth }
    }
    GridLayout {
        visible: dashboard.status === "ok" && !dashboard.compact
        columns: 2
        columnSpacing: 18
        rowSpacing: 6
        Layout.alignment: Qt.AlignHCenter
        Rectangle { width: 12; height: 12; radius: 3; color: "#3b82f6" }
        Controls.Label { text: "5hr limit: " + (dashboard.fiveHour ? dashboard.fiveHour.remaining + "%" : "Unavailable") + " · " + dashboard.resetText(dashboard.fiveHour) }
        Rectangle { width: 12; height: 12; radius: 3; color: "#a855f7" }
        Controls.Label { text: "Weekly limit: " + (dashboard.weekly ? dashboard.weekly.remaining + "%" : "Unavailable") + " · " + dashboard.resetText(dashboard.weekly) }
    }
    Controls.Label {
        visible: dashboard.status !== "ok"
        text: dashboard.status === "missing" ? "Codex is not installed" :
              dashboard.status === "auth" ? "Sign in to Codex to view usage" :
              dashboard.status === "error" ? "Could not refresh Codex usage" : "Loading Codex usage…"
        wrapMode: Text.WordWrap
        Layout.alignment: Qt.AlignHCenter
    }
    Controls.Label {
        visible: dashboard.status === "ok" && dashboard.stale && !dashboard.compact
        text: "Last update failed; showing saved usage"
        Layout.alignment: Qt.AlignHCenter
    }
    Controls.Button {
        visible: !dashboard.compact && dashboard.status === "missing"
        text: "Open settings"
        Layout.alignment: Qt.AlignHCenter
        onClicked: dashboard.settingsRequested()
    }
}
