import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: dlg
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property double axisStartMs: 0
    property double axisEndMs: 0

    property bool isEdit: false
    property int editId: 0
    property bool darkTheme: true
    readonly property color cInputBg: darkTheme ? "#3E4552" : "#F2EEE6"
    readonly property color cInputBorder: darkTheme ? "#636C7C" : "#CFC5B7"
    readonly property color cInputFocus: darkTheme ? "#8A9B94" : "#96A89E"
    readonly property color cTextPrimary: darkTheme ? "#E6E1D8" : "#4A4A47"
    readonly property color cTextSecondary: darkTheme ? "#B9B3A9" : "#7E786F"

    signal saveNew(string title, string note, int startAtS, int endAtS, bool urgent)
    signal saveEdit(int id, string title, string note, int startAtS, int endAtS, bool urgent)

    width: Math.min(720, parent ? parent.width - 80 : 720)
    height: 408

    background: Rectangle {
        radius: 16
        color: darkTheme ? "#343A45" : "#FBF8F2"
        border.color: darkTheme ? "#596272" : "#D8D0C1"
        border.width: 1
    }

    function openForNew() {
        isEdit = false
        editId = 0
        titleField.text = ""
        noteField.text = ""
        urgentBox.checked = false
        var now = new Date()
        startField.text = Qt.formatDateTime(now, "yyyy-MM-dd HH:mm")
        var later = new Date(now.getTime() + 2 * 3600 * 1000)
        endField.text = Qt.formatDateTime(later, "yyyy-MM-dd HH:mm")
        open()
    }

    function openForEdit(id, title, note, startAtS, endAtS, urgent) {
        isEdit = true
        editId = id
        titleField.text = title
        noteField.text = note
        urgentBox.checked = urgent
        startField.text = Qt.formatDateTime(new Date(startAtS * 1000), "yyyy-MM-dd HH:mm")
        endField.text = Qt.formatDateTime(new Date(endAtS * 1000), "yyyy-MM-dd HH:mm")
        open()
    }

    function parseToSeconds(s) {
        // expected: "yyyy-MM-dd HH:mm"
        var parts = s.split(" ")
        if (parts.length !== 2) return 0
        var d = parts[0].split("-")
        var t = parts[1].split(":")
        if (d.length !== 3 || t.length !== 2) return 0
        var dt = new Date(parseInt(d[0]), parseInt(d[1]) - 1, parseInt(d[2]), parseInt(t[0]), parseInt(t[1]), 0, 0)
        return Math.floor(dt.getTime() / 1000)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: dlg.isEdit ? "编辑父事件" : "新建父事件"
                color: darkTheme ? "#E6E1D8" : "#4A4A47"
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Button {
                text: "关闭"
                onClicked: dlg.close()
                background: Rectangle { radius: 10; color: darkTheme ? "#424A57" : "#F2EDE3"; border.color: darkTheme ? "#606A79" : "#CEC4B5"; border.width: 1 }
                contentItem: Text { text: parent.text; color: darkTheme ? "#C3BEB3" : "#6F6A62"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }

        TextField {
            id: titleField
            Layout.fillWidth: true
            placeholderText: "标题"
            color: dlg.cTextPrimary
            placeholderTextColor: dlg.cTextSecondary
            background: Rectangle {
                radius: 10
                color: dlg.cInputBg
                border.width: 1
                border.color: titleField.activeFocus ? dlg.cInputFocus : dlg.cInputBorder
            }
        }

        TextArea {
            id: noteField
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: "备注（可选）"
            wrapMode: TextArea.Wrap
            color: dlg.cTextPrimary
            placeholderTextColor: dlg.cTextSecondary
            background: Rectangle {
                radius: 10
                color: dlg.cInputBg
                border.width: 1
                border.color: noteField.activeFocus ? dlg.cInputFocus : dlg.cInputBorder
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            TextField {
                id: startField
                Layout.fillWidth: true
                placeholderText: "开始 yyyy-MM-dd HH:mm"
                color: dlg.cTextPrimary
                placeholderTextColor: dlg.cTextSecondary
                background: Rectangle {
                    radius: 10
                    color: dlg.cInputBg
                    border.width: 1
                    border.color: startField.activeFocus ? dlg.cInputFocus : dlg.cInputBorder
                }
            }
            TextField {
                id: endField
                Layout.fillWidth: true
                placeholderText: "截止 yyyy-MM-dd HH:mm"
                color: dlg.cTextPrimary
                placeholderTextColor: dlg.cTextSecondary
                background: Rectangle {
                    radius: 10
                    color: dlg.cInputBg
                    border.width: 1
                    border.color: endField.activeFocus ? dlg.cInputFocus : dlg.cInputBorder
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            CheckBox {
                id: urgentBox
                text: "紧急"
                contentItem: Text {
                    text: urgentBox.text
                    color: dlg.cTextSecondary
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: urgentBox.indicator.width + urgentBox.spacing
                }
                indicator: Rectangle {
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 4
                    y: (parent.height - height) / 2
                    color: urgentBox.checked ? dlg.cInputFocus : dlg.cInputBg
                    border.width: 1
                    border.color: urgentBox.checked ? dlg.cInputFocus : dlg.cInputBorder
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 2
                        color: "#F8F5EE"
                        visible: urgentBox.checked
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "保存"
                background: Rectangle { radius: 10; color: darkTheme ? "#8A9B94" : "#96A89E" }
                contentItem: Text { text: parent.text; color: darkTheme ? "#F5F1E8" : "#F9F6EF"; font.pixelSize: 13; font.weight: Font.Medium; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var sS = parseToSeconds(startField.text)
                    var eS = parseToSeconds(endField.text)
                    if (eS < sS) {
                        var tmp = sS; sS = eS; eS = tmp
                    }
                    if (dlg.isEdit) {
                        dlg.saveEdit(dlg.editId, titleField.text, noteField.text, sS, eS, urgentBox.checked)
                    } else {
                        dlg.saveNew(titleField.text, noteField.text, sS, eS, urgentBox.checked)
                    }
                    dlg.close()
                }
            }
        }
    }
}

