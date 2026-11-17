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
    property bool settingsVisible: false
    property bool saving: false
    property bool fetchPending: false
    property bool refreshAfterPending: false
    property bool closeAfterValidation: false
    property string pendingPath: ""
    property int pendingInterval: 60000
    property string validateSource: ""
    property int nowSeconds: Math.floor(Date.now() / 1000)
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../code/codex_usage.py").toString().replace(/^file:\/\//, ""))

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Codex usage"
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Configure Codex usage"
            icon.name: "configure"
            onTriggered: root.openSettings()
        }
    ]

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
    function openSettings() {
        settingsVisible = true
        root.expanded = true
    }
    function saveSettings(path, interval, closeAfter) {
        if (saving) return
        pendingPath = path
        pendingInterval = interval
        closeAfterValidation = closeAfter
        if (path === "") {
            finishSave()
            return
        }
        saving = true
        validateSource = command("validate", path, interval)
        executable.connectSource(validateSource)
    }
    function finishSave() {
        Plasmoid.configuration.codexPath = pendingPath
        Plasmoid.configuration.refreshInterval = pendingInterval
        saving = false
        settingsPane.errorText = ""
        settingsPane.reset(pendingPath, pendingInterval)
        if (closeAfterValidation) settingsVisible = false
        status = "loading"
        if (fetchPending) refreshAfterPending = true
        else fetchUsage()
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            var answer = null
            try { answer = JSON.parse(data["stdout"] || "") } catch (error) {}
            if (sourceName === root.validateSource) {
                root.validateSource = ""
                root.saving = false
                if (answer && answer.valid) root.finishSave()
                else settingsPane.errorText = "That path is not a valid Codex CLI binary."
                return
            }
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

    Timer { interval: Plasmoid.configuration.refreshInterval || 60000; repeat: true; running: true; onTriggered: root.fetchUsage() }
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.nowSeconds = Math.floor(Date.now() / 1000) }
    Component.onCompleted: fetchUsage()

    compactRepresentation: Item {
        Layout.preferredWidth: root.status === "ok" ? 100 : 190
        Layout.preferredHeight: 44
        UsageDashboard {
            anchors.centerIn: parent
            compact: true
            status: root.status
            fiveHour: root.fiveHour
            weekly: root.weekly
            nowSeconds: root.nowSeconds
        }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton; onClicked: root.expanded = !root.expanded }
    }
    fullRepresentation: Item {
        Layout.preferredWidth: 340
        Layout.preferredHeight: root.settingsVisible ? 260 : 250
        Layout.minimumWidth: 290
        Layout.minimumHeight: 210
        UsageDashboard {
            anchors.centerIn: parent
            visible: !root.settingsVisible
            status: root.status
            fiveHour: root.fiveHour
            weekly: root.weekly
            nowSeconds: root.nowSeconds
            stale: root.stale
            onSettingsRequested: root.openSettings()
        }
        SettingsPane {
            id: settingsPane
            anchors.fill: parent
            anchors.margins: 12
            visible: root.settingsVisible
            initialPath: Plasmoid.configuration.codexPath || ""
            initialInterval: Plasmoid.configuration.refreshInterval || 60000
            saving: root.saving
            onApplyRequested: root.saveSettings(path, interval, closeAfter)
            onCancelRequested: root.settingsVisible = false
        }
    }
}
