/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    readonly property int maxItemsValue: Plasmoid.configuration.maxItems
    readonly property int headlineLinesValue: Plasmoid.configuration.headlineLines
    readonly property int columnsValue: 1

    function setMaxItems(value) {
        Plasmoid.configuration.maxItems = value;
    }

    function setHeadlineLines(value) {
        Plasmoid.configuration.headlineLines = value;
    }

    function setColumns(value) {
        Plasmoid.configuration.columns = value;
    }

    function agendaSources() {
        var s = Plasmoid.configuration.agendaSources;
        if (typeof s === "undefined" || s === null) {
            return [];
        }
        return s;
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            text: i18n("Exibição")
            textFormat: Text.PlainText
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Máximo total de notícias na lista:")
            }

            QQC2.SpinBox {
                objectName: "globalLimitSpinner"
                from: 1
                to: 200
                editable: true
                value: page.maxItemsValue
                onValueModified: page.setMaxItems(value)
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Linhas da chamada da matéria:")
            }

            QQC2.SpinBox {
                objectName: "headlineLinesSpinner"
                from: 1
                to: 5
                editable: true
                value: page.headlineLinesValue
                onValueModified: page.setHeadlineLines(value)
            }

            QQC2.Label {
                text: i18n("linhas por notícia")
                opacity: 0.6
            }

            Item {
                Layout.fillWidth: true
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Este limite vale para a lista inteira, somando todos os feeds. Para ajustar cada fonte individualmente, use a seção “Feeds de notícias”.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("As alterações são aplicadas imediatamente ao widget.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: i18n("Agenda")
            textFormat: Text.PlainText
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Fontes de calendário (.ics): uma URL do Google/CalDAV (definição “URL pessoal do iCal” / secret) ou um caminho local para um arquivo .ics. Os compromissos de hoje aparecem nas abas Agenda e Resumo.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: agSourceField
                Layout.fillWidth: true
                placeholderText: i18n("URL .ics ou caminho local…")
                onAccepted: addAgButton.clicked()
            }

            QQC2.Button {
                id: addAgButton
                text: i18n("Adicionar")
                icon.name: "list-add-symbolic"
                onClicked: {
                    var u = agSourceField.text.trim();
                    if (!u) return;
                    var list = page.agendaSources();
                    if (list.indexOf(u) !== -1) return;
                    list.push(u);
                    Plasmoid.configuration.agendaSources = list;
                    agSourceField.text = "";
                }
            }
        }

        PlasmaComponents3.Label {
            visible: page.agendaSources().length === 0
            Layout.fillWidth: true
            opacity: 0.5
            text: i18n("Nenhuma fonte adicionada.")
        }

        Repeater {
            model: page.agendaSources()
            delegate: RowLayout {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                spacing: 6
                Layout.topMargin: 2

                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData
                    elide: Text.ElideMiddle
                }

                QQC2.ToolButton {
                    icon.name: "edit-delete-remove-symbolic"
                    Accessible.name: i18n("Remover fonte")
                    onClicked: {
                        var list = page.agendaSources().slice();
                        list.splice(index, 1);
                        Plasmoid.configuration.agendaSources = list;
                    }
                }
            }
        }
    }
}