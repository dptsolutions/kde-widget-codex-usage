import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: ring
    property var remaining: null
    property color ringColor: "#3b82f6"
    property color trackColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, 0.25)
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
        color: Kirigami.Theme.textColor
        font.pixelSize: Math.max(9, ring.width / 5.3)
        font.bold: true
    }
}
