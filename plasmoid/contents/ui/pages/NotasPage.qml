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
    property int pendingNoteIndex: -1
    property string draftNoteText: ""

    // Mantém o cursor visível enquanto digita (caixa e barra acompanham).
    function followCursor(flick, edit) {
        var cr = edit.cursorRectangle;
        if (cr.y < flick.contentY) {
            flick.contentY = cr.y;
        } else if (cr.y + cr.height > flick.contentY + flick.height) {
            flick.contentY = cr.y + cr.height - flick.height;
        }
    }

    // Espaço reservado para a barra de rolagem vertical (no QQC2 ela é
    // desenhada por cima do conteúdo): o grid de notas não fica sob a barra.
    readonly property real scrollGutter: notasScrollBar.visible ? notasScrollBar.width : 0

    // Debounce: só grava a nota 400ms depois da última tecla.
    Timer {
        id: noteSaveTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (page.pendingNoteIndex >= 0
                    && notePopup.visible
                    && notePopup.currentIndex === page.pendingNoteIndex) {
                page.updateNoteText(page.pendingNoteIndex, noteTextField.text);
            }
            page.pendingNoteIndex = -1;
        }
    }

    Flickable {
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: mainCol.implicitHeight + Kirigami.Units.largeSpacing * 2

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            id: notasScrollBar
            policy: QQC2.ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: mainCol
            width: parent.width - page.scrollGutter - Kirigami.Units.largeSpacing
            anchors.top: parent.top
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing
            spacing: 0

            PageHeader {
                title: i18n("Your notes, thoughts, or anything you need to write down...")
                margins: 0
            }

            // Entrada para nova nota
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: newNoteCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.largeSpacing
                color: root.accentSoft
                border.width: 1
                border.color: Qt.alpha(root.accentMain, 0.18)

                ColumnLayout {
                    id: newNoteCol
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    // Entrada para nova nota: multi-linha com barra de rolagem própria
                    Rectangle {
                        id: newNoteBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(root.textMain, 0.2)
                        clip: true

                        readonly property bool newNeedsScroll: newNoteEdit.implicitHeight > newNoteFlick.height

                        Text {
                            visible: newNoteEdit.text === ""
                            z: -1
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 6
                            text: i18n("Write your note…")
                            font.pixelSize: 13
                            color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.35, 0.35, 0.35, 1)
                        }

                        Flickable {
                            id: newNoteFlick
                            anchors.fill: parent
                            anchors.rightMargin: newNoteBox.newNeedsScroll ? 7 : 1
                            clip: true
                            contentWidth: width
                            contentHeight: newNoteEdit.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: newNoteEdit
                                width: newNoteFlick.width + 1
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                text: page.draftNoteText
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                selectionColor: root.accentMain
                                selectedTextColor: "white"
                                selectByMouse: true
                                persistentSelection: true
                                padding: 6
                                onTextChanged: page.draftNoteText = text
                                onCursorRectangleChanged: page.followCursor(newNoteFlick, newNoteEdit)
                                Keys.onReturnPressed: {
                                    if (!(event.modifiers & Qt.ShiftModifier)) {
                                        addNoteAction.trigger();
                                        event.accepted = true;
                                    }
                                }
                                Keys.onEnterPressed: {
                                    if (!(event.modifiers & Qt.ShiftModifier)) {
                                        addNoteAction.trigger();
                                        event.accepted = true;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: newNoteBox.newNeedsScroll
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            width: 5
                            radius: 2.5
                            color: "transparent"

                            Rectangle {
                                id: newNoteHandle
                                width: 5
                                radius: 2.5
                                color: root.isDarkTheme ? Qt.rgba(0.5, 0.8, 1, 0.6) : Qt.rgba(0.15, 0.5, 0.85, 0.55)
                                height: Math.max(16, newNoteTrack.height * newNoteFlick.height / Math.max(1, newNoteEdit.implicitHeight))
                                y: newNoteTrack.height > newNoteHandle.height
                                   ? (newNoteEdit.implicitHeight > newNoteFlick.height
                                      ? newNoteFlick.contentY / (newNoteEdit.implicitHeight - newNoteFlick.height)
                                        * (newNoteTrack.height - newNoteHandle.height)
                                      : 0)
                                   : 0
                            }
                        }

                        MouseArea {
                            id: newNoteTrack
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            width: 8
                            visible: newNoteBox.newNeedsScroll
                            cursorShape: Qt.PointingHandCursor
                            onPressed: (mouse) => newNoteGrab(mouse.y)
                            onPositionChanged: (mouse) => newNoteGrab(mouse.y)
                            function newNoteGrab(ty) {
                                var range = Math.max(1, newNoteEdit.implicitHeight - newNoteFlick.height);
                                var trav = Math.max(1, newNoteTrack.height - newNoteHandle.height);
                                newNoteFlick.contentY = Math.max(0, Math.min(range, (ty - newNoteHandle.height / 2) / trav * range));
                            }
                        }
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
                                             ? root.accentMain
                                             : Qt.alpha(root.textMain, 0.2)

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
                            text: i18n("Add")
                            icon.name: "list-add"
                            enabled: page.draftNoteText.trim() !== ""
                            onClicked: {
                                page.addNote(page.draftNoteText.trim(), page.selectedColor);
                                page.draftNoteText = "";
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

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104

                        // Sombra suave atrás do post-it (compensada para baixo/direita).
                        Rectangle {
                            id: noteShadow
                            anchors.fill: parent
                            anchors.rightMargin: -3
                            anchors.bottomMargin: -3
                            radius: Kirigami.Units.smallSpacing
                            color: root.isDarkTheme ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(0, 0, 0, 0.12)
                        }

                        Rectangle {
                            id: noteCard
                            anchors.fill: parent
                            anchors.leftMargin: 0
                            anchors.topMargin: 0
                            anchors.rightMargin: 3
                            anchors.bottomMargin: 3
                            radius: Kirigami.Units.smallSpacing
                            color: (page.notes[index] && page.notes[index].color) || page.noteColors[0]
                            border.width: 1
                            border.color: Qt.alpha(root.textMain, 0.12)

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
            }

            Kirigami.PlaceholderMessage {
                visible: page.notes.length === 0
                Layout.fillWidth: true
                text: i18n("No notes yet.\nWrite one above to get started.")
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

// Texto da nota (editável), com barra de rolagem própria e cursor
                // sempre visível enquanto se digita.
                Rectangle {
                    id: noteEditBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: Kirigami.Units.smallSpacing
                    color: notePopup.currentColor
                    border.width: 1
                    border.color: Qt.alpha(root.textMain, 0.1)
                    clip: true

                    readonly property bool noteNeedsScroll: noteTextField.implicitHeight > noteFlick.height

                    Flickable {
                        id: noteFlick
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        anchors.rightMargin: noteEditBox.noteNeedsScroll
                                              ? Kirigami.Units.largeSpacing + 7 : Kirigami.Units.largeSpacing
                        clip: true
                        contentWidth: width
                        contentHeight: noteTextField.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: noteTextField
                            width: noteFlick.width + 1
                            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                            text: notePopup.currentText
                            font.pixelSize: 14
                            color: "#1a1a1a"
                            selectionColor: root.accentMain
                            selectedTextColor: "white"
                            selectByMouse: true
                            persistentSelection: true
                            padding: 1
                            onTextChanged: {
                                if (notePopup.currentIndex >= 0) {
                                    page.pendingNoteIndex = notePopup.currentIndex;
                                    noteSaveTimer.restart();
                                }
                            }
                            onCursorRectangleChanged: page.followCursor(noteFlick, noteTextField)
                        }
                    }

                    // Barra de rolagem vertical (só quando o texto extrapola)
                    Rectangle {
                        visible: noteEditBox.noteNeedsScroll
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: 5
                        radius: 2.5
                        color: "transparent"

                        Rectangle {
                            id: noteHandle
                            width: 5
                            radius: 2.5
                            color: Qt.rgba(0.15, 0.45, 0.85, 0.7)
                            height: Math.max(18, noteTrack.height * noteFlick.height / Math.max(1, noteTextField.implicitHeight))
                            y: noteTrack.height > noteHandle.height
                               ? (noteTextField.implicitHeight > noteFlick.height
                                  ? noteFlick.contentY / (noteTextField.implicitHeight - noteFlick.height)
                                    * (noteTrack.height - noteHandle.height)
                                  : 0)
                               : 0
                        }
                    }

                    MouseArea {
                        id: noteTrack
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: 8
                        visible: noteEditBox.noteNeedsScroll
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => noteGrab(mouse.y)
                        onPositionChanged: (mouse) => noteGrab(mouse.y)
                        function noteGrab(ty) {
                            var range = Math.max(1, noteTextField.implicitHeight - noteFlick.height);
                            var trav = Math.max(1, noteTrack.height - noteHandle.height);
                            noteFlick.contentY = Math.max(0, Math.min(range, (ty - noteHandle.height / 2) / trav * range));
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
                                     ? root.accentMain
                                     : Qt.alpha(root.textMain, 0.2)

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
                    text: i18n("Delete")
                    icon.name: "edit-delete"
                    onClicked: {
                        page.removeNote(notePopup.currentIndex);
                        notePopup.close();
                    }
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Button {
                    text: i18n("Close")
                    icon.name: "window-close"
                    onClicked: notePopup.close()
                }
            }
        }
    }
}
