import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    readonly property real _viewNoteExtra: Math.max(0, noteText.contentHeight - 30)
    readonly property real _editNoteExtra: Math.max(0, noteArea.contentHeight - 34)
    implicitHeight: isDragPlaceholder
        ? (dragWin && dragWin.ghostSlotHeight > 0 ? dragWin.ghostSlotHeight : 146)
        : (editMode ? (196 + _editNoteExtra) : (146 + _viewNoteExtra))

    // data
    property string title: ""
    property string note: ""
    property int eventId: 0
    property bool urgent: false
    property bool done: false
    property int startAtS: 0
    property int endAtS: 0
    property bool darkTheme: true

    // axis
    property double axisStartMs: 0
    property double axisEndMs: 0
    property double nowMs: 0

    // list / reorder
    property var listView: null
    property var dragWin: null
    property int modelIndex: -1
    property int dragKey: 0

    // 列表内占位（原槽位）；顶层幽灵卡片
    property bool isDragPlaceholder: false
    property bool isGhostFloat: false
    property real ghostScale: 1.03

    signal toggleDone(bool nextDone)
    signal requestUrgentToggle(int id, bool urgent)
    signal requestInlineSave(int id, string title, string note, int startAtS, int endAtS, bool urgent)
    signal requestDelete(int id)
    signal reorderStateChanged(bool active)

    height: isDragPlaceholder && dragWin && dragWin.ghostSlotHeight > 0 ? dragWin.ghostSlotHeight : implicitHeight

    function clamp01(x) { return Math.max(0, Math.min(1, x)) }
    function sToMs(s) { return s * 1000.0 }

    // swipe（仅非幽灵、非占位）
    property real dragX: 0
    property bool draggingHoriz: false
    property bool draggingVert: false
    property real pressX: 0
    property real pressY: 0
    property bool longPressArmed: false
    property bool inReorder: false
    property bool editMode: false
    property string editTitle: ""
    property string editNote: ""
    property string editStartText: ""
    property string editEndText: ""
    property bool editUrgent: false
    readonly property bool showDeleteBtn: !isGhostFloat && !isDragPlaceholder
    property double _lastClickAtMs: 0
    readonly property color cInputBg: darkTheme ? "#454C58" : "#EFE9DE"
    readonly property color cInputBorder: darkTheme ? "#66707F" : "#CEC4B7"
    readonly property color cInputFocus: darkTheme ? "#8A9B94" : "#96A89E"
    readonly property color cTitleColor: darkTheme ? (done ? "#AAA79F" : "#E6E1D8") : (done ? "#8C857A" : "#4A4A47")
    readonly property color cNoteColor: darkTheme ? (done ? "#8E8B84" : "#B9B3A9") : (done ? "#9A9388" : "#7B756B")
    readonly property int _barStartS: {
        if (!editMode)
            return startAtS
        var p = parseInput(editStartText)
        return p > 0 ? p : startAtS
    }
    readonly property int _barEndS: {
        if (!editMode)
            return endAtS
        var p = parseInput(editEndText)
        return p > 0 ? p : endAtS
    }

    function rubberband(x, limit) {
        if (Math.abs(x) <= limit) return x
        var sign = x < 0 ? -1 : 1
        var over = Math.abs(x) - limit
        return sign * (limit + over * 0.25)
    }
    function fmtInput(s) {
        var d = new Date(s * 1000)
        var pad = function(n){ return (n<10?("0"+n):(""+n)) }
        return d.getFullYear()+"-"+pad(d.getMonth()+1)+"-"+pad(d.getDate())+" "+pad(d.getHours())+":"+pad(d.getMinutes())
    }
    function parseInput(v) {
        var parts = v.split(" ")
        if (parts.length !== 2) return 0
        var d = parts[0].split("-")
        var t = parts[1].split(":")
        if (d.length !== 3 || t.length !== 2) return 0
        var dt = new Date(parseInt(d[0]), parseInt(d[1]) - 1, parseInt(d[2]), parseInt(t[0]), parseInt(t[1]), 0, 0)
        return Math.floor(dt.getTime() / 1000)
    }
    function beginInlineEdit() {
        editMode = true
        editTitle = title
        editNote = note
        editStartText = fmtInput(startAtS)
        editEndText = fmtInput(endAtS)
        editUrgent = urgent
        Qt.callLater(function() {
            titleField.forceActiveFocus()
            titleField.selectAll()
        })
    }
    function cancelInlineEdit() {
        editMode = false
    }
    function commitInlineEdit() {
        var sS = parseInput(editStartText)
        var eS = parseInput(editEndText)
        if (eS < sS) {
            var tmp = sS
            sS = eS
            eS = tmp
        }
        requestInlineSave(eventId, editTitle, editNote, sS, eS, editUrgent)
        editMode = false
    }
    function toggleUrgentNow() {
        if (root.isGhostFloat || root.isDragPlaceholder || root.done)
            return
        if (root.editMode) {
            root.editUrgent = !root.editUrgent
            root.requestUrgentToggle(root.eventId, root.editUrgent)
            return
        }
        root.requestUrgentToggle(root.eventId, !root.urgent)
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        clip: true
        x: root.isDragPlaceholder ? 0 : root.dragX
        y: 0
        scale: root.isGhostFloat ? root.ghostScale : 1.0
        radius: 16
        color: darkTheme ? (done ? "#333843" : "#3A404C") : (done ? "#F0ECE4" : "#FCF9F2")
        border.width: root.isDragPlaceholder ? 2 : 1
        border.color: root.isDragPlaceholder ? (darkTheme ? "#7A837D" : "#B2A99A") : (darkTheme ? "#565F6D" : "#D8D0C1")

        Behavior on x {
            enabled: !root.isDragPlaceholder && !root.isGhostFloat
            NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Rectangle {
            visible: !root.isDragPlaceholder
            anchors.fill: parent
            radius: card.radius
            color: root.dragX > 0 ? (darkTheme ? "#4E5D54" : "#DCE6DE") : (root.dragX < 0 ? (darkTheme ? "#5A4A4F" : "#E9DADD") : "transparent")
            opacity: Math.min(0.35, Math.abs(root.dragX) / 220)
        }
        Rectangle {
            id: urgentPulseRing
            visible: root.urgent && !root.done && !root.isDragPlaceholder
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            border.width: 3
            border.color: darkTheme ? "#FF8A8A" : "#D84F4F"
            opacity: 0.62
            z: 3
            SequentialAnimation on opacity {
                running: urgentPulseRing.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.22; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.8; duration: 900; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            visible: root.urgent && !root.done && !root.isDragPlaceholder
            anchors.fill: parent
            anchors.margins: -4
            radius: card.radius + 4
            color: "transparent"
            border.width: 2
            border.color: darkTheme ? "#FFB3B3" : "#E07777"
            opacity: urgentPulseRing.opacity * 0.65
            z: 2
        }
        Rectangle {
            visible: root.urgent && !root.done && !root.isDragPlaceholder
            anchors.fill: parent
            anchors.margins: -7
            radius: card.radius + 7
            color: "transparent"
            border.width: 1
            border.color: darkTheme ? "#FF9C9C" : "#D76363"
            opacity: urgentPulseRing.opacity * 0.45
            z: 1
        }

        Item {
            id: contentLayer
            width: parent.width
            height: parent.height
            visible: !root.isDragPlaceholder
            opacity: root.isGhostFloat ? 1.0 : 1.0
            z: 3

            Shortcut {
                sequence: "Escape"
                enabled: root.editMode && !root.isGhostFloat && !root.isDragPlaceholder
                onActivated: root.cancelInlineEdit()
            }
            Shortcut {
                sequence: "Ctrl+Return"
                enabled: root.editMode && !root.isGhostFloat && !root.isDragPlaceholder
                onActivated: root.commitInlineEdit()
            }

            ColumnLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: root.editMode ? editActionsBar.top : parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: root.showDeleteBtn ? 44 : 14
                anchors.topMargin: 14
                anchors.bottomMargin: root.editMode ? 8 : 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        visible: !root.editMode
                        text: root.title
                        color: root.cTitleColor
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    TextField {
                        id: titleField
                        Layout.fillWidth: true
                        visible: root.editMode
                        text: root.editTitle
                        placeholderText: "标题"
                        placeholderTextColor: darkTheme ? "#8A8378" : "#A39A8E"
                        padding: 0
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 1
                        bottomPadding: 1
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: root.cTitleColor
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        background: Rectangle {
                            color: "transparent"
                            border.width: 0
                        }
                        onTextChanged: {
                            if (titleField.activeFocus)
                                root.editTitle = text
                        }
                    }
                    Rectangle {
                        visible: done
                        radius: 999
                        color: darkTheme ? "#454C58" : "#ECE7DD"
                        border.width: 1
                        border.color: darkTheme ? "#66707F" : "#CFC6B8"
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: 62
                        Text {
                            anchors.centerIn: parent
                            text: "已完成"
                            color: darkTheme ? "#D8D2C8" : "#6F6A62"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }
                Text {
                    id: noteText
                    Layout.fillWidth: true
                    visible: !root.editMode
                    text: root.note
                    color: root.cNoteColor
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: root.isGhostFloat ? 4 : 999
                    Layout.preferredHeight: contentHeight
                }
                TextArea {
                    id: noteArea
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(180, Math.max(40, noteArea.contentHeight + 6))
                    visible: root.editMode
                    text: root.editNote
                    wrapMode: TextArea.Wrap
                    font.pixelSize: 11
                    color: root.cNoteColor
                    placeholderText: "备注（可选）"
                    placeholderTextColor: darkTheme ? "#7A756C" : "#9A9388"
                    topPadding: 0
                    bottomPadding: 0
                    leftPadding: 0
                    rightPadding: 0
                    selectByMouse: true
                    background: Rectangle {
                        color: "transparent"
                        border.width: noteArea.activeFocus ? 1 : 0
                        border.color: root.cInputFocus
                        radius: 4
                    }
                    onTextChanged: {
                        if (noteArea.activeFocus)
                            root.editNote = text
                    }
                }
                TimelineBar {
                    id: timeBar
                    Layout.fillWidth: true
                    height: 44
                    visible: !root.isGhostFloat
                    axisStartMs: root.axisStartMs
                    axisEndMs: root.axisEndMs
                    nowMs: root.nowMs
                    startMs: root.sToMs(root._barStartS)
                    endMs: root.sToMs(root._barEndS)
                    darkTheme: root.darkTheme
                    editable: root.editMode
                    startEditText: root.editStartText
                    endEditText: root.editEndText
                    onStartTextEdited: function (s) {
                        root.editStartText = s
                    }
                    onEndTextEdited: function (t) {
                        root.editEndText = t
                    }
                    onStartMsDragged: function(ms) {
                        root.editStartText = root.fmtInput(Math.floor(ms / 1000))
                    }
                    onEndMsDragged: function(ms) {
                        root.editEndText = root.fmtInput(Math.floor(ms / 1000))
                    }
                }
            }

            Row {
                id: editActionsBar
                z: 5
                visible: root.editMode
                spacing: 18
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.bottomMargin: 14
                Text {
                    id: cancelGlyph
                    text: "\u00D7"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    color: darkTheme ? "#B8B2A8" : "#8A8378"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.cancelInlineEdit()
                    }
                }
                Text {
                    id: okGlyph
                    text: "\u2713"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: darkTheme ? "#A8B9B0" : "#5E7268"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.commitInlineEdit()
                    }
                }
            }
            Item {
                id: urgentAction
                visible: !root.isGhostFloat && !root.isDragPlaceholder && !root.done
                z: 8
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 5
                width: 52
                height: 30
                scale: urgentBtn.pressed ? 0.93 : (urgentBtn.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                Rectangle {
                    anchors.centerIn: parent
                    width: 48
                    height: 26
                    radius: 13
                    color: "transparent"
                    border.width: 1
                    border.color: root.urgent
                        ? (darkTheme ? "#E5A3A3" : "#C06A6A")
                        : (darkTheme ? "#7D6668" : "#BEA5A5")
                    opacity: urgentBtn.containsMouse || root.urgent ? 0.88 : 0.5
                    SequentialAnimation on opacity {
                        running: root.urgent && !urgentBtn.pressed
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.42; duration: 1200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.95; duration: 1200; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 24
                    radius: 12
                    color: (urgentBtn.containsMouse || urgentBtn.pressed)
                        ? (darkTheme ? "#B85A5A" : "#D98585")
                        : (root.urgent ? (darkTheme ? "#A85D5D" : "#C97777") : (darkTheme ? "#665357" : "#D2B4B4"))
                    border.width: 1
                    border.color: darkTheme ? "#E7C5C5" : "#BD7C7C"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        color: root.urgent ? "#FFF8F8" : (darkTheme ? "#EBD9D9" : "#7B6060")
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 999
                    color: "transparent"
                    border.width: 1.5
                    border.color: darkTheme ? "#FFD2D2" : "#D56565"
                    opacity: urgentBtn.pressed ? 0.75 : 0.0
                    scale: urgentBtn.pressed ? 1.0 : 2.6
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: urgentBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleUrgentNow()
                }
            }

            Connections {
                target: root
                function onEditTitleChanged() {
                    if (!titleField.activeFocus)
                        titleField.text = root.editTitle
                }
                function onEditNoteChanged() {
                    if (!noteArea.activeFocus)
                        noteArea.text = root.editNote
                }
            }
        }

        Rectangle {
            visible: root.isDragPlaceholder
            anchors.centerIn: parent
            width: parent.width - 32
            height: 4
            radius: 2
            color: darkTheme ? "#6A736E" : "#BFB4A4"
            opacity: 0.6
        }

        MouseArea {
            id: gesture
            anchors.fill: parent
            visible: !root.isGhostFloat && !root.editMode
            enabled: !root.editMode
            z: 2
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            preventStealing: root.draggingHoriz || root.inReorder
            pressAndHoldInterval: 500

            onPressed: (m) => {
                if (root.isDragPlaceholder) return
                root.pressX = m.x
                root.pressY = m.y
                root.draggingHoriz = false
                root.draggingVert = false
                root.longPressArmed = true
                root.inReorder = false
                root.dragX = 0
            }

            onPressAndHold: (m) => {
                if (root.editMode) return
                if (root.isGhostFloat || root.isDragPlaceholder) return
                if (root.draggingHoriz || root.draggingVert) return
                if (!root.dragWin || root.modelIndex < 0) return
                root.inReorder = true
                root.longPressArmed = false
                root.dragWin.beginGhostReorder(root.modelIndex, root, m.x, m.y, {
                    id: root.eventId,
                    title: root.title,
                    note: root.note,
                    urgent: root.urgent,
                    done: root.done,
                    startAtS: root.startAtS,
                    endAtS: root.endAtS
                })
                root.reorderStateChanged(true)
            }

            onPositionChanged: (m) => {
                if (root.editMode) return
                if (root.isGhostFloat) return
                if (!pressed && !(root.inReorder && root.dragWin && root.dragWin.ghostDragging)) return

                var dx = m.x - root.pressX
                var dy = m.y - root.pressY

                if (root.inReorder && root.dragWin && root.dragWin.ghostDragging) {
                    root.dragWin.updateGhostReorder(root, m.x, m.y)
                    return
                }

                if (!root.draggingHoriz && !root.draggingVert) {
                    if (Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy) * 1.2) {
                        root.draggingHoriz = true
                        root.longPressArmed = false
                    } else if (Math.abs(dy) > 10 && Math.abs(dy) > Math.abs(dx) * 1.2) {
                        root.draggingVert = true
                        root.longPressArmed = false
                    }
                }
                if (root.draggingHoriz) {
                    root.dragX = rubberband(dx, 140)
                }
            }

            onReleased: (m) => {
                if (root.isGhostFloat) return
                if (root.editMode) return
                root.longPressArmed = false

                if (root.inReorder && root.dragWin && root.dragWin.ghostDragging) {
                    root.dragWin.endGhostReorder()
                    root.inReorder = false
                    root.reorderStateChanged(false)
                    return
                }

                if (root.draggingHoriz) {
                    var threshold = 110
                    if (Math.abs(root.dragX) > threshold) {
                        var goRight = root.dragX > 0
                        root.dragX = goRight ? (root.width + 40) : -(root.width + 40)
                        Qt.callLater(function() {
                            root.toggleDone(!root.done)
                            root.dragX = 0
                        })
                    } else {
                        root.dragX = 0
                    }
                } else {
                    root.dragX = 0
                }
                root.draggingHoriz = false
                root.draggingVert = false
                root.reorderStateChanged(false)
            }

            // 双击兜底：某些手势组合下 onDoubleClicked 可能不稳定
            onClicked: {
                if (root.isDragPlaceholder || root.isGhostFloat || root.editMode) return
                var now = Date.now()
                if (now - root._lastClickAtMs < 280) {
                    root.beginInlineEdit()
                    root._lastClickAtMs = 0
                } else {
                    root._lastClickAtMs = now
                }
            }

            onCanceled: {
                if (root.inReorder && root.dragWin && root.dragWin.ghostDragging) {
                    root.dragWin.endGhostReorder()
                }
                root.inReorder = false
                root.longPressArmed = false
                root.dragX = 0
                root.draggingHoriz = false
                root.draggingVert = false
                root.reorderStateChanged(false)
            }

            onDoubleClicked: {
                if (!root.isDragPlaceholder && !root.isGhostFloat) root.beginInlineEdit()
            }
        }

        Item {
            id: deleteHit
            visible: root.showDeleteBtn
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 40
            z: 60

            property bool hovered: deleteArea.containsMouse || deleteArea.pressed

            Rectangle {
                anchors.centerIn: parent
                width: 34
                height: 34
                radius: 10
                color: deleteHit.hovered
                    ? (darkTheme ? Qt.rgba(0.78, 0.42, 0.42, 0.35) : Qt.rgba(0.75, 0.35, 0.35, 0.2))
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Item {
                width: 20
                height: 22
                anchors.centerIn: parent
                readonly property color stroke: deleteHit.hovered
                    ? (darkTheme ? "#E8A0A0" : "#B85C5C")
                    : (darkTheme ? "#B0A8A0" : "#8A8278")
                Rectangle {
                    x: (parent.width - 6) / 2
                    y: 0
                    width: 6
                    height: 5
                    radius: 1
                    color: "transparent"
                    border.width: 1.5
                    border.color: parent.stroke
                }
                Rectangle {
                    x: (parent.width - 14) / 2
                    y: 5
                    width: 14
                    height: 3
                    radius: 1
                    color: parent.stroke
                }
                Rectangle {
                    x: (parent.width - 12) / 2
                    y: 9
                    width: 12
                    height: 11
                    radius: 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: parent.stroke
                }
            }
            MouseArea {
                id: deleteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestDelete(root.eventId)
            }
        }
    }
}
