/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Página de Listas: listas gerais e de compras.
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

    required property var lists
    signal addList(string name)
    signal removeList(int index)
    signal addItem(int listIndex, string text)
    signal removeItem(int listIndex, int itemIndex)
    signal toggleItem(int listIndex, int itemIndex)

    property int expandedList: -1

    Flickable {
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: mainCol.implicitHeight + Kirigami.Units.largeSpacing * 2

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

        ColumnLayout {
            id: mainCol
            width: parent.width
            anchors.top: parent.top
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                spacing: Kirigami.Units.smallSpacing

                PlasmaExtras.Heading {
                    level: 4
                    Layout.fillWidth: true
                    text: root.t("Suas listas, compras ou qualquer coisa que precise organizar...")
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    elide: Text.ElideRight
                    font.pixelSize: 13
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                opacity: 0.15
            }

            // Entrada para nova lista
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextField {
                    id: newListField
                    Layout.fillWidth: true
                    placeholderText: root.t("Nome da nova lista...")
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    onAccepted: {
                        if (text.trim().length > 0) {
                            page.addList(text.trim());
                            text = "";
                        }
                    }
                }

                QQC2.Button {
                    text: "+"
                    implicitWidth: 40
                    onClicked: {
                        if (newListField.text.trim().length > 0) {
                            page.addList(newListField.text.trim());
                            newListField.text = "";
                        }
                    }
                }
            }

            // Listas
            Repeater {
                model: page.lists

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    radius: Kirigami.Units.largeSpacing
                    color: root.isDarkTheme ? Qt.rgba(0.25, 0.25, 0.25, 1) : Qt.rgba(0.95, 0.95, 0.95, 1)
                    border.width: 1
                    border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
                    implicitHeight: listCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                    Layout.topMargin: Kirigami.Units.smallSpacing

                    property bool isExpanded: page.expandedList === index

                    ColumnLayout {
                        id: listCol
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        // Header da lista
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.bold: true
                                font.pixelSize: 13
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            }

                            PlasmaComponents3.Label {
                                text: modelData.items.length + " " + root.t("itens")
                                font.pixelSize: 11
                                color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.5, 0.5, 0.5, 1)
                            }

                            PlasmaComponents3.ToolButton {
                                text: isExpanded ? "▲" : "▼"
                                font.pixelSize: 10
                                contentItem: Text {
                                    text: isExpanded ? "▲" : "▼"
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: page.expandedList = isExpanded ? -1 : index
                            }

                            PlasmaComponents3.ToolButton {
                                text: "×"
                                font.pixelSize: 14
                                contentItem: Text {
                                    text: "×"
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: page.removeList(index)
                            }
                        }

                        // Itens da lista (quando expandida)
                        ColumnLayout {
                            visible: isExpanded
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Separator {
                                Layout.fillWidth: true
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                opacity: 0.15
                            }

                            Repeater {
                                model: modelData.items

                                delegate: RowLayout {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    QQC2.CheckBox {
                                        checked: modelData.done
                                        onToggled: page.toggleItem(model.index, index)
                                    }

                                    PlasmaComponents3.Label {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        font.pixelSize: 12
                                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                        opacity: modelData.done ? 0.5 : 1.0
                                        font.italic: modelData.done
                                    }

                                    PlasmaComponents3.ToolButton {
                                        text: "×"
                                        font.pixelSize: 10
                                        contentItem: Text {
                                            text: "×"
                                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: page.removeItem(model.index, index)
                                    }
                                }
                            }

                            // Adicionar item
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                QQC2.TextField {
                                    Layout.fillWidth: true
                                    placeholderText: root.t("Novo item...")
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    onAccepted: {
                                        if (text.trim().length > 0) {
                                            page.addItem(index, text.trim());
                                            text = "";
                                        }
                                    }
                                }

                                QQC2.Button {
                                    text: "+"
                                    implicitWidth: 36
                                    property var inputField: parent.children[0]
                                    onClicked: {
                                        if (inputField.text.trim().length > 0) {
                                            page.addItem(index, inputField.text.trim());
                                            inputField.text = "";
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
