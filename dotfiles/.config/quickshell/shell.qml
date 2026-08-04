import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: panel

    anchors {
        top: true
        left: true
        right: true
    }

    color: "transparent"
    implicitHeight: island.expanded ? 250 : 42
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 42
    WlrLayershell.layer: Layer.Top

    property bool expanded: false

    property date now: new Date()
    property int displayedMonth: now.getMonth()
    property int displayedYear: now.getFullYear()


    function pad(value) {
        return value < 10 ? "0" + value : value
    }

    function monthName(month) {
        var names = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                     "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
        return names[month]
    }

    function sameDay(a, b) {
        return a.getDate() === b.getDate() &&
               a.getMonth() === b.getMonth() &&
               a.getFullYear() === b.getFullYear()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            panel.now = new Date()
            analogClock.requestPaint()

        }
    }

    Rectangle {
        id: island
        objectName: "dynamicIsland"
        z: 1
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: expanded ? 390 : 190
        height: expanded ? 220 : 38
        radius: expanded ? 0 : 19
        color: "transparent"
        border.color: "transparent"
        border.width: 0
        clip: true

        property bool expanded: panel.expanded
        onWidthChanged: islandBackground.requestPaint()
        onHeightChanged: islandBackground.requestPaint()
        onExpandedChanged: islandBackground.requestPaint()
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: 260 } }

        Canvas {
            id: islandBackground
            anchors.fill: parent
            z: -2

            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height
                var r = panel.expanded ? 0 : 18

                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(w, 0)
                ctx.lineTo(w, h - r)
                ctx.quadraticCurveTo(w, h, w - r, h)
                ctx.lineTo(r, h)
                ctx.quadraticCurveTo(0, h, 0, h - r)
                ctx.closePath()
                ctx.fillStyle = "#B32E3440"
                ctx.fill()
                ctx.lineWidth = 1
                ctx.strokeStyle = "#5588C0D0"
                ctx.stroke()
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 2
            hoverEnabled: true
            onClicked: {
                panel.expanded = !panel.expanded
            }
            onExited: {
                if (panel.expanded)
                    panel.expanded = false
            }
        }

        Text {
            id: compactClock
            anchors.centerIn: parent
            text: panel.pad(panel.now.getHours()) + ":" + panel.pad(panel.now.getMinutes())
            color: "white"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            visible: !panel.expanded
        }

        Item {
            id: expandedContent
            z: 1
            anchors.fill: parent
            visible: panel.expanded
            opacity: panel.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            MouseArea {
                anchors.fill: parent
                onClicked: panel.expanded = false
            }

            Text {
                anchors.top: parent.top
                anchors.left: analogClock.left
                anchors.right: analogClock.right
                anchors.topMargin: 12
                text: panel.pad(panel.now.getHours()) + ":" + panel.pad(panel.now.getMinutes()) + ":" + panel.pad(panel.now.getSeconds())
                color: "white"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            Canvas {
                id: analogClock
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 38
                width: 125
                height: 125

                onPaint: {
                    var ctx = getContext("2d")
                    var cx = width / 2
                    var cy = height / 2
                    var r = Math.min(cx, cy) - 5
                    var hours = panel.now.getHours() % 12
                    var minutes = panel.now.getMinutes()
                    var seconds = panel.now.getSeconds()

                    ctx.reset()
                    ctx.translate(cx, cy)
                    ctx.beginPath()
                    ctx.arc(0, 0, r, 0, Math.PI * 2)
                    ctx.fillStyle = "#263447"
                    ctx.fill()
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "#80ffffff"
                    ctx.stroke()

                    for (var i = 0; i < 12; i++) {
                        var angle = i * Math.PI / 6
                        ctx.save()
                        ctx.rotate(angle)
                        ctx.beginPath()
                        ctx.moveTo(0, -r + 9)
                        ctx.lineTo(0, -r + (i % 3 === 0 ? 20 : 15))
                        ctx.lineWidth = i % 3 === 0 ? 3 : 1.5
                        ctx.strokeStyle = "white"
                        ctx.stroke()
                        ctx.restore()
                    }

                    function hand(angle, length, lineWidth, color) {
                        ctx.save()
                        ctx.rotate(angle)
                        ctx.beginPath()
                        ctx.moveTo(0, 9)
                        ctx.lineTo(0, -length)
                        ctx.lineWidth = lineWidth
                        ctx.lineCap = "round"
                        ctx.strokeStyle = color
                        ctx.stroke()
                        ctx.restore()
                    }

                    hand((hours + minutes / 60) * Math.PI / 6, r * 0.52, 5, "white")
                    hand(minutes * Math.PI / 30, r * 0.74, 3, "white")
                    hand(seconds * Math.PI / 30, r * 0.82, 1.5, "#72d6ff")
                    ctx.beginPath()
                    ctx.arc(0, 0, 4, 0, Math.PI * 2)
                    ctx.fillStyle = "#72d6ff"
                    ctx.fill()
                }
            }

            Column {
                anchors.left: analogClock.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 12
                spacing: 4

                Text {
                    width: parent.width
                    text: panel.monthName(panel.displayedMonth) + " " + panel.displayedYear
                    color: "white"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: ["L", "M", "X", "J", "V", "S", "D"]
                        Text {
                            width: parent.width / 7
                            text: modelData
                            color: "#aab8cc"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 10
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7
                    rows: 6
                    spacing: 0

                    Repeater {
                        model: 42
                        Rectangle {
                            width: parent.width / 7
                            height: 20
                            radius: 5
                            color: {
                                var first = new Date(panel.displayedYear, panel.displayedMonth, 1)
                                var day = index - ((first.getDay() + 6) % 7) + 1
                                var cellDate = new Date(panel.displayedYear, panel.displayedMonth, day)
                                return panel.sameDay(cellDate, panel.now) ? "#4d9be8" : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                property var first: new Date(panel.displayedYear, panel.displayedMonth, 1)
                                property int day: index - ((first.getDay() + 6) % 7) + 1
                                text: day
                                color: (new Date(panel.displayedYear, panel.displayedMonth, day).getMonth() === panel.displayedMonth) ? "white" : "#66758a"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

        }
    }
}
