import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: win
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    width: 1080
    height: 720
    title: "事务时间表"
    property bool darkTheme: false
    color: "transparent"
    readonly property color cPanel: darkTheme ? "#2E333D" : "#FBF8F2"
    readonly property color cPanelSoft: darkTheme ? "#353B46" : "#F3EFE7"
    readonly property color cBorder: darkTheme ? "#4A505D" : "#D9D2C6"
    readonly property color cTextPrimary: darkTheme ? "#E6E1D8" : "#4A4A47"
    readonly property color cTextSecondary: darkTheme ? "#B6B0A6" : "#7E786F"
    readonly property color cAccent: darkTheme ? "#8FA09A" : "#94A89F"
    readonly property color cAccentStrong: darkTheme ? "#7E918A" : "#839C92"
    readonly property int rSm: 10
    readonly property int rMd: 12
    readonly property int rLg: 16
    readonly property int rOuter: 18
    readonly property int ctrlBtn: 28
    readonly property int resizeHandle: 8
    readonly property color cHeaderBg: Qt.rgba(cPanel.r, cPanel.g, cPanel.b, 0.78)
    readonly property color cHeaderTextAuto: autoTextOn(cHeaderBg)
    readonly property color cHeaderSubTextAuto: autoSubTextOn(cHeaderBg)

    function luminance(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }
    function autoTextOn(bg) {
        return luminance(bg) > 0.56 ? "#3F3A34" : "#F0EBE2"
    }
    function autoSubTextOn(bg) {
        return luminance(bg) > 0.56 ? "#6D665D" : "#C2BBB0"
    }
    Rectangle {
        anchors.fill: parent
        radius: win.rOuter
        color: win.darkTheme ? "#2A2F39" : "#F4F1EA"
        border.color: win.cBorder
        border.width: 1
        z: -10
    }

    // 无边框窗口缩放热区（四边 + 四角）
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: win.resizeHandle
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemResize(Qt.LeftEdge) }
    }
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: win.resizeHandle
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemResize(Qt.RightEdge) }
    }
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: win.resizeHandle
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemResize(Qt.TopEdge) }
    }
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: win.resizeHandle
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemResize(Qt.BottomEdge) }
    }
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        width: win.resizeHandle + 4
        height: win.resizeHandle + 4
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemResize(Qt.LeftEdge | Qt.TopEdge) }
    }
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        width: win.resizeHandle + 4
        height: win.resizeHandle + 4
        hoverEnabled: true
        cursorShape: Qt.SizeBDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemResize(Qt.RightEdge | Qt.TopEdge) }
    }
    MouseArea {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: win.resizeHandle + 4
        height: win.resizeHandle + 4
        hoverEnabled: true
        cursorShape: Qt.SizeBDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemResize(Qt.LeftEdge | Qt.BottomEdge) }
    }
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: win.resizeHandle + 4
        height: win.resizeHandle + 4
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemResize(Qt.RightEdge | Qt.BottomEdge) }
    }


    property int filterMode: 0
    property bool autoEditNewCard: false

    // —— Ghost 浮层拖拽 ——
    property bool ghostDragging: false
    property int ghostDragIndex: -1
    property int ghostEventId: -1
    property real ghostSlotHeight: 0
    property real ghostGrabX: 0
    property real ghostGrabY: 0
    property real ghostX: 0
    property real ghostY: 0
    property real ghostVisualScale: 1.0
    property string ghostTitle: ""
    property string ghostNote: ""
    property bool ghostUrgent: false
    property bool ghostDone: false
    property int ghostStartAtS: 0
    property int ghostEndAtS: 0
    property double _lastGhostMoveAt: 0
    property real ghostPointerListY: -1
    property real ghostAutoScrollV: 0
    property bool ghostDropAnimating: false
    readonly property int ghostMoveCooldownMs: 26
    readonly property real ghostCrossPad: 10

    function keepListViewport(action) {
        var keepY = list.contentY
        action()
        Qt.callLater(function() {
            var maxY = Math.max(0, list.contentHeight - list.height)
            list.contentY = Math.max(0, Math.min(maxY, keepY))
        })
    }

    function deleteCardEvent(id) {
        if ((ghostDragging || ghostDropAnimating) && ghostEventId === id) {
            ghostDropXAnim.stop()
            ghostDropYAnim.stop()
            finalizeGhostReorder()
        }
        repo.delete_event(id)
    }

    function monthStartMs(d) {
        return new Date(d.getFullYear(), d.getMonth(), 1, 0, 0, 0, 0).getTime()
    }
    function endOfNextMonthMs(d) {
        return new Date(d.getFullYear(), d.getMonth() + 2, 0, 23, 59, 59, 999).getTime()
    }

    readonly property double axisStartMs: monthStartMs(new Date())
    readonly property double axisEndMs: endOfNextMonthMs(new Date())
    readonly property double nowMs: (new Date()).getTime()
    property string nowLabel: ""

    function formatNowLabel(d) {
        var pad = function(n) { return (n < 10 ? ("0" + n) : ("" + n)) }
        var w = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
            + "  " + w[d.getDay()] + "  "
            + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds())
    }

    function beginGhostReorder(idx, item, lx, ly, data) {
        ghostDragIndex = idx
        ghostEventId = data.id !== undefined ? data.id : -1
        ghostDragging = true
        ghostGrabX = lx
        ghostGrabY = ly
        // 限制拖拽幽灵高度，避免长备注卡片在拖拽时遮挡过多内容
        ghostSlotHeight = Math.min(220, Math.max(item.height, 72))
        ghostTitle = data.title
        ghostNote = data.note
        ghostUrgent = data.urgent
        ghostDone = data.done
        ghostStartAtS = data.startAtS
        ghostEndAtS = data.endAtS
        list.interactive = false
        _lastGhostMoveAt = 0
        var pt = item.mapToItem(ghostHost, lx, ly)
        ghostX = pt.x - ghostGrabX
        ghostY = pt.y - ghostGrabY
        var pList = item.mapToItem(list.contentItem, lx, ly)
        ghostPointerListY = pList ? pList.y : (item.y + item.height / 2)
        ghostVisualScale = 1.0
        ghostScaleIn.restart()
    }

    Component.onCompleted: {
        nowLabel = formatNowLabel(new Date())
    }

    function updateGhostReorder(item, mx, my) {
        if (!ghostDragging) return
        var pt = item.mapToItem(ghostHost, mx, my)
        ghostX = pt.x - ghostGrabX
        ghostY = pt.y - ghostGrabY

        var pList = item.mapToItem(list.contentItem, mx, my)
        if (!pList) return
        var pointerY = pList.y
        ghostPointerListY = pointerY

        var current = ghostDragIndex
        if (current < 0 || current >= list.count) return

        var nowMs = Date.now()
        if (nowMs - _lastGhostMoveAt < ghostMoveCooldownMs) return

        var target = current
        var cnt = list.count
        if (current < cnt - 1) {
            var nextItem = list.itemAtIndex(current + 1)
            if (nextItem) {
                var nextMid = nextItem.y + nextItem.height / 2
                if (pointerY > nextMid + ghostCrossPad) target = current + 1
            }
        }
        if (target === current && current > 0) {
            var prevItem = list.itemAtIndex(current - 1)
            if (prevItem) {
                var prevMid = prevItem.y + prevItem.height / 2
                if (pointerY < prevMid - ghostCrossPad) target = current - 1
            }
        }

        if (target !== current) {
            if (filterMode === 0) inProgressModel.move(current, target)
            else doneModel.move(current, target)
            ghostDragIndex = target
            _lastGhostMoveAt = nowMs
        }
    }

    function endGhostReorder() {
        if (ghostDropAnimating) return
        var targetItem = list.itemAtIndex(ghostDragIndex)
        if (targetItem) {
            var p = targetItem.mapToItem(ghostHost, 0, 0)
            ghostDropXAnim.to = p.x
            ghostDropYAnim.to = p.y
            ghostDropAnimating = true
            ghostDropXAnim.start()
            ghostDropYAnim.start()
            return
        }
        finalizeGhostReorder()
    }

    function finalizeGhostReorder() {
        ghostDragging = false
        ghostDropAnimating = false
        ghostDragIndex = -1
        ghostEventId = -1
        ghostSlotHeight = 0
        ghostPointerListY = -1
        ghostAutoScrollV = 0
        ghostVisualScale = 1.0
        list.interactive = true
    }

    NumberAnimation {
        id: ghostScaleIn
        target: win
        property: "ghostVisualScale"
        from: 1.0
        to: 1.03
        duration: 120
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: ghostDropXAnim
        target: win
        property: "ghostX"
        duration: 140
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: ghostDropYAnim
        target: win
        property: "ghostY"
        duration: 180
        easing.type: Easing.OutBack
        onStopped: {
            if (win.ghostDropAnimating) {
                win.finalizeGhostReorder()
            }
        }
    }

    Timer {
        id: autoScrollTimer
        interval: 16
        repeat: true
        running: win.ghostDragging
        onTriggered: {
            if (!win.ghostDragging) return
            var edge = 72
            var visibleY = win.ghostPointerListY - list.contentY
            if (visibleY < edge) {
                win.ghostAutoScrollV = -Math.min(14, (edge - visibleY) * 0.2 + 2)
            } else if (visibleY > list.height - edge) {
                win.ghostAutoScrollV = Math.min(14, (visibleY - (list.height - edge)) * 0.2 + 2)
            } else {
                win.ghostAutoScrollV = 0
            }

            if (win.ghostAutoScrollV !== 0) {
                var maxY = Math.max(0, list.contentHeight - list.height)
                list.contentY = Math.max(0, Math.min(maxY, list.contentY + win.ghostAutoScrollV))
            }
        }
    }
    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: nowLabel = formatNowLabel(new Date())
    }

    header: Rectangle {
        height: 66
        color: win.cHeaderBg
        border.width: 1
        border.color: Qt.rgba(cBorder.r, cBorder.g, cBorder.b, 0.55)
        radius: win.rOuter - 1
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    win.startSystemMove()
                }
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "事务"
                    color: win.cHeaderTextAuto
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "时间轴：当月 ~ 下月末"
                    color: win.cHeaderSubTextAuto
                    font.pixelSize: 11
                }
            }

            Rectangle {
                id: filterSwitch
                radius: win.rMd
                color: win.cPanel
                border.color: win.cBorder
                border.width: 1
                height: 33
                width: 214
                property real dragStartX: 0
                Rectangle {
                    id: filterThumb
                    y: 4
                    x: win.filterMode === 0 ? 4 : (parent.width / 2)
                    width: (parent.width - 8) / 2
                    height: parent.height - 8
                    radius: win.rSm
                    color: win.cAccentStrong
                    Behavior on x { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    Repeater {
                        model: [
                            { label: "进行中", value: 0 },
                            { label: "已完成", value: 1 }
                        ]
                        delegate: Rectangle {
                            radius: win.rSm
                            width: (parent.width - 4) / 2
                            height: parent.height
                            color: "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: (win.filterMode === modelData.value) ? "#F8F5EE" : win.cTextSecondary
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: win.filterMode = modelData.value
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: (m) => filterSwitch.dragStartX = m.x
                    onPositionChanged: (m) => {
                        if (Math.abs(m.x - filterSwitch.dragStartX) > 14) {
                            win.filterMode = (m.x < width / 2) ? 0 : 1
                        }
                    }
                }
            }

            Rectangle {
                id: themeSwitch
                radius: win.rMd
                color: win.cPanelSoft
                border.color: win.cBorder
                border.width: 1
                height: 33
                width: 176
                property real dragStartX: 0
                Rectangle {
                    id: themeThumb
                    y: 4
                    x: win.darkTheme ? 4 : (parent.width / 2)
                    width: (parent.width - 8) / 2
                    height: parent.height - 8
                    radius: win.rSm
                    color: win.cAccent
                    Behavior on x { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    Rectangle {
                        width: (parent.width - 4) / 2
                        height: parent.height
                        color: "transparent"
                        radius: win.rSm
                        Text {
                            anchors.centerIn: parent
                            text: "深色"
                            color: win.darkTheme ? "#F8F5EE" : win.cTextSecondary
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        MouseArea { anchors.fill: parent; onClicked: win.darkTheme = true }
                    }
                    Rectangle {
                        width: (parent.width - 4) / 2
                        height: parent.height
                        color: "transparent"
                        radius: win.rSm
                        Text {
                            anchors.centerIn: parent
                            text: "浅色"
                            color: win.darkTheme ? win.cTextSecondary : "#F8F5EE"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        MouseArea { anchors.fill: parent; onClicked: win.darkTheme = false }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: (m) => themeSwitch.dragStartX = m.x
                    onPositionChanged: (m) => {
                        if (Math.abs(m.x - themeSwitch.dragStartX) > 14) {
                            win.darkTheme = (m.x < width / 2)
                        }
                    }
                }
            }

            Rectangle {
                radius: win.rMd
                color: win.cPanel
                border.color: win.cBorder
                border.width: 1
                width: (win.ctrlBtn * 2) + 8
                height: win.ctrlBtn
                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 2

                    Rectangle {
                        id: minBtn
                        width: win.ctrlBtn - 4
                        height: parent.height
                        radius: win.rSm
                        color: minArea.pressed ? (win.darkTheme ? "#5E6777" : "#D9D0C1") : (minArea.containsMouse ? (win.darkTheme ? "#515A69" : "#E3DBCF") : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "—"
                            color: win.cTextPrimary
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: minArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.visibility = Window.Minimized
                        }
                    }

                    Rectangle {
                        id: closeBtn
                        width: win.ctrlBtn + 4
                        height: parent.height
                        radius: win.rSm
                        color: closeArea.pressed ? (win.darkTheme ? "#A87982" : "#B88790") : (closeArea.containsMouse ? (win.darkTheme ? "#996D75" : "#B3818A") : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: closeArea.containsMouse || closeArea.pressed ? "#F9F5EE" : (win.darkTheme ? win.cTextPrimary : "#5E5650")
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.close()
                        }
                    }
                }
            }
        }

        Rectangle {
            id: addBtn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 17
            color: addArea.pressed ? win.cAccentStrong : (addArea.containsMouse ? win.cAccent : win.cPanelSoft)
            border.color: win.cBorder
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "+"
                color: win.darkTheme ? "#F8F5EE" : "#4E4A43"
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    win.filterMode = 0
                    win.autoEditNewCard = true
                    list.positionViewAtEnd()
                    var now = new Date()
                    var startS = Math.floor(now.getTime() / 1000)
                    var endS = startS + 2 * 3600
                    repo.add_event("新事件", "", startS, endS, false)
                    Qt.callLater(function() { list.positionViewAtEnd() })
                }
            }
        }
    }

    EditDialog {
        id: edit
        darkTheme: win.darkTheme
        axisStartMs: win.axisStartMs
        axisEndMs: win.axisEndMs
        onSaveNew: function(title, note, startAtS, endAtS, urgent) {
            repo.add_event(title, note, startAtS, endAtS, urgent)
        }
        onSaveEdit: function(id, title, note, startAtS, endAtS, urgent) {
            repo.update_event(id, title, note, startAtS, endAtS, urgent)
        }
    }

    Rectangle {
        anchors.fill: parent
        // ApplicationWindow 的 header 已占据顶部，这里不再二次留白
        anchors.topMargin: 0
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.bottomMargin: 1
        radius: win.rOuter - 1
        clip: true
        color: win.darkTheme ? "#2A2F39" : "#F4F1EA"

        Item {
            id: page
            anchors.fill: parent

            Rectangle {
                id: dateTimeBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34
                radius: 12
                color: win.darkTheme ? "#2F343E" : "#EFEBE3"
                border.width: 1
                border.color: win.darkTheme ? "#4A505D" : "#D9D2C6"

                Text {
                    id: dateText
                    anchors.centerIn: parent
                    text: win.nowLabel
                    color: win.darkTheme ? "#E5DFD4" : "#5D5750"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            ListView {
                id: list
                anchors.top: dateTimeBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.topMargin: 10
                anchors.bottomMargin: 16
                spacing: 12
                clip: true

                model: (win.filterMode === 0) ? inProgressModel : doneModel
                interactive: true

                moveDisplaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: row
                    width: list.width
                    height: card.implicitHeight

                    EventCard {
                        id: card
                        width: row.width
                        eventId: model.id
                        title: model.title
                        note: model.note
                        urgent: model.urgent
                        done: model.done
                        startAtS: model.start_at
                        endAtS: model.end_at
                        axisStartMs: win.axisStartMs
                        axisEndMs: win.axisEndMs
                        nowMs: win.nowMs
                        darkTheme: win.darkTheme
                        listView: list
                        dragWin: win
                        modelIndex: index
                        dragKey: model.id
                        isDragPlaceholder: win.ghostDragging && win.ghostDragIndex === index

                        onToggleDone: function(nextDone) {
                            repo.set_done(model.id, nextDone)
                        }
                        onRequestUrgentToggle: function(id, urgent) {
                            repo.set_urgent(id, urgent)
                        }
                        onRequestInlineSave: function(id, title, note, startAtS, endAtS, urgent) {
                            win.keepListViewport(function() {
                                repo.update_event(id, title, note, startAtS, endAtS, urgent)
                            })
                        }
                        onRequestDelete: function(id) {
                            win.deleteCardEvent(id)
                        }
                        onReorderStateChanged: function(active) {
                            list.interactive = !active
                        }
                        Component.onCompleted: {
                            if (win.autoEditNewCard && win.filterMode === 0 && index === list.count - 1) {
                                card.beginInlineEdit()
                                win.autoEditNewCard = false
                            }
                        }
                    }
                }
            }

            Item {
                id: ghostHost
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.topMargin: 10
                anchors.bottomMargin: 16
                z: 100
                enabled: false

                EventCard {
                    id: ghostCard
                    visible: win.ghostDragging || win.ghostDropAnimating
                    isGhostFloat: true
                    ghostScale: win.ghostVisualScale
                    width: list.width
                    height: win.ghostSlotHeight > 0 ? win.ghostSlotHeight : 146
                    x: win.ghostX
                    y: win.ghostY
                    title: win.ghostTitle
                    note: win.ghostNote
                    urgent: win.ghostUrgent
                    done: win.ghostDone
                    startAtS: win.ghostStartAtS
                    endAtS: win.ghostEndAtS
                    axisStartMs: win.axisStartMs
                    axisEndMs: win.axisEndMs
                    nowMs: win.nowMs
                    darkTheme: win.darkTheme
                }
            }
        }
    }
}
