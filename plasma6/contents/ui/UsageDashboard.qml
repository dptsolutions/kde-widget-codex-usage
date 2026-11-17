import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: dashboard
    property bool compact: false
    property real compactSize: 42
    property string status: "loading"
    property var fiveHour: null
    property var weekly: null
    property bool stale: false
    property int nowSeconds: 0
    signal settingsRequested()
    spacing: compact ? 2 : 18

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

    Kirigami.Heading {
        color: Kirigami.Theme.textColor
        text: "Codex usage"
        visible: !dashboard.compact
        level: 2
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
    }
    RowLayout {
        visible: dashboard.status === "ok"
        Layout.alignment: Qt.AlignHCenter
        spacing: dashboard.compact ? Math.round(dashboard.compactSize * 0.25) : 30
        Ring { compact: dashboard.compact; remaining: dashboard.fiveHour ? dashboard.fiveHour.remaining : null; ringColor: "#3b82f6"; Layout.preferredWidth: dashboard.compact ? dashboard.compactSize : 92; Layout.preferredHeight: Layout.preferredWidth }
        Ring { compact: dashboard.compact; remaining: dashboard.weekly ? dashboard.weekly.remaining : null; ringColor: "#a855f7"; Layout.preferredWidth: dashboard.compact ? dashboard.compactSize : 92; Layout.preferredHeight: Layout.preferredWidth }
    }
    GridLayout {
        visible: dashboard.status === "ok" && !dashboard.compact
        columns: 2
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing
        Layout.alignment: Qt.AlignHCenter
        Rectangle { Layout.preferredWidth: Kirigami.Units.smallSpacing; Layout.fillHeight: true; color: "#3b82f6" }
        PlasmaComponents.Label { color: Kirigami.Theme.textColor; text: "5hr limit: " + (dashboard.fiveHour ? dashboard.fiveHour.remaining + "%" : "Unavailable") + " · " + dashboard.resetText(dashboard.fiveHour) }
        Rectangle { Layout.preferredWidth: Kirigami.Units.smallSpacing; Layout.fillHeight: true; color: "#a855f7" }
        PlasmaComponents.Label { color: Kirigami.Theme.textColor; text: "Weekly limit: " + (dashboard.weekly ? dashboard.weekly.remaining + "%" : "Unavailable") + " · " + dashboard.resetText(dashboard.weekly) }
    }
    PlasmaComponents.Label { color: Kirigami.Theme.textColor;
        visible: dashboard.status !== "ok"
        text: dashboard.status === "missing" ? "Codex is not installed" :
              dashboard.status === "auth" ? "Sign in to Codex to view usage" :
              dashboard.status === "error" ? "Could not refresh Codex usage" : "Loading Codex usage…"
        wrapMode: Text.WordWrap
        Layout.alignment: Qt.AlignHCenter
    }
    PlasmaComponents.Label { color: Kirigami.Theme.textColor;
        visible: dashboard.status === "ok" && dashboard.stale && !dashboard.compact
        text: "Last update failed; showing saved usage"
        Layout.alignment: Qt.AlignHCenter
    }
    PlasmaComponents.Button {
        visible: !dashboard.compact && dashboard.status === "missing"
        text: "Open settings"
        Layout.alignment: Qt.AlignHCenter
        onClicked: dashboard.settingsRequested()
    }
}
