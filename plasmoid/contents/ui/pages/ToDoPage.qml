/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Página de To-Dos: tarefas do dia, com adicionar, concluir e excluir.
    Tarefas concluídas são movidas para completedList e ficam no histórico.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.dateandtime as DateAndTime

Item {
    id: page

    required property var todos
    required property var completedTodos
    signal addTodo(string text, var dueDate)
    signal toggleTodo(int index)
    signal removeTodo(int index)
    signal restoreTodo(int index)
    signal removeCompletedTodo(int index)

    property bool showHistory: false
    property var newDueDate: 0
    property string draftTodoText: ""

    // Mantém o cursor visível enquanto digita (caixa e barra acompanham).
    function followCursor(flick, edit) {
        var cr = edit.cursorRectangle;
        if (cr.y < flick.contentY) {
            flick.contentY = cr.y;
        } else if (cr.y + cr.height > flick.contentY + flick.height) {
            flick.contentY = cr.y + cr.height - flick.height;
        }
    }

    function commitNewTodo() {
        if (page.draftTodoText.trim() === "") {
            return;
        }
        page.addTodo(page.draftTodoText.trim(), page.newDueDate);
        page.draftTodoText = "";
        page.newDueDate = 0;
    }

    // Espaço reservado para a barra de rolagem vertical (desenhada por cima
    // do conteúdo no QQC2): tarefas e histórico não ficam sob a barra.
    readonly property real scrollGutter: todoScrollBar.visible ? todoScrollBar.width : 0
    readonly property real historyScrollGutter: histScrollBar.visible ? histScrollBar.width : 0

    function createdDateText(ms) {
        if (!ms) return "";
        var d = new Date(ms);
        var now = new Date();
        if (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()) {
            return i18n("Today");
        }
        return d.toLocaleString(Qt.locale(), "dd/MM");
    }

    function dueDateText(ms) {
        if (!ms) return "";
        var d = new Date(ms);
        var now = new Date();
        var t0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        var d0 = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        var diffDays = Math.round((d0 - t0) / 86400000);
        if (diffDays === 0) return i18n("Today");
        if (diffDays === 1) return i18n("Tomorrow");
        return d.toLocaleString(Qt.locale(), "dd/MM/yyyy");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            id: pageFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: rootCol.implicitHeight + Kirigami.Units.largeSpacing * 2

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            id: todoScrollBar
            policy: QQC2.ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: rootCol
            width: parent.width - page.scrollGutter - Kirigami.Units.largeSpacing
            anchors.top: parent.top
            anchors.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // Header (padrão em todas as abas)
            PageHeader {
                title: i18n("These are the tasks you need to complete")
                margins: 0
            }

            // Entrada para nova tarefa
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // Entrada para nova tarefa: multi-linha com barra de rolagem própria
                Rectangle {
                    id: newTodoBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    Layout.alignment: Qt.AlignVCenter
                    radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(root.textMain, 0.2)
                    clip: true

                    readonly property bool todoNeedsScroll: newTodoEdit.implicitHeight > newTodoFlick.height

                    Text {
                        visible: newTodoEdit.text === ""
                        z: -1
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 6
                        text: i18n("New task…")
                        font.pixelSize: 13
                        color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.35, 0.35, 0.35, 1)
                    }

                    Flickable {
                        id: newTodoFlick
                        anchors.fill: parent
                        anchors.rightMargin: newTodoBox.todoNeedsScroll ? 7 : 1
                        clip: true
                        contentWidth: width
                        contentHeight: newTodoEdit.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: newTodoEdit
                            width: newTodoFlick.width + 1
                            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                            text: page.draftTodoText
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            selectionColor: root.accentMain
                            selectedTextColor: "white"
                            selectByMouse: true
                            persistentSelection: true
                            padding: 6
                            onTextChanged: page.draftTodoText = text
                            onCursorRectangleChanged: page.followCursor(newTodoFlick, newTodoEdit)
                            Keys.onReturnPressed: {
                                if (!(event.modifiers & Qt.ShiftModifier)) {
                                    page.commitNewTodo();
                                    event.accepted = true;
                                }
                            }
                            Keys.onEnterPressed: {
                                if (!(event.modifiers & Qt.ShiftModifier)) {
                                    page.commitNewTodo();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: newTodoBox.todoNeedsScroll
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: 5
                        radius: 2.5
                        color: "transparent"

                        Rectangle {
                            id: newTodoHandle
                            width: 5
                            radius: 2.5
                            color: root.isDarkTheme ? Qt.rgba(0.5, 0.8, 1, 0.6) : Qt.rgba(0.15, 0.5, 0.85, 0.55)
                            height: Math.max(16, newTodoTrack.height * newTodoFlick.height / Math.max(1, newTodoEdit.implicitHeight))
                            y: newTodoTrack.height > newTodoHandle.height
                               ? (newTodoEdit.implicitHeight > newTodoFlick.height
                                  ? newTodoFlick.contentY / (newTodoEdit.implicitHeight - newTodoFlick.height)
                                    * (newTodoTrack.height - newTodoHandle.height)
                                  : 0)
                               : 0
                        }
                    }

                    MouseArea {
                        id: newTodoTrack
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: 8
                        visible: newTodoBox.todoNeedsScroll
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => newTodoGrab(mouse.y)
                        onPositionChanged: (mouse) => newTodoGrab(mouse.y)
                        function newTodoGrab(ty) {
                            var range = Math.max(1, newTodoEdit.implicitHeight - newTodoFlick.height);
                            var trav = Math.max(1, newTodoTrack.height - newTodoHandle.height);
                            newTodoFlick.contentY = Math.max(0, Math.min(range, (ty - newTodoHandle.height / 2) / trav * range));
                        }
                    }
                }

                PlasmaComponents3.Button {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Math.max(96, implicitWidth)
                    text: page.newDueDate > 0 ? i18n("Deadline: %1", page.dueDateText(page.newDueDate)) : i18n("Deadline")
                    icon.name: "view-calendar-day"
                    onClicked: duePicker.open()
                }

                PlasmaComponents3.ToolButton {
                    Layout.alignment: Qt.AlignTop
                    visible: page.newDueDate > 0
                    text: "\u00D7"
                    Accessible.name: i18n("Remove deadline")
                    onClicked: page.newDueDate = 0
                }

                PlasmaComponents3.Button {
                    Layout.alignment: Qt.AlignTop
                    text: i18n("Add")
                    enabled: page.draftTodoText.trim() !== ""
                    onClicked: page.commitNewTodo()
                }
            }

            // Popup de escolha de data do prazo
            DateAndTime.DatePopup {
                id: duePicker
                value: page.newDueDate > 0 ? new Date(page.newDueDate) : new Date()
                minimumDate: new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())
                onAccepted: page.newDueDate = duePicker.value.getTime()
            }

            // Cabeçalho
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: page.todos.length > 0
                text: page.todos.length + i18n(" pending")
                opacity: 0.6
                font.pixelSize: 11
            }

            Kirigami.PlaceholderMessage {
                visible: page.todos.length === 0
                Layout.fillWidth: true
                text: i18n("No tasks yet.\nAdd one above to start your day.")
                icon.name: "task-new"
            }

            Repeater {
                model: page.todos
                delegate: todoDelegate
            }
        }
    }

    Component {
        id: todoDelegate
        Rectangle {
            id: todoRect
            required property int index
            required property var model

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(38, row.implicitHeight + Kirigami.Units.smallSpacing * 2)
            radius: Kirigami.Units.smallSpacing
            color: Qt.alpha(root.textMain, 0.05)
            border.width: 1
            border.color: Qt.alpha(root.textMain, 0.08)

            RowLayout {
                id: row
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                // Data de inclusão (como na Agenda)
                ColumnLayout {
                    spacing: 0
                    Layout.preferredWidth: 58
                    visible: model.createdAt > 0

                    PlasmaComponents3.Label {
                        color: root.textMain
                        text: i18n("Added on")
                        font.pixelSize: 9
                        opacity: 0.55
                    }
                    PlasmaComponents3.Label {
                        color: root.textMain
                        text: page.createdDateText(model.createdAt)
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }

                QQC2.CheckBox {
                    checked: model.done
                    onClicked: completeAnim.restart()
                    Accessible.name: model.text
                }

                PlasmaComponents3.Label {
                    id: todoLabel
                    Layout.fillWidth: true
                    text: model.text
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    color: root.textMain
                }

                // Prazo de término (quando definido)
                Rectangle {
                    visible: model.dueDate > 0
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: Math.max(dueText.implicitWidth + Kirigami.Units.smallSpacing * 2, 34)
                    radius: 11
                    color: Qt.alpha("#e05c10", 0.18)
                    border.width: 1
                    border.color: Qt.alpha("#e05c10", 0.35)

                    PlasmaComponents3.Label {
                        id: dueText
                        anchors.centerIn: parent
                        text: page.dueDateText(model.dueDate)
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: "#e05c10"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                PlasmaComponents3.ToolButton {
                    text: "✕"
                    Accessible.name: i18n("Remove task")
                    onClicked: page.removeTodo(index)
                }
            }

            // Risca o texto (strike-through animado) ao concluir, depois some.
            Rectangle {
                id: strikeLine
                visible: lineWidth > 0
                height: 2
                radius: 1
                color: Qt.alpha(root.textMain, 0.6)
                anchors.left: todoLabel.left
                anchors.verticalCenter: todoLabel.verticalCenter
                property real lineWidth: 0
                width: lineWidth
            }

            SequentialAnimation {
                id: completeAnim
                PropertyAnimation {
                    target: strikeLine
                    property: "lineWidth"
                    to: todoLabel.width
                    duration: 220
                    easing.type: Easing.InOutQuad
                }
                ParallelAnimation {
                    NumberAnimation { target: todoRect; property: "opacity"; to: 0; duration: 150 }
                    NumberAnimation { target: todoRect; property: "scale"; to: 0.98; duration: 150 }
                }
                ScriptAction { script: page.toggleTodo(index) }
            }
        }
    }

// Botão de histórico fixo no rodapé
    PlasmaComponents3.Button {
        id: histToggleBtn
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        visible: page.completedTodos.length > 0
        text: (page.showHistory ? "\u25BC " : "\u25B6 ") + i18n("Completed tasks history") + " (" + page.completedTodos.length + ")"
        onClicked: page.showHistory = !page.showHistory
    }
}

// Popup de histórico (abre ao pressionar o botão)
Rectangle {
    id: historyPopup
    visible: page.showHistory && page.completedTodos.length > 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: Kirigami.Units.largeSpacing
    anchors.rightMargin: Kirigami.Units.largeSpacing
    anchors.bottom: parent.bottom
    anchors.bottomMargin: histToggleBtn.height + Kirigami.Units.smallSpacing * 2
    height: Math.min(340, historyPopupCol.implicitHeight + Kirigami.Units.largeSpacing * 2)
    radius: Kirigami.Units.largeSpacing
    color: (root.isDarkTheme ? Qt.rgba(0.22, 0.22, 0.22, 1) : Qt.rgba(0.95, 0.95, 0.95, 1))
    border.width: 1
    border.color: Qt.alpha(root.textMain, 0.15)
    z: 10
    opacity: page.showHistory ? 1 : 0
    scale: page.showHistory ? 1 : 0.98
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: historyPopupCol
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaExtras.Heading {
                level: 4
                color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                text: i18n("Completed (%1)", page.completedTodos.length)
                Layout.fillWidth: true
            }
            PlasmaComponents3.ToolButton {
                text: "\u00D7"
                Accessible.name: i18n("Close history")
                onClicked: page.showHistory = false
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Flickable {
            id: historyFlick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(230, historyItems.implicitHeight)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: historyItems.implicitHeight

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                id: histScrollBar
                policy: QQC2.ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: historyItems
                width: parent.width - page.historyScrollGutter
                anchors.top: parent.top
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: page.completedTodos
                    delegate: Rectangle {
                        required property int index
                        required property var model

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(30, histRow.implicitHeight + Kirigami.Units.smallSpacing)
                        radius: Kirigami.Units.smallSpacing
                        color: "transparent"

                        RowLayout {
                            id: histRow
                            anchors.fill: parent
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: "dialog-ok"
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                            }

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                text: model.text
                                font.pixelSize: 11
                                opacity: 0.7
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                font.italic: true
                            }

                            PlasmaComponents3.ToolButton {
                                icon.name: "edit-undo"
                                width: 28
                                height: 28
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: i18n("Restore task")
                                onClicked: page.restoreTodo(index)
                            }

                            PlasmaComponents3.ToolButton {
                                text: "\u00D7"
                                width: 28
                                height: 28
                                Accessible.name: i18n("Remove permanently")
                                onClicked: page.removeCompletedTodo(index)
                            }
                        }
                    }
                }
            }
        }
    }
}
}
