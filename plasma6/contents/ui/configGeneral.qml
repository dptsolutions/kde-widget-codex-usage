import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page
    property alias cfg_codexPath: pathField.text
    property int cfg_refreshInterval: 60000
    RowLayout {
        Kirigami.FormData.label: "Codex install path:"
        Controls.TextField { id: pathField; Layout.fillWidth: true; placeholderText: "Automatic discovery" }
        Controls.Button { text: "Browse…"; onClicked: picker.open() }
    }
    Controls.ComboBox {
        id: intervalBox
        Kirigami.FormData.label: "Refresh interval:"
        textRole: "label"
        valueRole: "value"
        model: [
            {label: "1 second", value: 1000}, {label: "5 seconds", value: 5000},
            {label: "10 seconds", value: 10000}, {label: "30 seconds", value: 30000},
            {label: "1 minute", value: 60000}, {label: "5 minutes", value: 300000},
            {label: "10 minutes", value: 600000}, {label: "30 minutes", value: 1800000},
            {label: "1 hour", value: 3600000}
        ]
        currentIndex: Math.max(0, indexOfValue(page.cfg_refreshInterval))
        onActivated: page.cfg_refreshInterval = currentValue
    }
    FileDialog {
        id: picker
        title: "choose Codex binary"
        fileMode: FileDialog.OpenFile
        onAccepted: pathField.text = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
    }
}
