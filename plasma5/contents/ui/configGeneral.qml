import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.quickcharts 1.0 as Charts
import QtQuick.Controls 2.15 as Controls
import QtQuick.Dialogs 1.3
import Qt.labs.platform 1.1 as Platform
import org.kde.kirigami 2.15 as Kirigami

Kirigami.FormLayout {
    id: page
    property alias cfg_codexPath: pathField.text
    property int cfg_refreshInterval: 60000
    property color cfg_fiveHourColor: "transparent"
    property color cfg_weeklyColor: "transparent"
    Charts.ColorGradientSource { id: defaultColors; baseColor: Kirigami.Theme.highlightColor; itemCount: 2 }
    readonly property color effectiveFiveHourColor: cfg_fiveHourColor.a > 0 ? cfg_fiveHourColor : defaultColors.colors[0]
    readonly property color effectiveWeeklyColor: cfg_weeklyColor.a > 0 ? cfg_weeklyColor : defaultColors.colors[1]
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
    Controls.Button {
        id: fiveHourButton
        Kirigami.FormData.label: "5hr Color:"
        Layout.preferredWidth: 48
        Accessible.name: "Choose 5hr color"
        onClicked: { colorPicker.target = "five"; colorPicker.currentColor = page.effectiveFiveHourColor; colorPicker.open() }
        Rectangle { anchors.centerIn: parent; width: 20; height: 20; color: page.effectiveFiveHourColor; border.color: parent.palette.mid }
    }
    Controls.Button {
        id: weeklyButton
        Kirigami.FormData.label: "Weekly Color:"
        Layout.preferredWidth: 48
        Accessible.name: "Choose weekly color"
        onClicked: { colorPicker.target = "weekly"; colorPicker.currentColor = page.effectiveWeeklyColor; colorPicker.open() }
        Rectangle { anchors.centerIn: parent; width: 20; height: 20; color: page.effectiveWeeklyColor; border.color: parent.palette.mid }
    }
    Platform.ColorDialog {
        id: colorPicker
        property string target: ""
        title: "Choose chart color"
        onAccepted: {
            if (target === "five") page.cfg_fiveHourColor = color
            else if (target === "weekly") page.cfg_weeklyColor = color
        }
    }
    FileDialog {
        id: picker
        title: "choose Codex binary"
        selectExisting: true
        selectMultiple: false
        onAccepted: pathField.text = decodeURIComponent(fileUrl.toString().replace(/^file:\/\//, ""))
    }
}
