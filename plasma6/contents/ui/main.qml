import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    property string status: "loading"
    property var fiveHour: null
    property var weekly: null
    property bool stale: false
    property bool fetchPending: false
    property bool refreshAfterPending: false
    property int nowSeconds: Math.floor(Date.now() / 1000)
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../code/codex_usage.py").toString().replace(/^file:\/\//, ""))

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Codex usage"

    function quote(value) { return "'" + value.replace(/'/g, "'\"'\"'") + "'" }
    function encoded(value) { return encodeURIComponent(value).replace(/[!'()*]/g, function(c) { return "%" + c.charCodeAt(0).toString(16).toUpperCase() }) }
    function command(action, path, interval) {
        return "/usr/bin/python3 " + quote(helperPath) + " " + action + " --path-uri " + quote(encoded(path)) + " --interval-ms " + interval
    }
    function fetchUsage() {
        if (fetchPending) return
        fetchPending = true
        executable.connectSource(command("fetch", Plasmoid.configuration.codexPath || "", Plasmoid.configuration.refreshInterval || 60000))
    }
    function openSettings() { Plasmoid.containment.configureRequested(Plasmoid) }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            var answer = null
            try { answer = JSON.parse(data["stdout"] || "") } catch (error) {}
            root.fetchPending = false
            if (root.refreshAfterPending) {
                root.refreshAfterPending = false
                root.fetchUsage()
                return
            }
            if (!answer) {
                if (root.status === "ok") root.stale = true
                else root.status = "error"
                return
            }
            if (answer.status === "ok") {
                root.status = "ok"
                root.fiveHour = answer.five_hour
                root.weekly = answer.weekly
                root.stale = false
            } else if (answer.status === "error" && root.status === "ok") {
                root.stale = true
            } else {
                root.status = answer.status || "error"
                root.fiveHour = null
                root.weekly = null
                root.stale = false
            }
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onCodexPathChanged() { root.configurationChanged() }
        function onRefreshIntervalChanged() { root.configurationChanged() }
    }
    function configurationChanged() {
        status = "loading"
        if (fetchPending) refreshAfterPending = true
        else fetchUsage()
    }

    Timer { interval: Plasmoid.configuration.refreshInterval || 60000; repeat: true; running: true; onTriggered: root.fetchUsage() }
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.nowSeconds = Math.floor(Date.now() / 1000) }
    Component.onCompleted: fetchUsage()

    compactRepresentation: Item {
        Layout.preferredWidth: root.status === "ok" ? height * 2 + Math.round(height * 0.25) : 190
        Layout.preferredHeight: 44
        UsageDashboard {
            anchors.centerIn: parent
            compact: true
            compactSize: parent.height
            status: root.status
            fiveHour: root.fiveHour
            weekly: root.weekly
            nowSeconds: root.nowSeconds
        }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton; onClicked: root.expanded = !root.expanded }
    }
    fullRepresentation: Item {
        Layout.preferredWidth: 340
        Layout.preferredHeight: 250
        Layout.minimumWidth: 290
        Layout.minimumHeight: 210
        UsageDashboard {
            anchors.centerIn: parent
            status: root.status
            fiveHour: root.fiveHour
            weekly: root.weekly
            nowSeconds: root.nowSeconds
            stale: root.stale
            onSettingsRequested: root.openSettings()
        }

    }
}
