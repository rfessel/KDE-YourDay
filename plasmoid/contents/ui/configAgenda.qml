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


    // Estado de autenticação Google
    property bool gcalAuthenticated: false
    property var gcalCalendars: []
    property string gcalStatus: ""

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

    function loadGoogleAuth() {
        var scriptUrl = Plasmoid.configuration.gcalClientId;
        if (scriptUrl && scriptUrl.indexOf("script.google.com") !== -1) {
            page.gcalAuthenticated = true;
            page.gcalStatus = i18n("Conectado ao Google Calendar");
            loadGoogleCalendarsFromScript();
        }
    }

    function startGoogleAuth() {
        var scriptUrl = agClientIdField.text.trim();
        if (!scriptUrl) {
            page.gcalStatus = i18n("Informe a URL do Apps Script");
            return;
        }

        // Garante que a URL termina com /exec
        if (!scriptUrl.endsWith("/exec")) {
            if (scriptUrl.endsWith("/")) {
                scriptUrl += "exec";
            } else {
                scriptUrl += "/exec";
            }
            agClientIdField.text = scriptUrl;
        }

        Plasmoid.configuration.gcalClientId = scriptUrl;
        page.gcalStatus = i18n("Testando conexão...");

        // Testa a conexão
        var testUrl = scriptUrl + "?action=list&timeMin=" + encodeURIComponent(new Date().toISOString()) + "&timeMax=" + encodeURIComponent(new Date(Date.now() + 86400000).toISOString());

        console.log("[yourday] Testando URL:", testUrl);

        var xhr = new XMLHttpRequest();
        xhr.open("GET", testUrl, true);
        xhr.timeout = 30000;
        xhr.onreadystatechange = function() {
            console.log("[yourday] XHR state:", xhr.readyState, "status:", xhr.status);
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        console.log("[yourday] Resposta:", JSON.stringify(data).substring(0, 200));
                        if (Array.isArray(data)) {
                            page.gcalAuthenticated = true;
                            page.gcalStatus = i18n("Conectado ao Google Calendar");
                            loadGoogleCalendarsFromScript();
                        } else {
                            page.gcalStatus = i18n("Resposta inválida: ") + JSON.stringify(data).substring(0, 100);
                        }
                    } catch (e) {
                        page.gcalStatus = i18n("Erro ao parsear: ") + e.message;
                        console.log("[yourday] Parse error:", e.message, "Response:", xhr.responseText.substring(0, 200));
                    }
                } else {
                    page.gcalStatus = i18n("Erro HTTP: ") + xhr.status;
                    console.log("[yourday] HTTP Error:", xhr.status, xhr.responseText.substring(0, 200));
                }
            }
        };
        xhr.onerror = function() {
            page.gcalStatus = i18n("Erro de conexão. Verifique a URL.");
            console.log("[yourday] XHR error");
        };
        xhr.ontimeout = function() {
            page.gcalStatus = i18n("Tempo esgotado. Verifique a URL e a permissão de acesso.");
            console.log("[yourday] XHR timeout");
        };
        xhr.send(null);
    }

    function loadGoogleCalendarsFromScript() {
        var scriptUrl = Plasmoid.configuration.gcalClientId;
        if (!scriptUrl) return;
        var url = scriptUrl + "?action=listCalendars";

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.timeout = 15000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    if (Array.isArray(data) && data.length > 0) {
                        page.gcalCalendars = data.map(function(cal) {
                            return { id: cal.id, summary: cal.name, primary: cal.isDefault, color: cal.color || "#4285f4" };
                        });
                        var savedColors = {};
                        try { savedColors = JSON.parse(Plasmoid.configuration.gcalCalendarColors || "{}"); } catch(e) {}
                        for (var i = 0; i < data.length; i++) {
                            if (!savedColors[data[i].id]) {
                                savedColors[data[i].id] = data[i].color || "#4285f4";
                            }
                        }
                        Plasmoid.configuration.gcalCalendarColors = JSON.stringify(savedColors);
                        var selected = (Plasmoid.configuration.gcalSelectedCalendars || "").split(",").filter(function(s) { return s; });
                        if (selected.length === 0) {
                            var defaultCal = data.find(function(c) { return c.isDefault; });
                            var calId = defaultCal ? defaultCal.id : data[0].id;
                            Plasmoid.configuration.gcalSelectedCalendars = calId;
                            Plasmoid.configuration.gcalCalendarId = calId;
                        }
                    }
                } catch (e) {
                    console.warn("[yourday] erro parsear calendários:", e);
                }
            }
        };
        xhr.onerror = function() {
            console.warn("[yourday] erro rede ao listar calendários");
        };
        xhr.send(null);
    }

    function disconnectGoogle() {
        Plasmoid.configuration.gcalClientId = "";
        Plasmoid.configuration.gcalCalendarId = "";
        Plasmoid.configuration.gcalSelectedCalendars = "";
        page.gcalAuthenticated = false;
        page.gcalCalendars = [];
        page.gcalStatus = i18n("Desconectado");
    }

    FileDialog {
        id: fileDialog
        title: i18n("Selecionar arquivo .ics")
        nameFilters: [ i18n("Calendário (*.ics)"), i18n("Todos os arquivos (*)") ]
        onAccepted: {
            var u = fileDialog.fileUrl.toString().replace("file://", "");
            if (u && !page.isAlreadyAdded(u)) {
                var list = page.agendaSources();
                list.push(u);
                Plasmoid.configuration.agendaSources = list;
            }
        }
    }

    Component.onCompleted: loadGoogleAuth()

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        // ---- Google Calendar API (sync bidirecional) ----
        Kirigami.Heading {
            level: 4
            Layout.fillWidth: true
            text: i18n("Google Calendar API (sincronização)")
            textFormat: Text.PlainText
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Para sincronizar eventos, crie um projeto no Google Cloud Console e ative a API do Google Calendar.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("1. Abra script.google.com\n2. Crie um novo projeto\n3. Cole o código abaixo\n4. No menu lateral, clique em \"Serviços\" (+)\n5. Busque \"Google Calendar API\" e ative\n6. Salve e publique como Web App\n7. Copie a URL gerada")
            opacity: 0.5
            font.pixelSize: 10
            font.italic: true
            wrapMode: Text.Wrap
        }

        QQC2.Button {
            text: i18n("Ver código do Apps Script")
            icon.name: "document-properties"
            onClicked: scriptCodeDialog.open()
        }

        QQC2.Dialog {
            id: scriptCodeDialog
            title: i18n("Código do Apps Script")
            modal: true
            standardButtons: QQC2.Dialog.Close
            width: 500
            height: 400

            QQC2.ScrollView {
                anchors.fill: parent
                QQC2.TextArea {
                    id: scriptCodeArea
                    readOnly: true
                    text: 'function doGet(e) {\n  var action = e.parameter.action;\n  \n  if (action === "listCalendars") {\n    var calendars = Calendar.CalendarList.list();\n    var result = calendars.items.map(function(cal) {\n      return {\n        id: cal.id,\n        name: cal.summary,\n        isDefault: cal.primary || false,\n        color: cal.backgroundColor || "#4285f4"\n      };\n    });\n    return ContentService.createTextOutput(JSON.stringify(result)).setMimeType(ContentService.MimeType.JSON);\n  }\n  \n  var calendarId = e.parameter.calendarId || "primary";\n  \n  if (action === "list") {\n    var events = Calendar.Events.list(calendarId, {\n      timeMin: e.parameter.timeMin,\n      timeMax: e.parameter.timeMax,\n      singleEvents: true,\n      orderBy: "startTime"\n    });\n    var result = (events.items || []).map(function(ev) {\n      var start, end, allDay = false;\n      if (ev.start.date) {\n        start = new Date(ev.start.date).getTime();\n        end = new Date(ev.end.date).getTime();\n        allDay = true;\n      } else {\n        start = new Date(ev.start.dateTime).getTime();\n        end = new Date(ev.end.dateTime).getTime();\n      }\n      return {\n        id: ev.id,\n        title: ev.summary || "(sem título)",\n        start: start,\n        end: end,\n        allDay: allDay,\n        description: ev.description || "",\n        location: ev.location || ""\n      };\n    });\n    return ContentService.createTextOutput(JSON.stringify(result)).setMimeType(ContentService.MimeType.JSON);\n  }\n  \n  if (action === "create") {\n    var event = {\n      summary: e.parameter.title,\n      description: e.parameter.description || "",\n      location: e.parameter.location || ""\n    };\n    if (e.parameter.allDay === "true") {\n      var startDate = new Date(Number(e.parameter.start));\n      var endDate = new Date(Number(e.parameter.end));\n      event.start = { date: startDate.toISOString().split("T")[0] };\n      event.end = { date: endDate.toISOString().split("T")[0] };\n    } else {\n      event.start = { dateTime: new Date(Number(e.parameter.start)).toISOString() };\n      event.end = { dateTime: new Date(Number(e.parameter.end)).toISOString() };\n    }\n    var created = Calendar.Events.insert(event, calendarId);\n    return ContentService.createTextOutput(JSON.stringify({id: created.id})).setMimeType(ContentService.MimeType.JSON);\n  }\n  \n  if (action === "delete") {\n    Calendar.Events.remove(calendarId, e.parameter.id);\n    return ContentService.createTextOutput(JSON.stringify({ok: true})).setMimeType(ContentService.MimeType.JSON);\n  }\n  \n  return ContentService.createTextOutput(JSON.stringify({error: "unknown action"})).setMimeType(ContentService.MimeType.JSON);\n}'
                    wrapMode: Text.Wrap
                    font.pixelSize: 11
                    font.family: "monospace"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                text: i18n("Apps Script URL:")
                font.pixelSize: 12
            }
            QQC2.TextField {
                id: agClientIdField
                Layout.fillWidth: true
                text: Plasmoid.configuration.gcalClientId || ""
                placeholderText: "https://script.google.com/macros/s/xxx/exec"
                font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: page.gcalAuthenticated ? i18n("Conectado") : i18n("Conectar")
                icon.name: page.gcalAuthenticated ? "dialog-ok-apply" : "preferences-system-network"
                enabled: !page.gcalAuthenticated
                onClicked: startGoogleAuth()
            }

            QQC2.Button {
                text: i18n("Desconectar")
                icon.name: "dialog-cancel"
                visible: page.gcalAuthenticated
                onClicked: disconnectGoogle()
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: page.gcalStatus
                font.pixelSize: 10
                opacity: 0.7
                wrapMode: Text.Wrap
            }
        }

        // Status da conexão
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: page.gcalAuthenticated

            Kirigami.Icon {
                source: "dialog-ok-apply"
                width: 16
                height: 16
            }
            QQC2.Label {
                text: i18n("Conectado ao Google Calendar")
                font.pixelSize: 12
                font.bold: true
                color: Kirigami.Theme.positiveTextColor
            }
        }

        // Seleção de calendários (multi-seleção)
        ColumnLayout {
            Layout.fillWidth: true
            visible: page.gcalAuthenticated && page.gcalCalendars.length > 0
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Calendários para sincronizar:")
                font.pixelSize: 12
                font.bold: true
            }

            Repeater {
                model: page.gcalCalendars
                delegate: Item {
                    required property var model
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: rowLayout.implicitHeight

                    RowLayout {
                        id: rowLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.CheckBox {
                            text: model.summary + (model.primary ? " (padrão)" : "")
                            Layout.fillWidth: true
                            checked: {
                                var selected = (Plasmoid.configuration.gcalSelectedCalendars || "").split(",").filter(function(s) { return s; });
                                return selected.indexOf(model.id) !== -1;
                            }
                            onToggled: {
                                var selected = (Plasmoid.configuration.gcalSelectedCalendars || "").split(",").filter(function(s) { return s; });
                                var idx = selected.indexOf(model.id);
                                if (checked && idx === -1) {
                                    selected.push(model.id);
                                } else if (!checked && idx !== -1) {
                                    selected.splice(idx, 1);
                                }
                                Plasmoid.configuration.gcalSelectedCalendars = selected.join(",");
                                if (selected.length > 0) {
                                    Plasmoid.configuration.gcalCalendarId = selected[0];
                                }
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            property string calColor: {
                                var savedColors = {};
                                try { savedColors = JSON.parse(Plasmoid.configuration.gcalCalendarColors || "{}"); } catch(e) {}
                                return savedColors[model.id] || model.color || "#4285f4";
                            }
                            color: calColor
                            border.width: 1
                            border.color: Qt.darker(calColor, 1.3)

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var palette = ["#4285f4","#ea4335","#fbbc04","#34a853","#ff6d01","#46bdc6","#7baaf7","#f07b72","#fcd04a","#57bb6a","#f4511e","#039be5","#616161","#8e24aa","#e67c73","#f6bf26","#33b679","#0b8043","#3f51b5","#d50000"];
                                    var savedColors = {};
                                    try { savedColors = JSON.parse(Plasmoid.configuration.gcalCalendarColors || "{}"); } catch(e) {}
                                    var cur = calColor;
                                    var idx = -1;
                                    for (var i = 0; i < palette.length; i++) {
                                        if (palette[i] === cur) { idx = i; break; }
                                    }
                                    var next = palette[(idx + 1) % palette.length];
                                    savedColors[model.id] = next;
                                    Plasmoid.configuration.gcalCalendarColors = JSON.stringify(savedColors);
                                }
                            }
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        // ---- Fontes .ics (leitura) ----
        Kirigami.Heading {
            level: 4
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18n("Fontes .ics (somente leitura)")
            textFormat: Text.PlainText
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Adicione fontes de calendário (.ics) para ver seus compromissos nas abas Agenda e Resumo.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("1. Abra o Google Calendar no navegador\n2. Clique em Configurações (engrenagem)\n3. Vá em Configurações do calendário\n4. Selecione o calendário desejado\n5. Role até Integração de calendário\n6. Copie o link Endereço público do iCal")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Formato:\nhttps://calendar.google.com/calendar/ical/seuemail%40gmail.com/public/basic.ics")
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
            text: i18n("Arquivo local")
            textFormat: Text.PlainText
        }

        QQC2.Button {
            text: i18n("Selecionar arquivo .ics...")
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
            text: i18n("Adicionar URL ou caminho")
            textFormat: Text.PlainText
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: agSourceField
                Layout.fillWidth: true
                placeholderText: i18n("URL iCal ou caminho local...")
                onAccepted: addAgButton.clicked()
            }

            QQC2.Button {
                id: addAgButton
                text: i18n("Adicionar")
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
                    icon.name: "list-remove"
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
