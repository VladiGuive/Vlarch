import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: panel

    anchors {
        top: true
        left: true
        right: true
    }

    color: "transparent"
    implicitHeight: island.expanded ? 390 : 42

    property bool expanded: false
    property var expandedFocusWindow: null
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
            if (panel.expanded && panel.expandedFocusWindow !== null &&
                    Hyprland.activeToplevel !== panel.expandedFocusWindow) {
                panel.expanded = false
                panel.expandedFocusWindow = null
            }
        }
    }

    Process {
        id: poweroffProcess
        command: ["systemctl", "poweroff"]
    }

    Process {
        id: rebootProcess
        command: ["systemctl", "reboot"]
    }

    Rectangle {
        id: island
        objectName: "dynamicIsland"
        z: 1
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: expanded ? 560 : 190
        height: expanded ? 370 : 38
        radius: expanded ? 24 : 19
        color: "#B32E3440"
        border.color: "#5588C0D0"
        border.width: 1
        clip: true

        property bool expanded: panel.expanded
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: 260 } }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                panel.expanded = !panel.expanded
                if (panel.expanded)
                    panel.expandedFocusWindow = Hyprland.activeToplevel
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
            anchors.fill: parent
            visible: panel.expanded
            opacity: panel.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse.accepted = true
            }

            Text {
                anchors.top: parent.top
                anchors.left: analogClock.left
                anchors.right: analogClock.right
                anchors.topMargin: 18
                text: panel.pad(panel.now.getHours()) + ":" + panel.pad(panel.now.getMinutes()) + ":" + panel.pad(panel.now.getSeconds())
                color: "white"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            Canvas {
                id: analogClock
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.top: parent.top
                anchors.topMargin: 56
                width: 170
                height: 170

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
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 42
                spacing: 8

                Text {
                    width: parent.width
                    text: panel.monthName(panel.displayedMonth) + " " + panel.displayedYear
                    color: "white"
                    font.pixelSize: 17
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
                            font.pixelSize: 12
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7
                    rows: 6
                    spacing: 2

                    Repeater {
                        model: 42
                        Rectangle {
                            width: (parent.width - 12) / 7
                            height: 25
                            radius: 8
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
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                spacing: 10

                Rectangle {
                    width: 112
                    height: 38
                    radius: 12
                    color: "#352f3945"
                    border.color: "#35ffffff"
                    Text { anchors.centerIn: parent; text: "⏻  Apagar"; color: "#ffb4b4"; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; onClicked: poweroffProcess.running = true }
                }

                Rectangle {
                    width: 112
                    height: 38
                    radius: 12
                    color: "#352f3945"
                    border.color: "#35ffffff"
                    Text { anchors.centerIn: parent; text: "↻  Reiniciar"; color: "#c5d9ff"; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; onClicked: rebootProcess.running = true }
                }
            }
        }
    }
}
