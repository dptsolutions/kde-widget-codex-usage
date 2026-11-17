import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import QtQuick.Dialogs

ColumnLayout {
    id: settings
    property string savedPath: ""
    property int savedInterval: 60000
    property string initialPath: ""
    property int initialInterval: 60000
    property string errorText: ""
    property bool saving: false
    readonly property bool dirty: pathField.text !== savedPath || intervalBox.currentValue !== savedInterval
    signal applyRequested(string path, int interval, bool closeAfter)
    signal cancelRequested()
    spacing: 12

    function reset(path, interval) {
        savedPath = path || ""
        savedInterval = interval || 60000
        pathField.text = savedPath
        var index = intervalBox.indexOfValue(savedInterval)
        intervalBox.currentIndex = index < 0 ? 4 : index
    }
    function resetFromConfiguration() {
        reset(initialPath, initialInterval)
        errorText = ""
    }
    onVisibleChanged: if (visible) resetFromConfiguration()
    Component.onCompleted: if (visible) resetFromConfiguration()

    PlasmaComponents.Label { color: Kirigami.Theme.textColor; text: "Configure Codex usage"; font.bold: true; font.pixelSize: 18 }
    PlasmaComponents.Label { color: Kirigami.Theme.textColor; text: "Codex install path" }
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents.TextField {
            id: pathField
            Layout.fillWidth: true
            placeholderText: "Automatic discovery"
            onTextEdited: settings.errorText = ""
        }
        PlasmaComponents.Button { text: "Browse…"; onClicked: picker.open() }
    }
    PlasmaComponents.Label { color: Kirigami.Theme.textColor; text: "refresh interval" }
    PlasmaComponents.ComboBox {
        id: intervalBox
        Layout.fillWidth: true
        textRole: "label"
        valueRole: "value"
        model: [
            {label: "1 second", value: 1000},
            {label: "5 seconds", value: 5000},
            {label: "10 seconds", value: 10000},
            {label: "30 seconds", value: 30000},
            {label: "1 minute", value: 60000},
            {label: "5 minutes", value: 300000},
            {label: "10 minutes", value: 600000},
            {label: "30 minutes", value: 1800000},
            {label: "1 hour", value: 3600000}
        ]
        Component.onCompleted: currentIndex = 4
    }
    PlasmaComponents.Label { color: Kirigami.Theme.textColor;
        visible: settings.errorText.length > 0
        text: settings.errorText
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    RowLayout {
        Layout.alignment: Qt.AlignRight
        PlasmaComponents.Button { text: "Cancel"; onClicked: settings.cancelRequested() }
        PlasmaComponents.Button {
            text: "Apply"
            enabled: settings.dirty && !settings.saving
            onClicked: settings.applyRequested(pathField.text.trim(), intervalBox.currentValue, false)
        }
        PlasmaComponents.Button {
            text: "OK"
            enabled: !settings.saving
            onClicked: settings.applyRequested(pathField.text.trim(), intervalBox.currentValue, true)
        }
    }
    FileDialog {
        id: picker
        title: "choose Codex binary"
        fileMode: FileDialog.OpenFile
        onAccepted: {
            pathField.text = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
            settings.errorText = ""
        }
    }
}
