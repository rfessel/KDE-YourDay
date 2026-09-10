/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Página de Listas: listas gerais e de compras.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls as QQC2

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property var lists
    signal addList(string name)
    signal removeList(string listId)
    signal addItem(string listId, string text)
    signal removeItem(string listId, string itemId)
    signal toggleItem(string listId, string itemId)
    signal setDone(string listId, bool done)

    property int expandedList: -1
    property bool showHistory: false
    property var activeLists: page.filterLists(page.lists, false)
    property var doneLists: page.filterLists(page.lists, true)

    function filterLists(arr, done) {
        var out = [];
        if (!arr) return out;
        for (var i = 0; i < arr.length; i++) {
            if (!!arr[i].done === done) out.push(arr[i]);
        }
        return out;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            title: i18n("Your lists, shopping, or anything you need to organize...")
            margins: Kirigami.Units.largeSpacing
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: newListField
                Layout.fillWidth: true
                placeholderText: i18n("New list name...")
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

        // Um único ListView: cada lista é um item que cresce quando
        // expandida, sem Flickable aninhado (scroll sempre solto).
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // Espaço da barra de rolagem para ela não cobrir os cards.
            readonly property real scrollGutter: listScrollBar.visible ? listScrollBar.width : 0
            model: page.activeLists
            spacing: Kirigami.Units.smallSpacing
            cacheBuffer: 400
            delegate: listDelegate
            ScrollBar.vertical: ScrollBar {
                id: listScrollBar
                policy: ScrollBar.AsNeeded
            }
        }

        PlasmaComponents3.Button {
            id: histToggleBtn
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: page.doneLists.length > 0
            text: (page.showHistory ? "\u25BC " : "\u25B6 ") + i18n("Completed lists history") + " (" + page.doneLists.length + ")"
            onClicked: page.showHistory = !page.showHistory
        }
    }

    Component {
        id: listDelegate
        Rectangle {
            id: listCard
            required property var modelData
            required property int index

            width: ListView.view.width - ListView.view.scrollGutter - Kirigami.Units.largeSpacing
            radius: Kirigami.Units.largeSpacing
            color: root.isDarkTheme ? Qt.rgba(0.25, 0.25, 0.25, 1) : Qt.rgba(0.95, 0.95, 0.95, 1)
            border.width: 1
            border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
            implicitHeight: listCol.implicitHeight + Kirigami.Units.largeSpacing * 2

            property bool isExpanded: page.expandedList === index

            ColumnLayout {
                id: listCol
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.ToolButton {
                        text: listCard.isExpanded ? "\u25B2" : "\u25BC"
                        font.pixelSize: 10
                        contentItem: Text {
                            text: listCard.isExpanded ? "\u25B2" : "\u25BC"
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: page.expandedList = listCard.isExpanded ? -1 : listCard.index
                    }

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: listCard.modelData.name
                        font.bold: true
                        font.pixelSize: 13
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    }

                    PlasmaComponents3.Label {
                        text: listCard.modelData.itemsModel.count + " " + i18n("items")
                        font.pixelSize: 11
                        color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.5, 0.5, 0.5, 1)
                    }

                    PlasmaComponents3.ToolButton {
                        text: "\u2713"
                        font.pixelSize: 12
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Complete list")
                        contentItem: Text {
                            text: "\u2713"
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: page.setDone(listCard.modelData.id, true)
                    }

                    PlasmaComponents3.ToolButton {
                        text: "+"
                        font.pixelSize: 12
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Add item")
                        contentItem: Text {
                            text: "+"
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            page.expandedList = listCard.index;
                            Qt.callLater(function() {
                                listView.positionViewAtIndex(listCard.index, ListView.Contain);
                            });
                        }
                    }

                    PlasmaComponents3.ToolButton {
                        text: "\u00D7"
                        font.pixelSize: 14
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Delete list")
                        contentItem: Text {
                            text: "\u00D7"
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: page.removeList(listCard.modelData.id)
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: expandedContent.active && expandedContent.item ? expandedContent.item.implicitHeight : 0

                    Loader {
                        id: expandedContent
                        anchors.fill: parent
                        active: listCard.isExpanded
                        sourceComponent: Component {
                            ColumnLayout {
                                width: parent.width
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Separator {
                                    Layout.fillWidth: true
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    opacity: 0.15
                                }

                                Repeater {
                                    model: listCard.modelData.itemsModel
                                    delegate: RowLayout {
                                        id: itemDelegate
                                        Layout.fillWidth: true
                                        spacing: Kirigami.Units.smallSpacing

                                        QQC2.CheckBox {
                                            checked: model.done
                                            onToggled: page.toggleItem(listCard.modelData.id, model.id)
                                        }

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            text: model.text
                                            font.pixelSize: 12
                                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                            opacity: model.done ? 0.5 : 1.0
                                            font.italic: model.done
                                        }

                                        PlasmaComponents3.ToolButton {
                                            text: "\u00D7"
                                            font.pixelSize: 10
                                            contentItem: Text {
                                                text: "\u00D7"
                                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                                font.pixelSize: 10
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: page.removeItem(listCard.modelData.id, model.id)
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    QQC2.TextField {
                                        id: itemInput
                                        Layout.fillWidth: true
                                        placeholderText: i18n("New item...")
                                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                        onAccepted: {
                                            if (text.trim().length > 0) {
                                                page.addItem(listCard.modelData.id, text.trim());
                                                text = "";
                                            }
                                        }
                                    }

                                    QQC2.Button {
                                        text: "+"
                                        implicitWidth: 36
                                        onClicked: {
                                            if (itemInput.text.trim().length > 0) {
                                                page.addItem(listCard.modelData.id, itemInput.text.trim());
                                                itemInput.text = "";
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

    // Popup de histórico de listas finalizadas (abre ao pressionar o botão)
    Rectangle {
        visible: page.showHistory && page.doneLists.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        anchors.bottom: parent.bottom
        anchors.bottomMargin: histToggleBtn.height + Kirigami.Units.smallSpacing * 2
        height: Math.min(340, donePopupCol.implicitHeight + Kirigami.Units.largeSpacing * 2)
        radius: Kirigami.Units.largeSpacing
        color: (root.isDarkTheme ? Qt.rgba(0.22, 0.22, 0.22, 1) : Qt.rgba(0.95, 0.95, 0.95, 1))
        border.width: 1
        border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.15)
        z: 10

        ColumnLayout {
            id: donePopupCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaExtras.Heading {
                    level: 4
                    color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                    text: i18n("Completed (%1)", page.doneLists.length)
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

            ListView {
                id: doneList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(230, doneList.contentHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: page.doneLists
                spacing: Kirigami.Units.smallSpacing
                delegate: doneRowDelegate
                readonly property real scrollGutter: doneScrollBar.visible ? doneScrollBar.width : 0
                ScrollBar.vertical: ScrollBar {
                    id: doneScrollBar
                    policy: ScrollBar.AsNeeded
                }
            }
        }
    }

    Component {
        id: doneRowDelegate
        Rectangle {
            required property var modelData
            width: ListView.view.width - ListView.view.scrollGutter
            implicitHeight: Math.max(32, doneRowLay.implicitHeight + Kirigami.Units.smallSpacing * 2)
            radius: Kirigami.Units.smallSpacing
            color: "transparent"
            border.width: 1
            border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)

            RowLayout {
                id: doneRowLay
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.italic: true
                        font.pixelSize: 11
                        opacity: 0.7
                        elide: Text.ElideRight
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    }

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: modelData.itemsModel.count + " " + i18n("items")
                        font.pixelSize: 10
                        opacity: 0.6
                        elide: Text.ElideRight
                        color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.5, 0.5, 0.5, 1)
                    }
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "edit-undo"
                    implicitWidth: 28
                    implicitHeight: 28
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18n("Restore list")
                    onClicked: page.setDone(modelData.id, false)
                }

                PlasmaComponents3.ToolButton {
                    text: "\u00D7"
                    implicitWidth: 28
                    implicitHeight: 28
                    Accessible.name: i18n("Delete permanently")
                    onClicked: page.removeList(modelData.id)
                }
            }
        }
    }
}