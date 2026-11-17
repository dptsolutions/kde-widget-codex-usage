import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: ring
    property var remaining: null
    property color ringColor: "#3b82f6"
    property color trackColor: Qt.rgba(PlasmaCore.Theme.textColor.r, PlasmaCore.Theme.textColor.g,
                                       PlasmaCore.Theme.textColor.b, 0.25)
    implicitWidth: 72
    implicitHeight: 72

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var radius = Math.min(width, height) / 2 - 5
            ctx.lineWidth = Math.max(4, width / 11)
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.strokeStyle = ring.trackColor
            ctx.arc(width / 2, height / 2, radius, 0, Math.PI * 2)
            ctx.stroke()
            if (ring.remaining !== null) {
                ctx.beginPath()
                ctx.strokeStyle = ring.ringColor
                ctx.arc(width / 2, height / 2, radius, -Math.PI / 2,
                        -Math.PI / 2 + Math.PI * 2 * ring.remaining / 100)
                ctx.stroke()
            }
        }
    }
    onRemainingChanged: canvas.requestPaint()
    onRingColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()

    Text {
        anchors.centerIn: parent
        text: ring.remaining === null ? "—" : ring.remaining + "%"
        color: PlasmaCore.Theme.textColor
        font.pixelSize: Math.max(9, ring.width / 5.3)
        font.bold: true
    }
}
