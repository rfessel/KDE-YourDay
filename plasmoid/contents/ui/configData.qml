/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later

    Configuração de Dados: backup e restauração completos em um JSON
    (tarefas, notas, listas, eventos locais, cidades e feeds).
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string exportContent: ""
    property string statusText: ""
    property bool statusIsError: false

    // Reúne todos os dados persistidos do widget em um único objeto.
    function collectData() {
        var cfg = Plasmoid.configuration;
        return {
            app: "kde.yourday",
            version: 1,
            exportedAt: Date.now(),
            data: {
                todos: cfg.todos || [],
                completedTodos: cfg.completedTodos || [],
                notes: cfg.notes || [],
                lists: cfg.lists || [],
                localEvents: cfg.localEvents || [],
                feeds: cfg.feeds || [],
                agendaSources: cfg.agendaSources || [],
                weatherCity: cfg.weatherCity || "",
                weatherLatitude: cfg.weatherLatitude || 0,
                weatherLongitude: cfg.weatherLongitude || 0,
                weatherCities: cfg.weatherCities || ""
            }
        };
    }

    // Escreve um arquivo local via XHR PUT (KIO no Qt QML do Plasma) —
    // mesmo mecanismo da exportação TXT/CSV das Listas.
    function writeFile(url, content) {
        var xhr = new XMLHttpRequest();
        xhr.open("PUT", url, false);
        xhr.send(content);
        return xhr.status === 0;
    }

    // Lê um arquivo local via XHR GET (mesmo mecanismo dos .ics locais).
    function readFile(url, onDone) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            // file:// responde com status 0 quando OK neste contexto.
            if (xhr.status >= 200 && xhr.status < 300 || xhr.status === 0) {
                if (onDone) onDone(xhr.responseText);
            } else if (onDone) {
                onDone(null);
            }
        };
        xhr.onerror = function() { if (onDone) onDone(null); };
        xhr.send(null);
    }

    function setStatus(msg, isError) {
        page.statusText = msg;
        page.statusIsError = !!isError;
    }

    function applyImport(data) {
        var cfg = Plasmoid.configuration;
        // Tudo o que o widget persistir pode ser restaurado; chaves ausentes
        // no backup mantêm o valor atual.
        if (data.todos !== undefined) cfg.todos = data.todos;
        if (data.completedTodos !== undefined) cfg.completedTodos = data.completedTodos;
        if (data.notes !== undefined) cfg.notes = data.notes;
        if (data.lists !== undefined) cfg.lists = data.lists;
        if (data.localEvents !== undefined) cfg.localEvents = data.localEvents;
        if (data.feeds !== undefined) cfg.feeds = data.feeds;
        if (data.agendaSources !== undefined) cfg.agendaSources = data.agendaSources;
        if (data.weatherCity !== undefined) cfg.weatherCity = data.weatherCity;
        if (data.weatherLatitude !== undefined) cfg.weatherLatitude = data.weatherLatitude;
        if (data.weatherLongitude !== undefined) cfg.weatherLongitude = data.weatherLongitude;
        if (data.weatherCities !== undefined) cfg.weatherCities = data.weatherCities;
    }

    function startImport(url) {
        page.setStatus(i18n("Reading file..."), false);
        page.readFile(url, function(text) {
            var parsed = null;
            if (text) {
                try {
                    parsed = JSON.parse(text);
                } catch (e) {
                    parsed = null;
                }
            }
            if (!parsed || parsed.app !== "kde.yourday" || !parsed.data) {
                page.setStatus(i18n("Invalid backup file: expected a JSON exported by this widget."), true);
                return;
            }
            page.applyImport(parsed.data);
            page.setStatus(i18n("Backup restored. The widget reloads the data right away."), false);
        });
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            text: i18n("Backup & restore")
            textFormat: Text.PlainText
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Export all widget data (tasks, notes, lists, local events, feeds and cities) to a single JSON file, and later restore it on this or another computer.")
            opacity: 0.7
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: i18n("Export backup (JSON)")
                icon.name: "document-export"
                onClicked: {
                    page.exportContent = JSON.stringify(page.collectData(), null, 2);
                    exportDialog.open();
                }
            }

            QQC2.Button {
                text: i18n("Import backup (JSON)")
                icon.name: "document-import"
                onClicked: importDialog.open()
            }

            Item { Layout.fillWidth: true }
        }

        QQC2.Label {
            id: statusLabel
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: page.statusText !== ""
            color: page.statusIsError
                   ? Kirigami.Theme.negativeTextColor
                   : Kirigami.Theme.positiveTextColor
            font.italic: true
            font.pixelSize: 11
            wrapMode: Text.Wrap
            text: page.statusText
        }

        FileDialog {
            id: exportDialog
            title: i18n("Save backup")
            fileMode: FileDialog.SaveFile
            nameFilters: [ i18n("JSON file (*.json)") ]
            onAccepted: {
                if (page.writeFile(exportDialog.selectedFile, page.exportContent)) {
                    page.setStatus(i18n("Backup exported."), false);
                } else {
                    page.setStatus(i18n("Failed to write the file."), true);
                }
            }
            onRejected: page.statusText = ""
        }

        FileDialog {
            id: importDialog
            title: i18n("Open backup")
            fileMode: FileDialog.OpenFile
            nameFilters: [ i18n("JSON file (*.json)") ]
            onAccepted: page.startImport(importDialog.selectedFile)
            onRejected: page.statusText = ""
        }
    }
}