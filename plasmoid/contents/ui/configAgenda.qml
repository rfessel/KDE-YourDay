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
import "js/i18n.js" as I18n

KCM.SimpleKCM {
    id: page

    property string _lang: Plasmoid.configuration.language || ""

    function t(text) {
        if (!_lang) return text;
        return I18n.translate(text, _lang);
    }

    function agendaSources() {
        var s = Plasmoid.configuration.agendaSources;
        if (typeof s === "undefined" || s === null) return [];
        return s;
    }

    function isAlreadyAdded(path) {
        var list = page.agendaSources();
        for (var i = 0; i < list.length; i++) {
            if (list[i] === path) return true;
        }
        return false;
    }

    FileDialog {
        id: fileDialog
        title: t("Selecionar arquivo .ics")
        nameFilters: [ t("Calendário (*.ics)"), t("Todos os arquivos (*)") ]
        onAccepted: {
            var u = fileDialog.fileUrl.toString().replace("file://", "");
            if (u && !page.isAlreadyAdded(u)) {
                var list = page.agendaSources();
                list.push(u);
                Plasmoid.configuration.agendaSources = list;
            }
        }
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: t("Adicione fontes de calendário (.ics) para ver seus compromissos nas abas Agenda e Resumo.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.Heading {
            level: 4
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: t("Google Calendar")
            textFormat: Text.PlainText
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: t("1. Abra o Google Calendar no navegador\n2. Clique em Configurações (engrenagem)\n3. Vá em Configurações do calendário\n4. Selecione o calendário desejado\n5. Role até Integração de calendário\n6. Copie o link Endereço público do iCal")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: t("Formato:\nhttps://calendar.google.com/calendar/ical/seuemail%40gmail.com/public/basic.ics")
            opacity: 0.5
            font.pixelSize: 10
            font.italic: true
            wrapMode: Text.Wrap
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.Heading {
            level: 4
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: t("Arquivo local")
            textFormat: Text.PlainText
        }

        QQC2.Button {
            text: t("Selecionar arquivo .ics...")
            icon.name: "document-open"
            onClicked: fileDialog.open()
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.Heading {
            level: 4
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: t("Adicionar URL ou caminho")
            textFormat: Text.PlainText
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: agSourceField
                Layout.fillWidth: true
                placeholderText: t("URL iCal ou caminho local...")
                onAccepted: addAgButton.clicked()
            }

            QQC2.Button {
                id: addAgButton
                text: t("Adicionar")
                icon.name: "list-add"
                onClicked: {
                    var u = agSourceField.text.trim();
                    if (!u) return;
                    if (page.isAlreadyAdded(u)) return;
                    var list = page.agendaSources();
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
            text: t("Nenhuma fonte adicionada.")
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
                    icon.name: "list-remove"
                    Accessible.name: t("Remover fonte")
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
