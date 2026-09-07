/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls as QQC2
import QtQuick.LocalStorage
import QtQml

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "js/feeds.js" as FeedParser
import "js/calendar.js" as Cal
import "js/weather.js" as Weather
import "pages"

PlasmoidItem {
    id: root

    property var allItems: []
    property var feedGroups: []
    property var feedFailures: []
    property var pendingUrls: []
    property int pendingItems: 0
    property bool loading: false
    readonly property int headlineLines: Number(Plasmoid.configuration.headlineLines) || 2
    readonly property int refreshMinutesValue: (function() {
        var v = Number(Plasmoid.configuration.refreshMinutes);
        if (typeof Plasmoid.configuration.refreshMinutes === "undefined" || v === null || isNaN(v)) {
            return 10; // padrão; 0 = só manual
        }
        return v;
    })()
    // Estado do auto-refresh de notícias extraído para feeds.js para virar
    // teste real: refreshMinutes=0 ⇒ running=false (não regressar o busy loop).
    readonly property var newsRefresh: FeedParser.newsRefreshState(
        root.refreshMinutesValue, root.currentFeeds().length > 0)
    readonly property var slicedAll: root.allItems.slice(0, Number(Plasmoid.configuration.maxItems) || 50)

    // Abas já visitadas: depois da 1ª visita a página permanece carregada.
    property var visitedTabs: [true, false, false, false, false, false, false]
    // Tick do relógio: força a saudação/data a re-renderizar a cada minuto.
    property int clockTick: 0
    // Cache de notícias em SQLite (QtQuick.LocalStorage).
    property var newsDbHandle: null
    // Cache antigo (migração do KConfig).
    property bool newsCacheMigrated: false

    // -------- agenda e to-dos do dia --------------------------------
    property var agendaEvents: []
    property var localEvents: []
    property var todoList: []
    property var completedList: []
    property var notesList: []
    property var listsList: []

    property bool agendaLoading: false
    property string agendaNotice: ""
    property var gcalCalendars: []
    property int currentTab: 0   // 0=Resumo, 1=Agenda, 2=Tarefas, 3=Clima, 4=Notas, 5=Listas, 6=Notícias

    // Tokens de geração: callbacks de XHR antigos são ignorados após nova carga.
    property int feedGen: 0
    property int agendaGen: 0
    property int weatherGen: 0
    property int lastNewsRefresh: 0
    property int lastAgendaRefresh: 0
    property int lastWeatherRefresh: 0

    // Fila de cargas no boot (uma de cada vez, sem tempestade na thread).
    property int bootStep: 0
    property var bootQueue: []

    onCurrentTabChanged: {
        if (currentTab >= 0 && currentTab < root.visitedTabs.length) {
            var v = root.visitedTabs.slice();
            v[currentTab] = true;
            root.visitedTabs = v;
        }
        if (currentTab === 3) {
            root.selectedCityName = Plasmoid.configuration.weatherCity || "";
        }
    }

    // -------- tradução: i18n() do Plasma (follows system locale) ---------

    // -------- clima --------------------------------
    property var weatherData: null
    property bool weatherLoading: false

    // -------- cidades adicionais (aba Clima) ------
    property var extraCities: []
    property var extraWeatherData: ({})
    property string selectedCityName: Plasmoid.configuration.weatherCity || ""
    property var selectedCityData: null

    function loadExtraCities() {
        try {
            var raw = Plasmoid.configuration.weatherCities;
            root.extraCities = raw ? JSON.parse(raw) : [];
        } catch (e) {
            root.extraCities = [];
        }
    }

    function refreshAllCitiesWeather() {
        root.extraCities.forEach(function(city) {
            Weather.fetchWeather(city.lat, city.lon,
                function(data) {
                    var copy = {};
                    for (var k in root.extraWeatherData) {
                        copy[k] = root.extraWeatherData[k];
                    }
                    copy[city.name] = data;
                    root.extraWeatherData = copy;
                },
                function(code) {}
            );
        });
    }

    function capFirst(str) {
        if (!str) return "";
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    function capWords(str) {
        return String(str).split(" ").map(root.capFirst).join(" ");
    }
    readonly property string chosenIcon: (function() {
        var c = Plasmoid.configuration.customIcon;
        if (c && c.trim() !== "") {
            return c;
        }
        return Plasmoid.configuration.iconName || "view-calendar-day";
    })()
    readonly property string iconResolvedName: root.iconIsFile(root.chosenIcon) ? "" : root.chosenIcon
    readonly property string iconResolvedSource: root.iconIsFile(root.chosenIcon) ? root.chosenIcon : ""

    function iconIsFile(value) {
        return value.indexOf("/") === 0 || value.indexOf("file://") === 0;
    }

    function applyIcon(name) {
        var n = (name || "").trim();
        if (!n || n === Plasmoid.configuration.iconName) {
            return;
        }
        Plasmoid.configuration.customIcon = "";
        Plasmoid.configuration.iconName = n;
        Plasmoid.icon = n;
    }

    function applyCustomIcon(url) {
        if (!url) {
            return;
        }
        Plasmoid.configuration.customIcon = url;
        Plasmoid.icon = url;
    }

    readonly property bool isDarkTheme: {
        var mode = Plasmoid.configuration.themeMode || 2;
        if (mode === 0) return false;
        if (mode === 1) return true;
        var bg = PlasmaCore.Theme.backgroundColor;
        var luminance = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b;
        return luminance < 0.5;
    }

    onChosenIconChanged: Plasmoid.icon = root.chosenIcon
    property string errorText: ""
    property string lastUpdated: ""

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 36
    Layout.preferredHeight: Kirigami.Units.gridUnit * 34
    Layout.maximumWidth: Kirigami.Units.gridUnit * 120
    Layout.maximumHeight: Kirigami.Units.gridUnit * 100

    // ---------------------------------------------------------------- plugins

    compactRepresentation: Item {
        id: compactRoot
        readonly property int compactMode: (function() {
            var m = Plasmoid.configuration.compactMode;
            return (m === 0 || m === 2) ? m : 1;
        })()

        Layout.minimumWidth: compactRoot.compactMode === 2 ? Kirigami.Units.gridUnit * 4 : Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: compactRoot.compactMode === 2 ? Kirigami.Units.gridUnit * 5 : Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Kirigami.Units.iconSizes.large

        // Modo "Ícone": ícone estático escolhido nas configurações.
        Item {
            anchors.fill: parent
            visible: compactRoot.compactMode === 0

            Kirigami.Icon {
                anchors.fill: parent
                anchors.margins: 4
                visible: root.iconResolvedSource === ""
                source: root.iconResolvedName
            }

            Image {
                anchors.fill: parent
                anchors.margins: 4
                visible: root.iconResolvedSource !== ""
                source: root.iconResolvedSource
                sourceSize: Qt.size(parent.width, parent.height)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        // Modo "Ícone interativo": calendário com o dia atual.
        DayIcon {
            anchors.fill: parent
            visible: compactRoot.compactMode === 1
        }

        // Modo "Relógio": horas com a data completa embaixo.
        CompactClock {
            anchors.fill: parent
            visible: compactRoot.compactMode === 2
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                root.currentTab = FeedParser.clampDefaultTab(Plasmoid.configuration.defaultTab);
                root.expanded = !root.expanded;
            }
            Accessible.name: Plasmoid.title
            cursorShape: Qt.PointingHandCursor
        }
    }

    // ------------------------------------------------------------------ lógica

    function currentFeeds() {
        var f = Plasmoid.configuration.feeds;
        if (typeof f === "undefined" || f === null) {
            return [];
        }
        return f;
    }

    function feedCapFor(index) {
        var caps = Plasmoid.configuration.feedLimits;
        if (typeof caps === "undefined" || caps === null) {
            return 0;
        }
        var v = parseInt(String(caps[index]), 10);
        return isNaN(v) || v <= 0 ? 0 : v;
    }

    function feedErrorText(url, code) {
        var why;
        if (code === -2) {
            why = i18n("tempo esgotado");
        } else if (code === -1) {
            why = i18n("falha de conexão");
        } else if (code === 0) {
            why = i18n("resposta inválida (não é RSS) ou servidor inacessível");
        } else if (code === -3) {
            why = i18n("abortado");
        } else {
            why = i18n("HTTP %1", code);
        }
        return i18n("%1 — %2", url, why);
    }

    // -------- cache de notícias (SQLite, fora do appletsrc) --------
    function newsDb() {
        if (root.newsDbHandle) {
            return root.newsDbHandle;
        }
        var db;
        try {
            db = LocalStorage.openDatabaseSync("yourday_news", "1.0", "Cache offline de notícias (Seu Dia...)", 4 * 1024 * 1024);
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS cache (id INTEGER PRIMARY KEY, data TEXT NOT NULL)");
            });
        } catch (e) {
            console.warn("[yourday] falha ao abrir cache SQLite:", e);
            return null;
        }
        root.newsDbHandle = db;
        return db;
    }

    function newsCacheJson() {
        var items = [];
        for (var i = 0; i < root.allItems.length; i++) {
            var it = root.allItems[i];
            items.push({
                title: it.title || "",
                link: it.link || "",
                source: it.source || "",
                time: it.time || "",
                summary: it.summary || "",
                image: it.image || ""
            });
        }
        return JSON.stringify(items);
    }

    function saveNewsCache() {
        var db = newsDb();
        if (!db) {
            return;
        }
        try {
            var json = newsCacheJson();
            db.transaction(function(tx) {
                tx.executeSql("INSERT OR REPLACE INTO cache (id, data) VALUES (1, ?)", [json]);
            });
        } catch (e) {
            console.warn("[yourday] falha ao salvar cache:", e);
        }
    }

    function loadNewsCache() {
        var db = newsDb();
        if (!db) {
            return false;
        }
        try {
            var items = null;
            db.readTransaction(function(tx) {
                var rs = tx.executeSql("SELECT data FROM cache WHERE id = 1");
                if (rs.rows.length > 0) {
                    try {
                        items = JSON.parse(rs.rows.item(0).data);
                    } catch (e) {
                        items = null;
                    }
                }
            });

            // Migração: cache antigo no appletsrc (cachedNews) -> SQLite.
            if ((!items || items.length === 0) && !root.newsCacheMigrated) {
                root.newsCacheMigrated = true;
                var legacy = Plasmoid.configuration.cachedNews;
                if (legacy) {
                    try {
                        var legacyItems = JSON.parse(legacy);
                        if (legacyItems && legacyItems.length > 0) {
                            items = legacyItems;
                            root.allItems = items;
                            saveNewsCache();
                        }
                    } catch (e) { /* cache corrompido: ignora */ }
                    if (Plasmoid.configuration.cachedNews !== "") {
                        Plasmoid.configuration.cachedNews = "";
                    }
                }
            }

            if (!items || items.length === 0) {
                return false;
            }
            root.allItems = items;
            return true;
        } catch (e) {
            return false;
        }
    }

    function finalizeLoad() {
        var items = FeedParser.applyLimits(root.feedGroups, Number(Plasmoid.configuration.maxItems) || 0);
        if (items.length === 0) {
            root.loadNewsCache();
        } else {
            root.allItems = items;
            saveNewsCache();
        }
        root.errorText = root.feedFailures.join("\n");
        root.lastUpdated = Qt.formatTime(new Date(), "HH:mm:ss");
        root.loading = false;
        loadWatchdog.stop();
    }

    function finishOne(url) {
        if (root.loading === false) {
            return; // já finalizado
        }
        var pos = root.pendingUrls.indexOf(url);
        if (pos === -1) {
            return; // já contabilizado
        }
        root.pendingUrls.splice(pos, 1);
        root.pendingItems = Math.max(0, root.pendingItems - 1);
        if (root.allItems.length === 0 && root.feedGroups.length > 0) {
            // Sem conteúdo ainda: mostra progressivamente ao chegar cada feed,
            // em vez de esperar todos (ou um lento) para aparecer.
            root.allItems = FeedParser.applyLimits(root.feedGroups, Number(Plasmoid.configuration.maxItems) || 0);
            root.errorText = root.feedFailures.join("\n");
        }
        if (root.pendingItems <= 0) {
            root.pendingItems = 0;
            finalizeLoad();
        }
    }

    function forceStuck() {
        if (!root.loading) {
            return;
        }
        var stuck = root.pendingUrls.slice();
        for (var i = 0; i < stuck.length; i++) {
            root.feedFailures.push(root.feedErrorText(stuck[i], -2));
            root.feedGroups.push({ items: [], cap: 0 });
            finishOne(stuck[i]);
        }
    }

    function loadAll() {
        var feeds = currentFeeds();
        if (feeds.length === 0) {
            root.loadNewsCache();
            root.loading = false;
            root.errorText = "";
            return;
        }

        root.feedGen++;
        var gen = root.feedGen;
        root.lastNewsRefresh = Date.now();
        root.loading = true;
        root.errorText = "";
        root.feedGroups = [];
        root.feedFailures = [];
        root.pendingUrls = feeds.slice();
        root.pendingItems = feeds.length;
        loadWatchdog.restart();

        for (var f = 0; f < feeds.length; f++) {
            (function(url, idx, myGen) {
                var settled = false;
                var done = function(code, items) {
                    if (settled || myGen !== root.feedGen) {
                        return;
                    }
                    if (root.pendingUrls.indexOf(url) === -1) {
                        // O watchdog já contabilizou este URL.
                        settled = true;
                        return;
                    }
                    settled = true;
                    if (code !== 0) {
                        console.warn("[yourday] feed FALHOU:", url, "código", code);
                        root.feedFailures.push(root.feedErrorText(url, code));
                        root.feedGroups.push({ items: [], cap: 0 });
                    } else {
                        console.log("[yourday] feed OK:", url, "->", items.length, "itens");
                        root.feedGroups.push({ items: items, cap: root.feedCapFor(idx) });
                    }
                    finishOne(url);
                };
                try {
                    FeedParser.loadFeed(url,
                        function(items) { done(0, items); },
                        function(code) { done(code); }
                    );
                } catch (e) {
                    done(-1, []);
                }
            })(feeds[f], f, gen);
        }
    }

    function openConfig() {
        // Plasma 6: o Applet expõe a ação "configure" (guia oficial de desenvolvedores).
        if (typeof plasmoid !== "undefined" && plasmoid.action && plasmoid.action("configure")) {
            plasmoid.action("configure").trigger();
        } else if (typeof Plasmoid.requestConfiguration === "function") {
            // Fallback para versões que ainda expõem este método.
            Plasmoid.requestConfiguration();
        }
    }

    // --------------------- agenda / to-dos --------------------------

    function parseTodos() {
        var raw = Plasmoid.configuration.todos;
        if (typeof raw === "undefined" || raw === null) {
            raw = [];
        }
        var out = [];
        for (var i = 0; i < raw.length; i++) {
            var text, done = false, created = 0;
            var parts = String(raw[i]).split("|");
            if (parts.length >= 3) {
                done = parts[parts.length - 2] === "1";
                created = parseInt(parts[parts.length - 1], 10) || 0;
                text = parts.slice(0, parts.length - 2).join("|");
            } else if (parts.length === 2) {
                done = parts[1] === "1";
                text = parts[0];
            } else {
                text = String(raw[i]);
            }
            out.push({ text: text, done: done, createdAt: created });
        }
        root.todoList = out;

        // Completed list
        var rawC = Plasmoid.configuration.completedTodos;
        if (typeof rawC === "undefined" || rawC === null) {
            rawC = [];
        }
        var outC = [];
        for (var j = 0; j < rawC.length; j++) {
            var cparts = String(rawC[j]).split("|");
            var ctext, ccreated = 0;
            if (cparts.length >= 2) {
                ccreated = parseInt(cparts[cparts.length - 1], 10) || 0;
                ctext = cparts.slice(0, cparts.length - 1).join("|");
            } else {
                ctext = String(rawC[j]);
            }
            outC.push({ text: ctext, done: true, createdAt: ccreated });
        }
        root.completedList = outC;
    }

    function saveTodos() {
        var raw = [];
        for (var i = 0; i < root.todoList.length; i++) {
            var rec = root.todoList[i].text + "|" + (root.todoList[i].done ? "1" : "0");
            if (root.todoList[i].createdAt) {
                rec += "|" + root.todoList[i].createdAt;
            }
            raw.push(rec);
        }
        Plasmoid.configuration.todos = raw;
    }

    function saveCompletedTodos() {
        var raw = [];
        for (var i = 0; i < root.completedList.length; i++) {
            var rec = root.completedList[i].text;
            if (root.completedList[i].createdAt) {
                rec += "|" + root.completedList[i].createdAt;
            }
            raw.push(rec);
        }
        Plasmoid.configuration.completedTodos = raw;
    }

    function addTodo(text) {
        root.todoList.push({ text: text, done: false, createdAt: Date.now() });
        root.saveTodos();
        root.todoList = root.todoList.slice();
    }

    function toggleTodo(index) {
        if (index < 0 || index >= root.todoList.length) {
            return;
        }
        var item = root.todoList[index];
        if (!item.done) {
            // Marcar como concluída: mover para completedList
            root.todoList.splice(index, 1);
            root.completedList.push({ text: item.text, done: true, createdAt: item.createdAt || Date.now() });
            root.saveTodos();
            root.saveCompletedTodos();
            root.todoList = root.todoList.slice();
            root.completedList = root.completedList.slice();
        } else {
            // Desmarcar: volta para pendente
            item.done = false;
            root.saveTodos();
            root.todoList = root.todoList.slice();
        }
    }

    function restoreTodo(index) {
        if (index < 0 || index >= root.completedList.length) {
            return;
        }
        var item = root.completedList[index];
        root.completedList.splice(index, 1);
        root.todoList.push({ text: item.text, done: false, createdAt: item.createdAt });
        root.saveCompletedTodos();
        root.saveTodos();
        root.completedList = root.completedList.slice();
        root.todoList = root.todoList.slice();
    }

    function removeTodo(index) {
        if (index < 0 || index >= root.todoList.length) {
            return;
        }
        root.todoList.splice(index, 1);
        root.saveTodos();
        root.todoList = root.todoList.slice();
    }

    function removeCompletedTodo(index) {
        if (index < 0 || index >= root.completedList.length) {
            return;
        }
        root.completedList.splice(index, 1);
        root.saveCompletedTodos();
        root.completedList = root.completedList.slice();
    }

    // -------- notas (post-its) --------------------------------
    function parseNotes() {
        var raw = Plasmoid.configuration.notes;
        if (typeof raw === "undefined" || raw === null) {
            raw = [];
        }
        var out = [];
        for (var i = 0; i < raw.length; i++) {
            var s = String(raw[i]);
            var sep = s.lastIndexOf("|");
            if (sep < 0) {
                out.push({ text: s, color: "#FFF9C4" });
            } else {
                out.push({ text: s.slice(0, sep), color: s.slice(sep + 1) });
            }
        }
        root.notesList = out;
    }

    function saveNotes() {
        var raw = [];
        for (var i = 0; i < root.notesList.length; i++) {
            raw.push(root.notesList[i].text + "|" + root.notesList[i].color);
        }
        Plasmoid.configuration.notes = raw;
    }

    function addNote(text, color) {
        root.notesList.push({ text: text, color: color || "#FFF9C4" });
        root.saveNotes();
        root.notesList = root.notesList.slice();
    }

    function removeNote(index) {
        if (index < 0 || index >= root.notesList.length) {
            return;
        }
        root.notesList.splice(index, 1);
        root.saveNotes();
        root.notesList = root.notesList.slice();
    }

    function updateNoteColor(index, color) {
        if (index < 0 || index >= root.notesList.length) {
            return;
        }
        root.notesList[index].color = color;
        root.saveNotes();
        root.notesList = root.notesList.slice();
    }

    function updateNoteText(index, text) {
        if (index < 0 || index >= root.notesList.length) {
            return;
        }
        root.notesList[index].text = text;
        root.saveNotes();
        root.notesList = root.notesList.slice();
    }

    function newItemsModel() {
        return Qt.createQmlObject("import QtQuick; ListModel {}", root, "listItemsModel");
    }

    function genId() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
    }

    // Lê uma entrada da config. Aceita o formato novo (JSON) e o antigo
    // ("nome|0/1|item1;item2"), gerando ids estáveis no legado.
    function parseListEntry(entry) {
        var s = String(entry || "").trim();
        if (s.charAt(0) === "{") {
            try {
                return JSON.parse(s);
            } catch (e) {
                return null;
            }
        }
        var parts = s.split("|");
        var name = parts[0];
        var done = false;
        var itemsPart = "";
        if (parts.length >= 3) {
            done = parts[1] === "1";
            itemsPart = parts[2];
        } else {
            itemsPart = parts[1] || "";
        }
        var items = [];
        if (itemsPart) {
            var itemParts = itemsPart.split(";");
            for (var j = 0; j < itemParts.length; j++) {
                var ip = itemParts[j].split("|");
                items.push({ text: ip[1] || "", done: ip[0] === "1", id: root.genId() });
            }
        }
        return { name: name, done: done, id: root.genId(), items: items };
    }

    function saveLists() {
        var raw = [];
        for (var i = 0; i < root.listsList.length; i++) {
            var list = root.listsList[i];
            var m = list.itemsModel;
            var items = [];
            for (var j = 0; j < m.count; j++) {
                var row = m.get(j);
                items.push({ text: row.text, done: !!row.done, id: row.id || root.genId() });
            }
            raw.push(JSON.stringify({ name: list.name, done: !!list.done, id: list.id, items: items }));
        }
        Plasmoid.configuration.lists = raw;
    }

    // Mantém as listas sempre ordenadas: ativas (done=false) primeiro.
    function sortListsArr(arr) {
        return arr.slice().sort(function(a, b) {
            var da = a.done ? 1 : 0;
            var db = b.done ? 1 : 0;
            return da - db;
        });
    }

    function findList(lid) {
        for (var i = 0; i < root.listsList.length; i++) {
            if (root.listsList[i].id === lid) {
                return root.listsList[i];
            }
        }
        return null;
    }

    function loadLists() {
        root.listsList = [];
        var raw = Plasmoid.configuration.lists;
        if (raw) {
            for (var i = 0; i < raw.length; i++) {
                var obj = root.parseListEntry(raw[i]);
                if (!obj) {
                    continue;
                }
                var m = root.newItemsModel();
                var items = obj.items || [];
                for (var j = 0; j < items.length; j++) {
                    m.append({ text: String(items[j].text || ""), done: !!items[j].done, id: items[j].id || root.genId() });
                }
                root.listsList.push({ name: String(obj.name || ""), done: !!obj.done, id: obj.id || root.genId(), itemsModel: m });
            }
        }
        root.listsList = root.sortListsArr(root.listsList);
    }

    function addList(name) {
        var list = { name: name, done: false, id: root.genId(), itemsModel: root.newItemsModel() };
        // Insere no grupo de ativas, antes da primeira lista finalizada.
        var insertAt = root.listsList.length;
        for (var i = 0; i < root.listsList.length; i++) {
            if (root.listsList[i].done) {
                insertAt = i;
                break;
            }
        }
        var arr = root.listsList.slice();
        arr.splice(insertAt, 0, list);
        root.listsList = arr;
        root.saveLists();
    }

    function removeList(lid) {
        for (var i = 0; i < root.listsList.length; i++) {
            if (root.listsList[i].id === lid) {
                root.listsList = root.listsList.slice(0, i).concat(root.listsList.slice(i + 1));
                break;
            }
        }
        root.saveLists();
    }

    function setListDone(lid, done) {
        for (var i = 0; i < root.listsList.length; i++) {
            if (root.listsList[i].id === lid) {
                root.listsList[i].done = done;
                break;
            }
        }
        root.listsList = root.sortListsArr(root.listsList);
        root.saveLists();
        if (listasLoader.item) {
            listasLoader.item.expandedList = -1;
            listasLoader.item.showHistory = done;
        }
    }

    function findListItem(list, iid) {
        var m = list.itemsModel;
        for (var i = 0; i < m.count; i++) {
            if (m.get(i).id === iid) {
                return i;
            }
        }
        return -1;
    }

    function addListItem(lid, text) {
        var list = root.findList(lid);
        if (!list) {
            return;
        }
        list.itemsModel.append({ text: text, done: false, id: root.genId() });
        root.saveLists();
    }

    function removeListItem(lid, iid) {
        var list = root.findList(lid);
        if (!list) {
            return;
        }
        var idx = root.findListItem(list, iid);
        if (idx >= 0) {
            list.itemsModel.remove(idx);
        }
        root.saveLists();
    }

    function toggleListItem(lid, iid) {
        var list = root.findList(lid);
        if (!list) {
            return;
        }
        var idx = root.findListItem(list, iid);
        if (idx >= 0) {
            list.itemsModel.setProperty(idx, "done", !list.itemsModel.get(idx).done);
        }
        root.saveLists();
    }

    function agendaSources() {
        var s = Plasmoid.configuration.agendaSources;
        if (typeof s === "undefined" || s === null) {
            return [];
        }
        return s;
    }

    // Janela visível da agenda: mês anterior até o final do mês seguinte
    // ao mês atual — os eventos fora dela não precisam ser carregados
    // (loop anos inteiros era fonte de travamento com recorrências antigas).
    function agendaWindow() {
        var now = new Date();
        var y = now.getFullYear();
        var m = now.getMonth();
        var from = new Date(y, m - 1, 1, 0, 0, 0, 0).getTime();
        var to = new Date(y, m + 2, 0, 23, 59, 59, 999).getTime();
        return { fromMs: from, toMs: to };
    }

    // Carrega eventos do dia a partir das fontes .ics configuradas.
    function refreshAgenda() {
        root.agendaGen++;
        var gen = root.agendaGen;
        root.lastAgendaRefresh = Date.now();
        root.agendaNotice = "";

        var sources = root.agendaSources();
        root.agendaLoading = true;

        var win = root.agendaWindow();

        // Corta fora da janela visível (RRULE da janela já no parser; aqui
        // garante consistência inclusive para os eventos locais).
        function inWindow(e) {
            return e.end > win.fromMs && e.start < win.toMs;
        }

        // Inclui eventos locais
        var all = root.localEvents.slice();

        // Tarefas pendentes até publicar: 1 XHR por fonte .ics + 1 por
        // calendário Google. O gate (calendar.js) garante que o finalize
        // roda exatamente uma vez — um handler que dispare em vários
        // readyStates intermediários não zera o pending antes da hora.
        var totalWork = sources.length;

        var scriptUrl = "";
        var selectedCals = [];
        if (root.isGCalAuthenticated()) {
            scriptUrl = Plasmoid.configuration.gcalClientId;
            selectedCals = (Plasmoid.configuration.gcalSelectedCalendars || "").split(",").filter(function(s) { return s; });
            if (selectedCals.length === 0) selectedCals = ["primary"];
            totalWork += selectedCals.length;
        }

        function publish() {
            if (gen !== root.agendaGen) {
                return;
            }
            all = all.filter(inWindow);
            all.sort(function(a, b) { return (a.start - b.start); });
            root.agendaEvents = all;
            root.agendaLoading = false;
        }

        var gate = Cal.makeCompleter(totalWork, publish);
        if (totalWork === 0) {
            // Sem fontes: o gate já publicou só os eventos locais.
            return;
        }

        if (root.isGCalAuthenticated()) {
            var now = new Date();
            var weekAgo = new Date(now.getTime() - 7 * 86400000);
            var weekAhead = new Date(now.getTime() + 30 * 86400000);

            for (var c = 0; c < selectedCals.length; c++) {
                (function(calId) {
                    var url = scriptUrl + "?action=list&calendarId=" + encodeURIComponent(calId) + "&timeMin=" + encodeURIComponent(weekAgo.toISOString()) + "&timeMax=" + encodeURIComponent(weekAhead.toISOString());

                    var xhr = new XMLHttpRequest();
                    xhr.open("GET", url, true);
                    xhr.timeout = 15000;
                    xhr.onreadystatechange = function() {
                        if (xhr.readyState !== XMLHttpRequest.DONE) {
                            return;
                        }
                        if (xhr.status >= 200 && xhr.status < 300) {
                            try {
                                var data = JSON.parse(xhr.responseText);
                                if (Array.isArray(data)) {
                                    var savedColors = {};
                                    try { savedColors = JSON.parse(Plasmoid.configuration.gcalCalendarColors || "{}"); } catch(e) {}
                                    for (var i = 0; i < data.length; i++) {
                                        var ev = data[i];
                                        all.push({
                                            title: ev.title || "(sem título)",
                                            start: Number(ev.start),
                                            end: Number(ev.end),
                                            allDay: !!ev.allDay,
                                            description: ev.description || "",
                                            location: ev.location || "",
                                            source: "google",
                                            googleId: ev.id,
                                            calendarId: calId,
                                            color: savedColors[calId] || "#4285f4"
                                        });
                                    }
                                }
                            } catch (e) {
                                console.warn("[yourday] erro parse Google Calendar:", e);
                            }
                        }
                        gate.next();
                    };
                    xhr.onerror = function() { gate.next(); };
                    xhr.ontimeout = function() { gate.next(); };
                    xhr.send(null);
                })(selectedCals[c]);
            }
        }

        for (var i = 0; i < sources.length; i++) {
            (function(src) {
                var url = String(src).trim();
                if (!url) {
                    gate.next();
                    return;
                }
                function handleText(text) {
                    try {
                        if (!Cal.withinIcsCap(text)) {
                            var shortUrl = url;
                            if (url.length > 60) {
                                shortUrl = url.slice(0, 57) + "...";
                            }
                            root.agendaNotice = i18n("Agenda ignorada: arquivo acima de 2 MB (%1)", shortUrl);
                            console.warn("[yourday] agenda recusada por tamanho:", url, String(text.length));
                            gate.next();
                            return;
                        }
                        var evs = Cal.allEvents(text, url, win.fromMs, win.toMs);
                        all = all.concat(evs);
                    } catch (e) {
                        console.warn("[yourday] erro parse agenda:", url, String(e));
                    }
                    gate.next();
                }
                if (/^https?:\/\//i.test(url)) {
                    Cal.loadUrl(url, handleText, function(code) {
                        console.warn("[yourday] agenda falhou fetch:", url, code);
                        gate.next();
                    });
                } else {
                    // Arquivo local: tenta XHR file:// (pode falhar) e segue.
                    try {
                        Cal.loadUrl("file://" + url, handleText, function(code) {
                            console.warn("[yourday] agenda falhou local:", url, code);
                            gate.next();
                        });
                    } catch (e) {
                        console.warn("[yourday] agenda local inválida:", url, String(e));
                        gate.next();
                    }
                }
            })(sources[i]);
        }
    }

    // -------- eventos locais (agenda) --------------------------------
    function parseLocalEvents() {
        var raw = Plasmoid.configuration.localEvents;
        if (typeof raw === "undefined" || raw === null) {
            raw = [];
        }
        var out = [];
        for (var i = 0; i < raw.length; i++) {
            try {
                var ev = JSON.parse(String(raw[i]));
                if (ev && ev.title && ev.start) {
                    out.push({
                        id: ev.id || String(Date.now()) + "_" + i,
                        title: ev.title,
                        start: Number(ev.start),
                        end: Number(ev.end) || Number(ev.start) + 3600000,
                        allDay: !!ev.allDay,
                        description: ev.description || "",
                        location: ev.location || "",
                        source: "local",
                        googleId: ev.googleId || null
                    });
                }
            } catch (e) {
                // ignora entrada inválida
            }
        }
        root.localEvents = out;
    }

    function saveLocalEvents() {
        var raw = [];
        for (var i = 0; i < root.localEvents.length; i++) {
            var ev = root.localEvents[i];
            raw.push(JSON.stringify({
                id: ev.id,
                title: ev.title,
                start: ev.start,
                end: ev.end,
                allDay: ev.allDay,
                description: ev.description,
                location: ev.location,
                googleId: ev.googleId || null
            }));
        }
        Plasmoid.configuration.localEvents = raw;
    }

    function isGCalAuthenticated() {
        var scriptUrl = Plasmoid.configuration.gcalClientId;
        return scriptUrl && scriptUrl.indexOf("script.google.com") !== -1;
    }

    function syncToGoogle(event, callback) {
        if (!isGCalAuthenticated()) {
            if (callback) callback();
            return;
        }
        var scriptUrl = Plasmoid.configuration.gcalClientId;
        var calId = Plasmoid.configuration.gcalCalendarId || "primary";
        var action = event.googleId ? "update" : "create";
        var url = scriptUrl + "?action=" + action
            + "&calendarId=" + encodeURIComponent(calId)
            + "&title=" + encodeURIComponent(event.title)
            + "&start=" + event.start
            + "&end=" + event.end
            + "&description=" + encodeURIComponent(event.description || "")
            + "&location=" + encodeURIComponent(event.location || "");

        if (event.googleId) {
            url += "&id=" + encodeURIComponent(event.googleId);
        }

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.timeout = 15000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    if (callback) callback(data.id || event.googleId);
                } catch (e) {
                    if (callback) callback(null);
                }
            } else {
                console.warn("[yourday] erro sync Google:", xhr.status);
                if (callback) callback(null);
            }
        };
        xhr.onerror = function() { if (callback) callback(null); };
        xhr.ontimeout = function() { if (callback) callback(null); };
        xhr.send(null);
    }

    function deleteFromGoogle(googleId) {
        if (!isGCalAuthenticated() || !googleId) return;
        var scriptUrl = Plasmoid.configuration.gcalClientId;
        var url = scriptUrl + "?action=delete&id=" + encodeURIComponent(googleId);

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.timeout = 15000;
        xhr.onreadystatechange = function() {};
        xhr.onerror = function() {};
        xhr.ontimeout = function() {};
        xhr.send(null);
    }

    function addGCalEvent(title, startMs, endMs, allDay, description, location, calId) {
        if (!root.isGCalAuthenticated()) {
            return;
        }
        var scriptUrl = Plasmoid.configuration.gcalClientId;
        var url = scriptUrl + "?action=create"
            + "&calendarId=" + encodeURIComponent(calId)
            + "&title=" + encodeURIComponent(title)
            + "&start=" + startMs
            + "&end=" + endMs
            + "&allDay=" + (allDay ? "true" : "false")
            + "&description=" + encodeURIComponent(description || "")
            + "&location=" + encodeURIComponent(location || "");

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.timeout = 15000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    JSON.parse(xhr.responseText);
                } catch (e) {
                    console.warn("[yourday] resposta inválida ao criar evento Google:", e);
                }
            } else {
                console.warn("[yourday] erro ao criar evento Google:", xhr.status);
            }
            root.refreshAgenda();
        };
        xhr.onerror = function() { root.refreshAgenda(); };
        xhr.ontimeout = function() { root.refreshAgenda(); };
        xhr.send(null);
    }

    function fetchGCalCalendars() {
        if (!root.isGCalAuthenticated()) {
            return;
        }
        var scriptUrl = Plasmoid.configuration.gcalClientId;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", scriptUrl + "?action=listCalendars", true);
        xhr.timeout = 15000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    if (Array.isArray(data) && data.length > 0) {
                        root.gcalCalendars = data.map(function(cal) {
                            return { id: cal.id, summary: cal.summary || cal.name || cal.id, primary: !!cal.isDefault, color: cal.color || "#4285f4" };
                        });
                        var savedColors = {};
                        try { savedColors = JSON.parse(Plasmoid.configuration.gcalCalendarColors || "{}"); } catch(e) {}
                        for (var i = 0; i < data.length; i++) {
                            if (!savedColors[data[i].id]) {
                                savedColors[data[i].id] = data[i].color || "#4285f4";
                            }
                        }
                        Plasmoid.configuration.gcalCalendarColors = JSON.stringify(savedColors);
                    }
                } catch (e) {
                    console.warn("[yourday] erro ao listar calendários Google:", e);
                }
            }
        };
        xhr.onerror = function() {};
        xhr.ontimeout = function() {};
        xhr.send(null);
    }

    function agendaTargetCalendars() {
        var out = [{ id: "local", label: i18n("Local"), color: "#34a853" }];
        if (root.isGCalAuthenticated()) {
            for (var i = 0; i < root.gcalCalendars.length; i++) {
                var cal = root.gcalCalendars[i];
                out.push({ id: cal.id, label: cal.summary || cal.id, color: cal.color || "#4285f4" });
            }
        }
        return out;
    }

    function addLocalEvent(title, startMs, endMs, allDay, description, location, calendarId) {
        if (calendarId && calendarId !== "local") {
            root.addGCalEvent(title, startMs, endMs, allDay, description, location, calendarId);
            return;
        }
        var id = String(Date.now()) + "_" + Math.random().toString(36).substr(2, 6);
        var ev = {
            id: id,
            title: title,
            start: startMs,
            end: endMs || startMs + (allDay ? 86400000 : 3600000),
            allDay: !!allDay,
            description: description || "",
            location: location || "",
            source: "local",
            googleId: null
        };
        root.localEvents.push(ev);
        root.saveLocalEvents();
        root.localEvents = root.localEvents.slice();
        root.refreshAgenda();
    }

    function updateLocalEvent(id, title, startMs, endMs, allDay, description, location) {
        var ev = null;
        for (var i = 0; i < root.localEvents.length; i++) {
            if (root.localEvents[i].id === id) {
                root.localEvents[i].title = title;
                root.localEvents[i].start = startMs;
                root.localEvents[i].end = endMs || startMs + (allDay ? 86400000 : 3600000);
                root.localEvents[i].allDay = !!allDay;
                root.localEvents[i].description = description || "";
                root.localEvents[i].location = location || "";
                ev = root.localEvents[i];
                break;
            }
        }
        root.saveLocalEvents();
        root.localEvents = root.localEvents.slice();

        // Sincroniza com Google Calendar
        if (ev) {
            syncToGoogle(ev, function(googleId) {
                if (googleId && !ev.googleId) {
                    ev.googleId = googleId;
                    root.saveLocalEvents();
                    root.localEvents = root.localEvents.slice();
                }
                root.refreshAgenda();
            });
        }

        root.refreshAgenda();
    }

    function removeLocalEvent(id) {
        var ev = null;
        for (var i = root.localEvents.length - 1; i >= 0; i--) {
            if (root.localEvents[i].id === id) {
                ev = root.localEvents[i];
                root.localEvents.splice(i, 1);
                break;
            }
        }
        root.saveLocalEvents();
        root.localEvents = root.localEvents.slice();

        // Remove do Google Calendar
        if (ev && ev.googleId) {
            deleteFromGoogle(ev.googleId);
        }

        root.refreshAgenda();
    }

    function gotoClima() { root.currentTab = 3; }
    function gotoNotas() { root.currentTab = 4; }
    function gotoListas() { root.currentTab = 5; }
    function gotoNoticias() { root.currentTab = 6; }

    function refreshWeather() {
        root.weatherGen++;
        var gen = root.weatherGen;
        root.lastWeatherRefresh = Date.now();
        var lat = Plasmoid.configuration.weatherLatitude;
        var lon = Plasmoid.configuration.weatherLongitude;
        if (!lat || !lon || lat === 0 || lon === 0) {
            root.weatherData = null;
            return;
        }
        root.weatherLoading = true;
        Weather.fetchWeather(lat, lon,
            function(data) {
                if (gen !== root.weatherGen) {
                    return;
                }
                root.weatherData = data;
                root.weatherLoading = false;
                root.refreshAllCitiesWeather();
            },
            function(code) {
                if (gen !== root.weatherGen) {
                    return;
                }
                console.warn("[yourday] clima falhou:", code);
                root.weatherLoading = false;
            }
        );
    }

    Component.onCompleted: {
        Plasmoid.icon = root.chosenIcon;
        // Síncrono/barato primeiro (mostra Resumo na hora, sem rede).
        root.loadNewsCache();
        parseTodos();
        parseNotes();
        loadLists();
        parseLocalEvents();
        // Lista de calendários do Google para o seletor de agenda (tudo em memória).
        root.fetchGCalCalendars();
        // Rede em fila, uma carga por vez.
        root.bootQueue = [root.refreshWeather, root.refreshAgenda, root.loadAll, root.loadExtraCities];
        root.bootStep = 0;
        bootTimer.start();
    }

    Timer {
        id: bootTimer
        interval: 250
        repeat: true
        onTriggered: {
            if (root.bootStep >= root.bootQueue.length) {
                root.bootQueue = [];
                root.bootStep = 0;
                bootTimer.stop();
                return;
            }
            var fn = root.bootQueue[root.bootStep];
            root.bootStep++;
            if (typeof fn === "function") {
                fn();
            }
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key, value) {
            if (key === "feeds") {
                root.loadAll();
            } else if (key === "maxItems") {
                // slicedAll é um binding: reavalia sozinho.
            } else if (key === "agendaSources") {
                root.refreshAgenda();
            } else if (key === "weatherLatitude" || key === "weatherLongitude") {
                root.refreshWeather();
            } else if (key === "weatherCities") {
                root.loadExtraCities();
                root.refreshAllCitiesWeather();
            }
        }
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.currentTab = FeedParser.clampDefaultTab(Plasmoid.configuration.defaultTab);
            // Sem tempestade ao abrir: só refaz rede se a última foi há > 5 min.
            var now = Date.now();
            if (now - root.lastAgendaRefresh >= 5 * 60000) root.refreshAgenda();
            if (now - root.lastWeatherRefresh >= 5 * 60000) root.refreshWeather();
            root.parseTodos();
        }
    }

    Timer {
        id: refreshTimer
        objectName: "refreshTimer"
        interval: root.newsRefresh.interval
        repeat: true
        running: root.newsRefresh.running
        onTriggered: root.loadAll()
    }

    onRefreshMinutesValueChanged: {
        if (root.refreshMinutesValue <= 0) {
            refreshTimer.stop();
            return;
        }
        refreshTimer.restart();
    }

    // Timer para atualização automática do clima (a cada 30 minutos)
    Timer {
        id: weatherRefreshTimer
        interval: 30 * 60000
        repeat: true
        running: Plasmoid.configuration.weatherCity !== ""
        onTriggered: {
            root.refreshWeather();
            root.refreshAllCitiesWeather();
        }
    }

    // Segurança: se algo travar durante o carregamento, aborta os XHR restantes
    // e libera o spinner no fim (não finge que terminou com resposta falsa).
    Timer {
        id: loadWatchdog
        interval: 20 * 1000
        repeat: false
        onTriggered: {
            FeedParser.abortAllNews();
            root.forceStuck();
        }
    }

    Timer {
        id: clockTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            root.clockTick++;
        }
    }

    // ------------------------------------------------------------------- dados

    Component {
        id: newsCardDelegate

        Rectangle {
            id: card
            required property var model

            readonly property bool hovered: cardMouse.containsMouse

            width: ListView.view.width
            height: Math.max(120, Math.min(212, contentText.implicitHeight + 16))
            radius: Kirigami.Units.roundIconSize / 4
            color: card.hovered
                   ? Qt.alpha(root.isDarkTheme ? Qt.rgba(0.35, 0.65, 0.9, 1) : Qt.rgba(0.15, 0.5, 0.85, 1), 0.15)
                   : (root.isDarkTheme ? Qt.rgba(0.22, 0.22, 0.22, 1) : Qt.rgba(1, 1, 1, 1))
            border.width: 1
            border.color: Qt.alpha(root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.75, 0.75, 0.75, 1), 0.5)

            Behavior on color {
                enabled: false // Desabilitado para performance
            }

            Rectangle {
                id: thumbBox
                visible: card.model.image !== ""
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                width: 84
                height: 96
                radius: 6
                color: root.isDarkTheme ? Qt.rgba(0.28, 0.28, 0.28, 1) : Qt.rgba(0.92, 0.92, 0.92, 1)
                clip: true

                Loader {
                    anchors.fill: parent
                    active: card.model.image !== ""
                    asynchronous: true
                    sourceComponent: Component {
                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: card.model.image
                            sourceSize: Qt.size(84, 96)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    thumbBox.visible = false;
                                }
                            }
                        }
                    }
                }
            }

            Column {
                id: contentText
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.right: thumbBox.visible ? thumbBox.left : parent.right
                anchors.rightMargin: 8
                spacing: 2

                PlasmaComponents3.Label {
                    width: contentText.width
                    text: card.model.title
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    font.pixelSize: 13
                    color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                }

                PlasmaComponents3.Label {
                    width: contentText.width
                    anchors.topMargin: 2
                    visible: card.model.summary !== "" && root.headlineLines > 0
                    text: card.model.summary
                    wrapMode: Text.Wrap
                    maximumLineCount: root.headlineLines
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.72)
                }

                Row {
                    width: contentText.width
                    anchors.topMargin: 2
                    spacing: 4

                    PlasmaComponents3.Label {
                        width: Math.min(contentText.width * 0.6, 220)
                        text: card.model.source
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.65)
                    }
                    PlasmaComponents3.Label {
                        visible: card.model.time > 0 && card.model.source !== ""
                        text: "•"
                        font.pixelSize: 11
                        color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.45)
                    }
                    PlasmaComponents3.Label {
                        text: FeedParser.relativeTime(card.model.time)
                        font.pixelSize: 11
                        color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.45)
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(card.model.link)
                onPressed: card.opacity = 0.8
                onReleased: card.opacity = 1
            }
        }
    }

    // ----------------------------------------------------------------------- UI

    // Botão de aba lateral
    Component {
        id: navButton

        Item {
            required property var modelData
            required property int index

            Layout.preferredWidth: 56
            Layout.preferredHeight: 52
            Layout.alignment: Qt.AlignHCenter

            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.smallSpacing
                color: index === root.currentTab
                       ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), 0.25)
                       : "transparent"
                border.width: index === root.currentTab ? 1 : 0
                border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), 0.5)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentTab = index
                Accessible.name: modelData.label
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Kirigami.Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 20
                    height: 20
                    source: modelData.icon
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    isMask: true
                }

                PlasmaComponents3.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.label
                    font.pixelSize: 10
                    opacity: index === root.currentTab ? 1.0 : 0.65
                    color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                }
            }
        }
    }

    fullRepresentation: Rectangle {
        color: (root.isDarkTheme ? Qt.rgba(0.16, 0.16, 0.16, 1) : Qt.rgba(0.96, 0.96, 0.96, 1))

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------------- Abas laterais + conteúdo
            RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: 0

            // Barra lateral de navegação
            ColumnLayout {
                id: sidebar
                Layout.preferredWidth: 64
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: [
                        { label: i18n("Resumo"), icon: "view-calendar-day" },
                        { label: i18n("Agenda"), icon: "view-calendar" },
                        { label: i18n("Tarefas"), icon: "task-new" },
                        { label: i18n("Clima"), icon: "weather-clear" },
                        { label: i18n("Notas"), icon: "note" },
                        { label: i18n("Listas"), icon: "view-list" },
                        { label: i18n("Notícias"), icon: root.iconResolvedName }
                    ]
                    delegate: navButton
                }
            }

            // Separador vertical
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: (root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1))
                Layout.margins: Kirigami.Units.smallSpacing
            }

            // Conteúdo das abas
            StackLayout {
                id: tabStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentTab

                ResumoPage {
                    events: root.agendaEvents
                    todos: root.todoList
                    loading: root.agendaLoading
                    weatherData: root.weatherData
                    weatherLoading: root.weatherLoading
                    weatherCity: Plasmoid.configuration.weatherCity || ""
                    onToggleTodoId: function(index) { root.toggleTodo(index); }
                }

                Loader {
                    active: root.visitedTabs[1]
                    asynchronous: true
                    sourceComponent: Component {
                        AgendaPage {
                            events: root.agendaEvents
                            loading: root.agendaLoading
                            notice: root.agendaNotice
                            calendarTargets: root.agendaTargetCalendars()
                            onAddEvent: function(title, startMs, endMs, allDay, description, location, calendarId) { root.addLocalEvent(title, startMs, endMs, allDay, description, location, calendarId); }
                            onUpdateEvent: function(id, title, startMs, endMs, allDay, description, location) { root.updateLocalEvent(id, title, startMs, endMs, allDay, description, location); }
                            onRemoveEvent: function(id) { root.removeLocalEvent(id); }
                        }
                    }
                }

                Loader {
                    active: root.visitedTabs[2]
                    asynchronous: true
                    sourceComponent: Component {
                        ToDoPage {
                            todos: root.todoList
                            completedTodos: root.completedList
                            onAddTodo: function(text) { root.addTodo(text); }
                            onToggleTodo: function(index) { root.toggleTodo(index); }
                            onRemoveTodo: function(index) { root.removeTodo(index); }
                            onRestoreTodo: function(index) { root.restoreTodo(index); }
                            onRemoveCompletedTodo: function(index) { root.removeCompletedTodo(index); }
                        }
                    }
                }

                Loader {
                    active: root.visitedTabs[3]
                    asynchronous: true
                    sourceComponent: Component {
                        ClimaPage {
                            weatherData: root.weatherData
                            weatherLoading: root.weatherLoading
                            weatherCity: Plasmoid.configuration.weatherCity || ""
                            extraCities: root.extraCities
                            extraWeatherData: root.extraWeatherData
                            selectedCityName: root.selectedCityName
                        }
                    }
                }

                // Página de Notas
                Loader {
                    active: root.visitedTabs[4]
                    asynchronous: true
                    sourceComponent: Component {
                        NotasPage {
                            notes: root.notesList
                            onAddNote: function(text, color) { root.addNote(text, color); }
                            onRemoveNote: function(index) { root.removeNote(index); }
                            onUpdateNoteColor: function(index, color) { root.updateNoteColor(index, color); }
                            onUpdateNoteText: function(index, text) { root.updateNoteText(index, text); }
                        }
                    }
                }

                // Página de Listas
                Loader {
                    id: listasLoader
                    active: root.visitedTabs[5]
                    asynchronous: true
                    sourceComponent: Component {
                        ListasPage {
                            id: listasPage
                            lists: root.listsList
                            onAddList: function(name) { root.addList(name); }
                            onRemoveList: function(listId) { root.removeList(listId); }
                            onAddItem: function(listId, text) { root.addListItem(listId, text); }
                            onRemoveItem: function(listId, itemId) { root.removeListItem(listId, itemId); }
                            onToggleItem: function(listId, itemId) { root.toggleListItem(listId, itemId); }
                            onSetDone: function(listId, done) { root.setListDone(listId, done); }
                        }
                    }
                }

                // Página de Notícias (corpo original das notícias)
                Loader {
                    active: root.visitedTabs[6]
                    asynchronous: true
                    sourceComponent: Component {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                    // Header fixo
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaExtras.Heading {
                            level: 4
                            Layout.fillWidth: true
                            text: i18n("Aqui estão as principais notícias de seu interesse")
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        }

                        PlasmaComponents3.ToolButton {
                            id: newsRefreshBtn
                            onClicked: root.loadAll()
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: i18n("Atualizar notícias")

                            contentItem: Item {
                                implicitWidth: 36
                                implicitHeight: 36

                                Kirigami.Icon {
                                    id: newsRefreshIcon
                                    source: "view-refresh"
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20

                                    NumberAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: root.loading
                                    }
                                }
                            }

                            background: Rectangle {
                                radius: Kirigami.Units.smallSpacing
                                color: newsRefreshBtn.hovered
                                       ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.1)
                                       : newsRefreshBtn.pressed
                                         ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.15)
                                         : "transparent"
                            }
                        }
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }

                    // Corpo rolante: ListView de coluna única com delegação reciclada,
                    // barra de rolagem e textura de fundo.
                    Item {
                        id: bodyArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            id: newsList
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.slicedAll
                            delegate: newsCardDelegate
                            cacheBuffer: 600
                            spacing: Kirigami.Units.smallSpacing
                            ScrollBar.vertical: ScrollBar {}
                        }

                        // Carregando…
                        QQC2.BusyIndicator {
                            anchors.centerIn: parent
                            visible: root.loading && root.slicedAll.length === 0
                            running: visible
                        }

                        // Estado vazio
                        Kirigami.PlaceholderMessage {
                            anchors.centerIn: parent
                            visible: !root.loading && root.slicedAll.length === 0

                            icon.name: root.iconResolvedName
                            icon.source: root.iconResolvedSource
                            text: root.currentFeeds().length === 0
                                  ? i18n("Nenhum feed configurado.\nAdicione feeds RSS nas Configurações.")
                                  : (root.errorText === ""
                                     ? i18n("Nenhuma notícia encontrada")
                                     : i18n("Nenhuma notícia carregada. Veja os detalhes abaixo."))

                            helpfulAction: Kirigami.Action {
                                text: root.currentFeeds().length === 0 ? i18n("Abrir configurações") : i18n("Tentar novamente")
                                icon.name: root.currentFeeds().length === 0 ? "configure" : "view-refresh"
                                onTriggered: root.currentFeeds().length === 0 ? root.openConfig() : root.loadAll()
                            }
                        }
                    }
                }
            }
                    }
                }
        }

        // ---------------- Rodapé (apenas na aba Notícias)
        ColumnLayout {
            visible: root.currentTab === 6
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.InlineMessage {
                id: errorMessage
                Layout.fillWidth: true
                visible: root.errorText !== ""
                type: Kirigami.MessageType.Warning
                text: i18n("Alguns feeds não carregaram:") + "\n" + root.errorText
                showCloseButton: true
                onVisibleChanged: if (!visible) root.errorText = ""
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.lastUpdated === ""
                      ? ""
                      : i18n("Atualizado às %1", root.lastUpdated)
                opacity: 0.55
                font.pixelSize: 10
            }
        } // ColumnLayout (bodyItem)
    } // Rectangle
}
}