import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property bool darkTheme: true
    property double axisStartMs: 0
    property double axisEndMs: 0
    property double nowMs: 0
    property double startMs: 0
    property double endMs: 0

    property bool editable: false
    property string startEditText: ""
    property string endEditText: ""

    signal startTextEdited(string s)
    signal endTextEdited(string t)
    signal startMsDragged(double ms)
    signal endMsDragged(double ms)

    property real lineY: 16
    property real lineH: 2
    property real markerR: 6

    function clamp01(x) { return Math.max(0, Math.min(1, x)) }
    function posForMs(ms) {
        var span = Math.max(1, axisEndMs - axisStartMs)
        var t = (ms - axisStartMs) / span
        return clamp01(t) * (root.width)
    }
    function msForX(x) {
        var span = Math.max(1, axisEndMs - axisStartMs)
        return axisStartMs + clamp01(x / Math.max(1, root.width)) * span
    }
    function snapDayMs(ms) {
        var d = new Date(ms)
        return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime()
    }
    function snappedMsForX(x) {
        var ms = snapDayMs(msForX(x))
        return Math.max(axisStartMs, Math.min(axisEndMs, ms))
    }
    function fmt(ms) {
        var d = new Date(ms)
        var pad = function(n){ return (n<10?("0"+n):(""+n)) }
        return d.getFullYear()+"-"+pad(d.getMonth()+1)+"-"+pad(d.getDate())+" "+pad(d.getHours())+":"+pad(d.getMinutes())
    }

    readonly property real startX: posForMs(startMs)
    readonly property real endX: posForMs(endMs)
    readonly property real nowX: posForMs(nowMs)
    readonly property real progressX: Math.max(0, Math.min(endX, Math.max(startX, nowX)))

    readonly property bool overlapped: Math.abs(endX - startX) < 12
    readonly property bool startClamped: (startMs < axisStartMs)
    readonly property bool endClamped: (endMs > axisEndMs)

    // baseline line
    Rectangle {
        id: baseLine
        x: 0
        y: root.lineY
        width: root.width
        height: root.lineH
        radius: 999
        color: darkTheme ? "#636D69" : "#C7BDAF"
        opacity: 0.9
    }

    // progress fill (浅色)
    Rectangle {
        x: Math.min(startX, progressX)
        y: root.lineY
        width: Math.max(0, Math.abs(progressX - startX))
        height: root.lineH
        radius: 999
        color: darkTheme ? "#95A79F" : "#A8B9B0"
        opacity: 0.35
    }

    // current time marker (需要显示)
    Rectangle {
        x: nowX - 1
        y: root.lineY - 7
        width: 2
        height: 16
        radius: 1
        color: darkTheme ? "#D8D2C8" : "#7A7368"
        opacity: 0.5
    }

    // start / end markers with anti-overlap
    Item {
        id: markers
        anchors.fill: parent

        // start marker
        Rectangle {
            id: startDot
            visible: root.editable || !overlapped
            width: root.markerR * 2
            height: root.markerR * 2
            radius: root.markerR
            x: startX - root.markerR
            y: root.lineY - root.markerR
            color: darkTheme ? "#8FA09A" : "#95A79F"
            border.width: 1
            border.color: darkTheme ? "#C3CEC9" : "#B8C8BF"
            opacity: 0.95
            HoverHandler { id: startHover }
            MouseArea {
                id: startDrag
                visible: root.editable
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                onPositionChanged: (m) => {
                    if (!pressed) return
                    var p = startDrag.mapToItem(root, m.x, m.y)
                    var ms = root.snappedMsForX(p.x)
                    ms = Math.min(ms, root.endMs)
                    root.startMsDragged(ms)
                }
            }
            Rectangle {
                visible: startHover.hovered || (root.editable && startDrag.pressed)
                z: 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 8
                width: startTipText.implicitWidth + 14
                height: 24
                radius: 8
                color: darkTheme ? "#3C424E" : "#F2EEE6"
                border.width: 1
                border.color: darkTheme ? "#6A7383" : "#CEC6B9"
                Text {
                    id: startTipText
                    anchors.centerIn: parent
                    text: (startClamped ? "开始(已钳制): " : "开始: ") + fmt(startMs)
                    color: darkTheme ? "#E0DBD1" : "#5E5850"
                    font.pixelSize: 11
                }
            }
        }

        // end marker
        Rectangle {
            id: endDot
            visible: root.editable || !overlapped
            width: root.markerR * 2
            height: root.markerR * 2
            radius: root.markerR
            x: endX - root.markerR
            y: root.lineY - root.markerR
            color: darkTheme ? "#B8838D" : "#C0939B"
            border.width: 1
            border.color: darkTheme ? "#DAB6BD" : "#DDBFC5"
            opacity: 0.95
            HoverHandler { id: endHover }
            MouseArea {
                id: endDrag
                visible: root.editable
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                onPositionChanged: (m) => {
                    if (!pressed) return
                    var p = endDrag.mapToItem(root, m.x, m.y)
                    var ms = root.snappedMsForX(p.x)
                    ms = Math.max(ms, root.startMs)
                    root.endMsDragged(ms)
                }
            }
            Rectangle {
                visible: endHover.hovered || (root.editable && endDrag.pressed)
                z: 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 8
                width: endTipText.implicitWidth + 14
                height: 24
                radius: 8
                color: darkTheme ? "#3C424E" : "#F2EEE6"
                border.width: 1
                border.color: darkTheme ? "#6A7383" : "#CEC6B9"
                Text {
                    id: endTipText
                    anchors.centerIn: parent
                    text: (endClamped ? "截止(已钳制): " : "截止: ") + fmt(endMs)
                    color: darkTheme ? "#E0DBD1" : "#5E5850"
                    font.pixelSize: 11
                }
            }
        }

        // overlapped marker: merge + offset label via tooltip
        Rectangle {
            id: merged
            visible: !root.editable && overlapped
            width: root.markerR * 2 + 10
            height: root.markerR * 2
            radius: 999
            x: (Math.min(startX, endX) - root.markerR) - 5
            y: root.lineY - root.markerR
            color: darkTheme ? "#474F5A" : "#EEE8DE"
            border.width: 1
            border.color: darkTheme ? "#66707D" : "#CDC4B7"
            Row {
                anchors.centerIn: parent
                spacing: 6
                Rectangle { width: root.markerR * 1.4; height: root.markerR * 1.4; radius: 999; color: darkTheme ? "#8FA09A" : "#95A79F" }
                Rectangle { width: root.markerR * 1.4; height: root.markerR * 1.4; radius: 999; color: darkTheme ? "#B8838D" : "#C0939B" }
            }
            HoverHandler { id: mergedHover }
            Rectangle {
                visible: mergedHover.hovered
                z: 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 8
                width: Math.max(mergedTip1.implicitWidth, mergedTip2.implicitWidth) + 14
                height: 38
                radius: 8
                color: darkTheme ? "#3C424E" : "#F2EEE6"
                border.width: 1
                border.color: darkTheme ? "#6A7383" : "#CEC6B9"
                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        id: mergedTip1
                        text: "开始: " + fmt(startMs)
                        color: darkTheme ? "#E0DBD1" : "#5E5850"
                        font.pixelSize: 11
                    }
                    Text {
                        id: mergedTip2
                        text: "截止: " + fmt(endMs)
                        color: darkTheme ? "#E0DBD1" : "#5E5850"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // readable timestamps beside the line (not only one-line text)
    Row {
        y: root.lineY + 10
        spacing: 10
        Text {
            visible: !root.editable
            text: "开始 " + fmt(startMs)
            color: darkTheme ? "#ACA79D" : "#878073"
            font.pixelSize: 11
            elide: Text.ElideRight
            width: root.width * 0.48
        }
        Text {
            visible: !root.editable
            text: "截止 " + fmt(endMs)
            color: darkTheme ? "#ACA79D" : "#878073"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            width: root.width * 0.48
        }
        Row {
            visible: root.editable
            width: root.width * 0.48
            spacing: 2
            Text {
                id: startLbl
                text: "开始 "
                color: darkTheme ? "#ACA79D" : "#878073"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            TextField {
                id: startField
                width: parent.width - startLbl.width - parent.spacing
                text: root.startEditText
                padding: 0
                leftPadding: 0
                rightPadding: 2
                topPadding: 0
                bottomPadding: 0
                font.pixelSize: 11
                color: darkTheme ? "#ACA79D" : "#878073"
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                background: Rectangle {
                    color: "transparent"
                    border.width: startField.activeFocus ? 1 : 0
                    border.color: darkTheme ? "#8A9B94" : "#96A89E"
                    radius: 4
                }
                onTextChanged: {
                    if (startField.activeFocus)
                        root.startTextEdited(text)
                }
            }
        }
        Item {
            visible: root.editable
            width: root.width * 0.48
            height: Math.max(startField.implicitHeight, endField.implicitHeight, 22)
            Text {
                id: endLbl
                text: "截止 "
                color: darkTheme ? "#ACA79D" : "#878073"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
            }
            TextField {
                id: endField
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: endLbl.right
                anchors.leftMargin: 2
                width: Math.max(48, parent.width - endLbl.implicitWidth - 2)
                text: root.endEditText
                padding: 0
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                font.pixelSize: 11
                horizontalAlignment: TextInput.AlignLeft
                color: darkTheme ? "#ACA79D" : "#878073"
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                background: Rectangle {
                    color: "transparent"
                    border.width: endField.activeFocus ? 1 : 0
                    border.color: darkTheme ? "#8A9B94" : "#96A89E"
                    radius: 4
                }
                onTextChanged: {
                    if (endField.activeFocus)
                        root.endTextEdited(text)
                }
            }
        }
        Connections {
            target: root
            function onStartEditTextChanged() {
                if (!startField.activeFocus)
                    startField.text = root.startEditText
            }
            function onEndEditTextChanged() {
                if (!endField.activeFocus)
                    endField.text = root.endEditText
            }
        }
    }
}

