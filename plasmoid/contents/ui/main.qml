/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQml

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "js/feeds.js" as FeedParser
import "js/calendar.js" as Cal
import "js/weather.js" as Weather
import "js/i18n.js" as I18n
import "pages"

PlasmoidItem {
    id: root

    property var allItems: []
    property var feedGroups: []
    property var feedFailures: []
    property var pendingUrls: []
    property int pendingItems: 0
    property double hangDeadline: 0
    property bool loading: false
    readonly property int headlineLines: Number(Plasmoid.configuration.headlineLines) || 2
    readonly property int newsColumns: Math.max(1, Math.min(4, Number(Plasmoid.configuration.columns) || 1))
    readonly property int refreshMinutesValue: (function() {
        var v = Number(Plasmoid.configuration.refreshMinutes);
        if (typeof Plasmoid.configuration.refreshMinutes === "undefined" || v === null || isNaN(v)) {
            return 10; // padrão; 0 = só manual
        }
        return v;
    })()
    readonly property var slicedAll: root.allItems.slice(0, Number(Plasmoid.configuration.maxItems) || 50)
    property double bodyWidth: 0
    readonly property double gridColumnWidth: root.newsColumns > 0
            ? Math.max(0, (root.bodyWidth - Kirigami.Units.largeSpacing * (root.newsColumns - 1)) / root.newsColumns) : 0

    // -------- agenda e to-dos do dia --------------------------------
    property var agendaEvents: []
    property var todoList: []
    property var completedList: []
    property var notesList: []
    property var listsList: []
    property bool agendaLoading: false
    property int currentTab: 0   // 0=Resumo, 1=Agenda, 2=Tarefas, 3=Clima, 4=Notas, 5=Listas, 6=Notícias

    onCurrentTabChanged: {
        if (currentTab === 3) {
            root.selectedCityName = Plasmoid.configuration.weatherCity || "";
        }
    }

    // -------- tradução forçada --------------------
    function t(text) {
        var lang = Plasmoid.configuration.language || "";
        if (!lang) return text;
        return I18n.translate(text, lang);
    }

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
                    var copy = JSON.parse(JSON.stringify(root.extraWeatherData));
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

    Layout.minimumWidth: Kirigami.Units.gridUnit * 60
    Layout.minimumHeight: Kirigami.Units.gridUnit * 50
    Layout.preferredWidth: Kirigami.Units.gridUnit * 81
    Layout.preferredHeight: Kirigami.Units.gridUnit * 80
    Layout.maximumWidth: Kirigami.Units.gridUnit * 120
    Layout.maximumHeight: Kirigami.Units.gridUnit * 100

    // ---------------------------------------------------------------- plugins

    compactRepresentation: Item {
        id: compactRoot
        Layout.minimumWidth: Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Kirigami.Units.iconSizes.large

        DayIcon {
            anchors.fill: parent
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                root.currentTab = Plasmoid.configuration.defaultTab || 0;
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

    property var _lastSliced: []
    property string _lastSlicedKey: ""

    function sliceItems() {
        var limit = Number(Plasmoid.configuration.maxItems) || 50;
        var items = root.allItems.slice(0, limit);
        // Só atualiza se mudou (evita re-render desnecessário)
        var key = items.length + ":" + (items.length > 0 ? items[0].title : "");
        if (key !== root._lastSlicedKey) {
            root._lastSlicedKey = key;
            // Força atualização apenas quando necessário
            root._lastSliced = items;
        }
    }

    function feedErrorText(url, code) {
        var why;
        if (code === -2) {
            why = i18n("tempo esgotado");
        } else if (code === -1) {
            why = i18n("falha de conexão");
        } else if (code === 0) {
            why = i18n("resposta inválida (não é RSS) ou servidor inacessível");
        } else {
            why = i18n("HTTP %1", code);
        }
        return i18n("%1 — %2", url, why);
    }

    // -------- cache de notícias (offline) --------
    function saveNewsCache() {
        try {
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
            Plasmoid.configuration.cachedNews = JSON.stringify(items);
        } catch (e) {
            console.warn("[yourday] falha ao salvar cache:", e);
        }
    }

    function loadNewsCache() {
        try {
            var raw = Plasmoid.configuration.cachedNews;
            if (!raw) return false;
            var items = JSON.parse(raw);
            if (!items || items.length === 0) return false;
            root.allItems = items;
            sliceItems();
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
        hangTimer.stop();
        sliceItems();
    }

    function finishOne(url) {
        if (root.loading === false) {
            return; // já finalizado pelo watchdog
        }
        if (root.pendingItems <= 0) {
            return;
        }
        var pos = root.pendingUrls.indexOf(url);
        if (pos !== -1) {
            root.pendingUrls.splice(pos, 1);
        }
        root.pendingItems--;
        if (root.allItems.length === 0 && root.feedGroups.length > 0) {
            // Sem conteúdo ainda: mostra progressivamente ao chegar cada feed,
            // em vez de esperar todos (ou um lento) para aparecer.
            root.allItems = FeedParser.applyLimits(root.feedGroups, Number(Plasmoid.configuration.maxItems) || 0);
            root.errorText = root.feedFailures.join("\n");
            sliceItems();
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

        root.loading = true;
        root.errorText = "";
        root.feedGroups = [];
        root.feedFailures = [];
        root.pendingUrls = feeds.slice();
        root.pendingItems = feeds.length;
        root.hangDeadline = Date.now() + 10000;
        loadWatchdog.restart();
        hangTimer.running = true;

        for (var f = 0; f < feeds.length; f++) {
            (function(url, idx) {
                try {
                    FeedParser.loadFeed(url,
                        function(items) {
                            console.log("[yourday] feed OK:", url, "->", items.length, "itens");
                            root.feedGroups.push({ items: items, cap: root.feedCapFor(idx) });
                            finishOne(url);
                        },
                        function(code) {
                            console.warn("[yourday] feed FALHOU:", url, "código", code);
                            root.feedFailures.push(root.feedErrorText(url, code));
                            root.feedGroups.push({ items: [], cap: 0 });
                            finishOne(url);
                        }
                    );
                } catch (e) {
                    console.warn("[yourday] exceção ao carregar:", url, String(e));
                    root.feedFailures.push(i18n("Falha em %1 (%2)", url, String(e)));
                    root.feedGroups.push({ items: [], cap: 0 });
                    finishOne(url);
                }
            })(feeds[f], f);
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
            var s = String(raw[i]);
            var sep = s.lastIndexOf("|");
            if (sep < 0) {
                out.push({ text: s, done: false });
            } else {
                out.push({ text: s.slice(0, sep), done: s.slice(sep + 1) === "1" });
            }
        }
        root.todoList = out;

        // Completed list
        var rawC = Plasmoid.configuration.completedTodos;
        if (typeof rawC === "undefined" || rawC === null) {
            rawC = [];
        }
        var outC = [];
        for (var j = 0; j < rawC.length; j++) {
            outC.push({ text: String(rawC[j]), done: true });
        }
        root.completedList = outC;
    }

    function saveTodos() {
        var raw = [];
        for (var i = 0; i < root.todoList.length; i++) {
            raw.push(root.todoList[i].text + "|" + (root.todoList[i].done ? "1" : "0"));
        }
        Plasmoid.configuration.todos = raw;
    }

    function saveCompletedTodos() {
        var raw = [];
        for (var i = 0; i < root.completedList.length; i++) {
            raw.push(root.completedList[i].text);
        }
        Plasmoid.configuration.completedTodos = raw;
    }

    function addTodo(text) {
        root.todoList.push({ text: text, done: false });
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
            root.completedList.push({ text: item.text, done: true });
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
        root.todoList.push({ text: item.text, done: false });
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

    function saveLists() {
        var raw = [];
        for (var i = 0; i < root.listsList.length; i++) {
            var items = [];
            for (var j = 0; j < root.listsList[i].items.length; j++) {
                items.push((root.listsList[i].items[j].done ? "1" : "0") + "|" + root.listsList[i].items[j].text);
            }
            raw.push(root.listsList[i].name + "|" + items.join(";"));
        }
        Plasmoid.configuration.lists = raw;
    }

    function loadLists() {
        var raw = Plasmoid.configuration.lists;
        var out = [];
        if (raw) {
            for (var i = 0; i < raw.length; i++) {
                var parts = raw[i].split("|");
                var name = parts[0];
                var items = [];
                if (parts[1]) {
                    var itemParts = parts[1].split(";");
                    for (var j = 0; j < itemParts.length; j++) {
                        var ip = itemParts[j].split("|");
                        items.push({ text: ip[1] || "", done: ip[0] === "1" });
                    }
                }
                out.push({ name: name, items: items });
            }
        }
        root.listsList = out;
    }

    function addList(name) {
        root.listsList.push({ name: name, items: [] });
        root.saveLists();
        root.listsList = root.listsList.slice();
    }

    function removeList(index) {
        if (index < 0 || index >= root.listsList.length) {
            return;
        }
        root.listsList.splice(index, 1);
        root.saveLists();
        root.listsList = root.listsList.slice();
    }

    function addListItem(listIndex, text) {
        if (listIndex < 0 || listIndex >= root.listsList.length) {
            return;
        }
        root.listsList[listIndex].items.push({ text: text, done: false });
        root.saveLists();
        root.listsList = root.listsList.slice();
    }

    function removeListItem(listIndex, itemIndex) {
        if (listIndex < 0 || listIndex >= root.listsList.length) {
            return;
        }
        if (itemIndex < 0 || itemIndex >= root.listsList[listIndex].items.length) {
            return;
        }
        root.listsList[listIndex].items.splice(itemIndex, 1);
        root.saveLists();
        root.listsList = root.listsList.slice();
    }

    function toggleListItem(listIndex, itemIndex) {
        if (listIndex < 0 || listIndex >= root.listsList.length) {
            return;
        }
        if (itemIndex < 0 || itemIndex >= root.listsList[listIndex].items.length) {
            return;
        }
        root.listsList[listIndex].items[itemIndex].done = !root.listsList[listIndex].items[itemIndex].done;
        root.saveLists();
        root.listsList = root.listsList.slice();
    }

    function agendaSources() {
        var s = Plasmoid.configuration.agendaSources;
        if (typeof s === "undefined" || s === null) {
            return [];
        }
        return s;
    }

    // Carrega eventos do dia a partir das fontes .ics configuradas.
    function refreshAgenda() {
        var sources = root.agendaSources();
        root.agendaLoading = true;

        if (sources.length === 0) {
            root.agendaEvents = [];
            root.agendaLoading = false;
            return;
        }

        var all = [];
        var pendingCount = sources.length;

        function pendingDone() {
            pendingCount--;
            if (pendingCount <= 0) {
                root.agendaEvents = all;
                root.agendaLoading = false;
            }
        }

        for (var i = 0; i < sources.length; i++) {
            (function(src) {
                var url = String(src).trim();
                if (!url) {
                    pendingDone();
                    return;
                }
                function handleText(text) {
                    try {
                        var evs = Cal.allEvents(text, url);
                        all = all.concat(evs);
                    } catch (e) {
                        console.warn("[yourday] erro parse agenda:", url, String(e));
                    }
                    pendingDone();
                }
                if (/^https?:\/\//i.test(url)) {
                    Cal.loadUrl(url, handleText, function(code) {
                        console.warn("[yourday] agenda falhou fetch:", url, code);
                        pendingDone();
                    });
                } else {
                    // Arquivo local: tenta XHR file:// (pode falhar) e segue.
                    try {
                        Cal.loadUrl("file://" + url, handleText, function(code) {
                            console.warn("[yourday] agenda falhou local:", url, code);
                            pendingDone();
                        });
                    } catch (e) {
                        console.warn("[yourday] agenda local inválida:", url, String(e));
                        pendingDone();
                    }
                }
            })(sources[i]);
        }
    }

    function gotoAgenda() { root.currentTab = 1; }
    function gotoTodos() { root.currentTab = 2; }
    function gotoClima() { root.currentTab = 3; }
    function gotoNotas() { root.currentTab = 4; }
    function gotoNoticias() { root.currentTab = 5; }

    function refreshWeather() {
        var lat = Plasmoid.configuration.weatherLatitude;
        var lon = Plasmoid.configuration.weatherLongitude;
        if (!lat || !lon || lat === 0 || lon === 0) {
            root.weatherData = null;
            return;
        }
        root.weatherLoading = true;
        Weather.fetchWeather(lat, lon,
            function(data) {
                root.weatherData = data;
                root.weatherLoading = false;
                root.refreshAllCitiesWeather();
            },
            function(code) {
                console.warn("[yourday] clima falhou:", code);
                root.weatherLoading = false;
            }
        );
    }

    Component.onCompleted: {
        // Forçar idioma se configurado
        var forcedLang = Plasmoid.configuration.language;
        if (forcedLang && forcedLang !== "") {
            Qt.locale(forcedLang);
        }
        Plasmoid.icon = root.chosenIcon;
        root.loadNewsCache();
        loadAll();
        refreshAgenda();
        parseTodos();
        parseNotes();
        loadLists();
        refreshWeather();
        loadExtraCities();
    }

    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key, value) {
            if (key === "feeds") {
                root.loadAll();
            } else if (key === "maxItems") {
                root.sliceItems();
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
            root.currentTab = Plasmoid.configuration.defaultTab || 0;
            root.loadAll();
            root.refreshAgenda();
            root.parseTodos();
            root.refreshWeather();
        }
    }

    Timer {
        id: refreshTimer
        objectName: "refreshTimer"
        interval: root.refreshMinutesValue > 0 ? root.refreshMinutesValue * 60000 : 0
        repeat: true
        running: root.refreshMinutesValue > 0 && root.currentFeeds().length > 0
        onTriggered: root.loadAll()
    }

    onRefreshMinutesValueChanged: {
        if (refreshTimer.running) {
            refreshTimer.restart();
        } else {
            refreshTimer.start();
        }
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

    // Segurança: se algo travar durante o carregamento, não fica no spinner para sempre.
    Timer {
        id: loadWatchdog
        interval: 30 * 1000
        repeat: false
        onTriggered: {
            root.forceStuck();
        }
    }

    Timer {
        id: hangTimer
        interval: 400
        repeat: true
        running: false
        onTriggered: {
            if (!root.loading) {
                running = false;
                return;
            }
            if (Date.now() >= root.hangDeadline) {
                root.forceStuck();
            }
        }
    }

    Timer {
        id: clockTimer
        interval: 60000
        repeat: true
        running: true
    }

    // ------------------------------------------------------------------- dados

    Component {
        id: newsCardDelegate

        Rectangle {
            id: card
            required property var model

            readonly property bool hovered: cardMouse.containsMouse

            width: root.gridColumnWidth
            height: contentText.implicitHeight + 16
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

                Image {
                    anchors.fill: parent
                    source: card.model.image
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
                        { label: root.t("Resumo"), icon: "view-calendar-day" },
                        { label: root.t("Agenda"), icon: "view-calendar" },
                        { label: root.t("Tarefas"), icon: "task-new" },
                        { label: root.t("Clima"), icon: "weather-clear" },
                        { label: root.t("Notas"), icon: "note" },
                        { label: root.t("Listas"), icon: "view-list" },
                        { label: root.t("Notícias"), icon: root.iconResolvedName }
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
                    onGotoAgenda: root.gotoAgenda()
                    onGotoTodos: root.gotoTodos()
                    onToggleTodoId: function(index) { root.toggleTodo(index); }
                }

                AgendaPage {
                    events: root.agendaEvents
                    loading: root.agendaLoading
                }

                ToDoPage {
                    todos: root.todoList
                    completedTodos: root.completedList
                    onAddTodo: function(text) { root.addTodo(text); }
                    onToggleTodo: function(index) { root.toggleTodo(index); }
                    onRemoveTodo: function(index) { root.removeTodo(index); }
                    onRestoreTodo: function(index) { root.restoreTodo(index); }
                    onRemoveCompletedTodo: function(index) { root.removeCompletedTodo(index); }
                }

                ClimaPage {
                    weatherData: root.weatherData
                    weatherLoading: root.weatherLoading
                    weatherCity: Plasmoid.configuration.weatherCity || ""
                    extraCities: root.extraCities
                    extraWeatherData: root.extraWeatherData
                    selectedCityName: root.selectedCityName
                }

                // Página de Notas
                NotasPage {
                    notes: root.notesList
                    onAddNote: function(text, color) { root.addNote(text, color); }
                    onRemoveNote: function(index) { root.removeNote(index); }
                    onUpdateNoteColor: function(index, color) { root.updateNoteColor(index, color); }
                    onUpdateNoteText: function(index, text) { root.updateNoteText(index, text); }
                }

                // Página de Listas
                ListasPage {
                    lists: root.listsList
                    onAddList: function(name) { root.addList(name); }
                    onRemoveList: function(index) { root.removeList(index); }
                    onAddItem: function(listIndex, text) { root.addListItem(listIndex, text); }
                    onRemoveItem: function(listIndex, itemIndex) { root.removeListItem(listIndex, itemIndex); }
                    onToggleItem: function(listIndex, itemIndex) { root.toggleListItem(listIndex, itemIndex); }
                }

                // Página de Notícias (corpo original das notícias)
                ColumnLayout {
                    id: bodyItem
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Header fixo
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaExtras.Heading {
                            level: 4
                            Layout.fillWidth: true
                            text: root.t("Aqui estão as principais notícias de seu interesse")
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

                    // Corpo rolante
                    Item {
                        id: bodyArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        onWidthChanged: {
                            if (Math.abs(root.bodyWidth - bodyArea.width) > 1) {
                                root.bodyWidth = bodyArea.width;
                            }
                        }
                        Component.onCompleted: root.bodyWidth = bodyArea.width

                        Flickable {
                            id: bodyFlick
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            contentWidth: bodyArea.width
                            contentHeight: Math.max(bodyGrid.height + Kirigami.Units.largeSpacing * 2, bodyArea.height)

                            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                            Grid {
                                id: bodyGrid
                                width: bodyArea.width
                                columns: root.newsColumns
                                flow: Grid.LeftToRight
                                columnSpacing: Kirigami.Units.largeSpacing
                                rowSpacing: Kirigami.Units.smallSpacing
                                anchors.top: parent.top
                                anchors.topMargin: Kirigami.Units.smallSpacing

                                Repeater {
                                    model: root.slicedAll
                                    delegate: newsCardDelegate
                                }
                            }
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