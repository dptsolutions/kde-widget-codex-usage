import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: ring
    property var remaining: null
    property color ringColor: "#3b82f6"
    property color trackColor: Qt.rgba(0, 0, 0, 0.2)
    implicitWidth: 72
    implicitHeight: 72

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.lineWidth = Math.max(3, width / 11)
            var radius = (Math.min(width, height) - ctx.lineWidth) / 2
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
        width: ring.width * 0.75
        horizontalAlignment: Text.AlignHCenter
        fontSizeMode: Text.HorizontalFit
        minimumPointSize: 7
    }
}
