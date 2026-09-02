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

Item {
    id: page

    required property var todos
    required property var completedTodos
    signal addTodo(string text)
    signal toggleTodo(int index)
    signal removeTodo(int index)
    signal restoreTodo(int index)
    signal removeCompletedTodo(int index)

    property bool showHistory: false

    Flickable {
        id: pageFlick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: rootCol.implicitHeight + Kirigami.Units.largeSpacing * 2

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

        ColumnLayout {
            id: rootCol
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // Entrada para nova tarefa
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextField {
                    id: newTodoField
                    Layout.fillWidth: true
                    placeholderText: i18n("Nova tarefa…")
                    onAccepted: {
                        if (text.trim() !== "") {
                            page.addTodo(text);
                            text = "";
                        }
                    }
                }

                PlasmaComponents3.Button {
                    text: i18n("Adicionar")
                    onClicked: {
                        if (newTodoField.text.trim() !== "") {
                            page.addTodo(newTodoField.text);
                            newTodoField.text = "";
                        }
                    }
                }
            }

            // Cabeçalho
            PlasmaExtras.Heading {
                level: 4
                Layout.fillWidth: true
                text: i18n("Tarefas de hoje")
                color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: page.todos.length > 0
                text: page.todos.length + i18n(" pendente(s)")
                opacity: 0.6
                font.pixelSize: 11
            }

            Kirigami.PlaceholderMessage {
                visible: page.todos.length === 0
                Layout.fillWidth: true
                text: i18n("Nenhuma tarefa ainda.\nAdicione uma acima para começar o dia.")
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
            required property int index
            required property var model

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(38, row.implicitHeight + Kirigami.Units.smallSpacing * 2)
            radius: Kirigami.Units.smallSpacing
            color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.05)
            border.width: 1
            border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.08)

            RowLayout {
                id: row
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                QQC2.CheckBox {
                    checked: false
                    onClicked: page.toggleTodo(index)
                    Accessible.name: model.text
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: model.text
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                }

                PlasmaComponents3.ToolButton {
                    text: "✕"
                    Accessible.name: i18n("Remover tarefa")
                    onClicked: page.removeTodo(index)
                }
            }
        }
    }

    // Botão de histórico (canto inferior direito)
    PlasmaComponents3.ToolButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Kirigami.Units.largeSpacing
        icon.name: "media-floppy"
        width: 40
        height: 40
        visible: page.completedTodos.length > 0
        onClicked: page.showHistory = !page.showHistory
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.text: i18n("Tarefas concluídas (%1)", page.completedTodos.length)
    }

    // Painel de histórico
    Rectangle {
        visible: page.showHistory && page.completedTodos.length > 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Kirigami.Units.largeSpacing
        width: 280
        height: Math.min(350, historyCol.implicitHeight + Kirigami.Units.largeSpacing * 2)
        radius: Kirigami.Units.largeSpacing
        color: (root.isDarkTheme ? Qt.rgba(0.22, 0.22, 0.22, 1) : Qt.rgba(0.95, 0.95, 0.95, 1))
        border.width: 1
        border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.15)
        z: 10

        ColumnLayout {
            id: historyCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaExtras.Heading {
                    level: 4
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                    text: i18n("Concluídas (%1)", page.completedTodos.length)
                    Layout.fillWidth: true
                }
                PlasmaComponents3.ToolButton {
                    text: "✕"
                    onClicked: page.showHistory = false
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Repeater {
                model: page.completedTodos
                delegate: Rectangle {
                    required property int index
                    required property var model

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(34, histRow.implicitHeight + Kirigami.Units.smallSpacing)
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
                            QQC2.ToolTip.text: i18n("Restaurar tarefa")
                            onClicked: page.restoreTodo(index)
                        }

                        PlasmaComponents3.ToolButton {
                            text: "✕"
                            width: 28
                            height: 28
                            Accessible.name: i18n("Remover permanentemente")
                            onClicked: page.removeCompletedTodo(index)
                        }
                    }
                }
            }
        }
    }
}
