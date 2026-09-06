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
    signal setDone(int listIndex, bool done)

    property int expandedList: -1
    property int refreshKey: 0
    property bool showHistory: false
    property var activeLists: page.filterLists(page.lists, false)
    property var doneLists: page.filterLists(page.lists, true)
    property int activeCount: page.activeLists.length

    function filterLists(arr, done) {
        var out = [];
        if (!arr) return out;
        for (var i = 0; i < arr.length; i++) {
            if (!!arr[i].done === done) out.push(arr[i]);
        }
        return out;
    }

    function forceRefresh() {
        refreshKey++;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            id: listFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
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

            Repeater {
                model: page.activeLists

                delegate: Rectangle {
                    id: listDelegate
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents3.ToolButton {
                                text: listDelegate.isExpanded ? "\u25B2" : "\u25BC"
                                font.pixelSize: 10
                                contentItem: Text {
                                    text: listDelegate.isExpanded ? "\u25B2" : "\u25BC"
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: page.expandedList = listDelegate.isExpanded ? -1 : listDelegate.index
                            }

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: listDelegate.modelData.name
                                font.bold: true
                                font.pixelSize: 13
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            }

                            PlasmaComponents3.Label {
                                text: listDelegate.modelData.itemsModel.count + " " + root.t("itens")
                                font.pixelSize: 11
                                color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.5, 0.5, 0.5, 1)
                            }

                            PlasmaComponents3.ToolButton {
                                text: "\u2713"
                                font.pixelSize: 12
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: root.t("Finalizar lista")
                                contentItem: Text {
                                    text: "\u2713"
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: page.setDone(listDelegate.index, true)
                            }

                            PlasmaComponents3.ToolButton {
                                text: "+"
                                font.pixelSize: 12
                                contentItem: Text {
                                    text: "+"
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    page.expandedList = listDelegate.index;
                                    Qt.callLater(function() {
                                        if (itemInput) {
                                            var pt = itemInput.mapToItem(listFlick.contentItem, 0, 0);
                                            listFlick.contentY = Math.max(0, pt.y - listFlick.height + itemInput.height + Kirigami.Units.largeSpacing * 2);
                                            itemInput.forceActiveFocus();
                                        }
                                    });
                                }
                            }

                            PlasmaComponents3.ToolButton {
                                text: "\u00D7"
                                font.pixelSize: 14
                                contentItem: Text {
                                    text: "\u00D7"
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: page.removeList(listDelegate.index)
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            property bool isExpanded: listDelegate.isExpanded
                            implicitHeight: expandedContent.active && expandedContent.item ? expandedContent.item.implicitHeight : 0

                            Loader {
                                id: expandedContent
                                anchors.fill: parent
                                active: parent.isExpanded
                                sourceComponent: Component {
                                    ColumnLayout {
                                        width: parent.width
                                        spacing: Kirigami.Units.smallSpacing

                                        Kirigami.Separator {
                                            Layout.fillWidth: true
                                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                            opacity: 0.15
                                        }

                            Flickable {
                                            id: itemScroller
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.min(240, itemCol.implicitHeight)
                                            clip: true
                                            contentHeight: itemCol.height
                                            boundsBehavior: Flickable.StopAtBounds
                                            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                                            ColumnLayout {
                                                id: itemCol
                                                width: parent.width
                                                spacing: Kirigami.Units.smallSpacing

                                                Repeater {
                                                    model: listDelegate.modelData.itemsModel

                                                    delegate: RowLayout {
                                                        id: itemDelegate
                                                        Layout.fillWidth: true
                                                        spacing: Kirigami.Units.smallSpacing

                                                        QQC2.CheckBox {
                                                            checked: model.done
                                                            onToggled: page.toggleItem(listDelegate.index, index)
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
                                                            onClicked: page.removeItem(listDelegate.index, index)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                QQC2.TextField {
                                    id: itemInput
                                    Layout.fillWidth: true
                                    placeholderText: root.t("Novo item...")
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    onAccepted: {
                                        if (text.trim().length > 0) {
                                            page.addItem(listDelegate.index, text.trim());
                                            text = "";
                                        }
                                    }
                                }

                                QQC2.Button {
                                    text: "+"
                                    implicitWidth: 36
                                    onClicked: {
                                        if (itemInput.text.trim().length > 0) {
                                            page.addItem(listDelegate.index, itemInput.text.trim());
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

            Repeater {
                model: page.showHistory ? page.doneLists : []

                delegate: Rectangle {
                    id: doneDelegate
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    radius: Kirigami.Units.largeSpacing
                    color: "transparent"
                    border.width: 1
                    border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
                    implicitHeight: doneCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                    Layout.topMargin: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        id: doneCol
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: doneDelegate.modelData.name
                                font.italic: true
                                font.pixelSize: 12
                                opacity: 0.6
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            }

                            PlasmaComponents3.Label {
                                text: doneDelegate.modelData.itemsModel.count + " " + root.t("itens")
                                font.pixelSize: 11
                                opacity: 0.6
                                color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.5, 0.5, 0.5, 1)
                            }

                            PlasmaComponents3.ToolButton {
                                text: "\u21BA"
                                font.pixelSize: 12
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: root.t("Restaurar lista")
                                contentItem: Text {
                                    text: "\u21BA"
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: page.setDone(page.activeCount + doneDelegate.index, false)
                            }

                            PlasmaComponents3.ToolButton {
                                text: "\u00D7"
                                font.pixelSize: 14
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: root.t("Excluir permanentemente")
                                contentItem: Text {
                                    text: "\u00D7"
                                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: page.removeList(page.activeCount + doneDelegate.index)
                            }
                        }
                    }
                }
            }
        }
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: page.doneLists.length > 0
            text: (page.showHistory ? "\u25BC " : "\u25B6 ") + root.t("Histórico de listas finalizadas") + " (" + page.doneLists.length + ")"
            onClicked: {
                page.showHistory = !page.showHistory;
                if (page.showHistory) {
                    Qt.callLater(function() {
                        listFlick.contentY = Math.max(0, listFlick.contentHeight - listFlick.height);
                    });
                }
            }
        }
    }
}
