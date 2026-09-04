/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Página de Notas: post-its com popup ao clicar.
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

    required property var notes
    signal addNote(string text, string color)
    signal removeNote(int index)
    signal updateNoteColor(int index, string color)
    signal updateNoteText(int index, string text)

    property var noteColors: ["#FFF9C4", "#C8E6C9", "#BBDEFB", "#F8BBD0", "#E1BEE7", "#FFE0B2"]
    property string selectedColor: noteColors[0]
    property int popupIndex: -1

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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                spacing: Kirigami.Units.smallSpacing

                PlasmaExtras.Heading {
                    level: 4
                    Layout.fillWidth: true
                    text: root.t("Suas notas, pensamentos ou qualquer coisa que precise anotar...")
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

            // Entrada para nova nota
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: newNoteCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.largeSpacing
                color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), 0.08)
                border.width: 1
                border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), 0.15)

                ColumnLayout {
                    id: newNoteCol
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.TextField {
                        id: newNoteField
                        Layout.fillWidth: true
                        placeholderText: root.t("Escreva sua nota…")
                        wrapMode: Text.Wrap
                        onAccepted: addNoteAction.trigger()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: page.noteColors
                            Rectangle {
                                width: 22
                                height: 22
                                radius: width / 2
                                color: modelData
                                border.width: page.selectedColor === modelData ? 2 : 1
                                border.color: page.selectedColor === modelData
                                             ? (root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1))
                                             : Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.2)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.selectedColor = modelData
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        PlasmaComponents3.Button {
                            id: addNoteAction
                            text: root.t("Adicionar")
                            icon.name: "list-add"
                            enabled: newNoteField.text.trim() !== ""
                            onClicked: {
                                page.addNote(newNoteField.text.trim(), page.selectedColor);
                                newNoteField.text = "";
                            }
                        }
                    }
                }
            }

            // Grid de notas
            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor((mainCol.width + Kirigami.Units.largeSpacing) / (160 + Kirigami.Units.largeSpacing)))
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.largeSpacing

                Repeater {
                    model: page.notes

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: Kirigami.Units.smallSpacing
                        color: (page.notes[index] && page.notes[index].color) || page.noteColors[0]
                        border.width: 1
                        border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.12)

                        PlasmaComponents3.Label {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            text: page.notes[index] ? page.notes[index].text : ""
                            font.pixelSize: 13
                            color: "#1a1a1a"
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.popupIndex = index;
                                notePopup.open();
                            }
                        }
                    }
                }
            }

            Kirigami.PlaceholderMessage {
                visible: page.notes.length === 0
                Layout.fillWidth: true
                text: root.t("Nenhuma nota ainda.\nEscreva uma acima para começar.")
                icon.name: "note-new"
            }
        }
    }

    // Popup da nota
    QQC2.Popup {
        id: notePopup
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(450, parent.width * 0.85)
        height: notePopupCol.implicitHeight + Kirigami.Units.largeSpacing * 4
        modal: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

        property int currentIndex: page.popupIndex
        property string currentColor: page.popupIndex >= 0 && page.notes[page.popupIndex]
                                     ? page.notes[page.popupIndex].color : page.noteColors[0]
        property string currentText: page.popupIndex >= 0 && page.notes[page.popupIndex]
                                     ? page.notes[page.popupIndex].text : ""

        ColumnLayout {
            id: notePopupCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // Texto da nota (editável)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: Kirigami.Units.smallSpacing
                color: notePopup.currentColor
                border.width: 1
                border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.1)

                QQC2.TextArea {
                    id: noteTextField
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    text: notePopup.currentText
                    wrapMode: Text.Wrap
                    font.pixelSize: 14
                    color: "#1a1a1a"
                    background: Item {}
                    onTextChanged: {
                        if (notePopup.currentIndex >= 0) {
                            page.updateNoteText(notePopup.currentIndex, text);
                        }
                    }
                }
            }

            // Seletor de cor
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: page.noteColors
                    Rectangle {
                        width: 26
                        height: 26
                        radius: width / 2
                        color: modelData
                        border.width: notePopup.currentColor === modelData ? 3 : 1
                        border.color: notePopup.currentColor === modelData
                                     ? (root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1))
                                     : Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.2)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                notePopup.currentColor = modelData;
                                page.updateNoteColor(notePopup.currentIndex, modelData);
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Botões de ação
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    text: root.t("Apagar")
                    icon.name: "edit-delete"
                    onClicked: {
                        page.removeNote(notePopup.currentIndex);
                        notePopup.close();
                    }
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Button {
                    text: root.t("Fechar")
                    icon.name: "window-close"
                    onClicked: notePopup.close()
                }
            }
        }
    }
}
