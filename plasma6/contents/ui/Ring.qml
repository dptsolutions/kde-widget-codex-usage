import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls as ChartControls

ChartControls.PieChartControl {
    id: ring
    property var remaining: null
    property color ringColor: "#3b82f6"
    implicitWidth: 72
    implicitHeight: 72
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    chart.smoothEnds: true
    chart.fromAngle: -180
    chart.toAngle: 180
    chart.backgroundColor: Qt.rgba(0, 0, 0, 0.2)
    range { from: 0; to: 100; automatic: false }
    valueSources: Charts.SingleValueSource { value: ring.remaining === null ? 0 : ring.remaining }
    chart.colorSource: Charts.SingleValueSource { value: ring.ringColor }

    Controls.Label {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.75
        text: ring.remaining === null ? "—" : ring.remaining + "%"
        color: Kirigami.Theme.textColor
        horizontalAlignment: Text.AlignHCenter
        fontSizeMode: Text.HorizontalFit
        minimumPointSize: 7
    }
}
