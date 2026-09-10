/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Teste de interface: a barra de rolagem vertical do QQC2 é desenhada POR
    CIMA do conteúdo por padrão. Se o conteúdo não reservar espaço à direita
    (gutter igual à largura da barra), cards/texto ficam escondidos sob ela.

    Cada página é instanciada pequena (360x420) com dados o suficiente para
    estourar o viewport; então verificamos que, para TODOS os Flickable/ListView
    com barra vertical visível, o conteúdo termina antes da barra
    (maxRight <= width - bar.width + 0.5) — ou seja, sem sobreposição.

    Rodar: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/
*/
import QtQuick
import QtQuick.Controls
import QtTest

Item {
    id: root
    width: 1400
    height: 900

    // ---- ambiente mínimo que as páginas esperam do main.qml (id `root`) ----
    property int clockTick: 0
    property bool isDarkTheme: false
    property color accentMain: Qt.rgba(0.15, 0.5, 0.85, 1)
    property color accentSoft: Qt.rgba(0.15, 0.5, 0.85, 0.12)
    property color accentBorder: Qt.rgba(0.15, 0.5, 0.85, 0.5)
    property color textMain: Qt.rgba(0.13, 0.13, 0.13, 1)
    property color textSubtle: Qt.rgba(0.13, 0.13, 0.13, 0.6)
    property var selectedCityName: ""
    function refreshWeather() {}

    // ---- ambiente extra só da página de Notícias (NewsPage lê do `root`) ----
    property var slicedAll: []
    property bool loading: false
    property string lastUpdated: ""
    property string errorText: ""
    property int headlineLines: 2
    property var iconResolvedName: ""
    property var iconResolvedSource: ""
    function currentFeeds() { return []; }
    function loadAll() {}
    function openConfig() {}

    // local onde as páginas são instanciadas (mantém o root de teste limpo)
    Item { id: holder; anchors.fill: parent }

    property var components: ({})
    function pageComponent(name) {
        if (!components[name]) {
            components[name] = Qt.createComponent("../plasmoid/contents/ui/pages/" + name + ".qml");
        }
        return components[name];
    }

    function createPage(name, props) {
        var comp = pageComponent(name);
        if (comp.status !== Component.Ready) {
            throw "component " + name + " not ready: " + comp.errorString();
        }
        var item = comp.createObject(holder, props);
        if (!item) {
            throw "failed to create " + name + ": " + comp.errorString();
        }
        item.visible = true;
        return item;
    }

    // ---------------- dados de enchimento ----------------
    function makeTodos(n) {
        var arr = [];
        for (var i = 0; i < n; i++) {
            arr.push({ text: "Tarefa " + i + " com cabo comprido para envolver e estourar o viewport de teste", done: false, createdAt: Date.now(), dueDate: Date.now() + 24 * 3600000 });
        }
        return arr;
    }

    function makeEvents(n) {
        var arr = [];
        var base = new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate(), 9, 0, 0, 0).getTime();
        for (var i = 0; i < n; i++) {
            arr.push({ title: "Compromisso " + i + " com descrição longa o bastante para ocupar várias linhas do card", start: base + i * 3600000, end: base + (i + 1) * 3600000, allDay: false, description: "", location: "", source: "local", id: "e" + i, googleId: null, color: "#4285f4" });
        }
        return arr;
    }

    function makeNotes(n) {
        var arr = [];
        for (var i = 0; i < n; i++) {
            arr.push({ text: "Anotação " + i + " com texto de post-it grande o bastante para enrolar o grid", color: "#FFF9C4" });
        }
        return arr;
    }

    function makeItemsModel(n) {
        var m = Qt.createQmlObject("import QtQuick; ListModel {}", root, "lm" + Math.random().toString(36).slice(2, 8));
        for (var i = 0; i < n; i++) {
            m.append({ text: "item " + i, done: false, id: "i" + i });
        }
        return m;
    }

    function makeLists(n, done) {
        var arr = [];
        for (var i = 0; i < n; i++) {
            arr.push({ name: "Lista " + i + " de compras do mês", done: done, id: "l" + i, itemsModel: makeItemsModel(6) });
        }
        return arr;
    }

    function makeWeather() {
        var days = [];
        for (var i = 0; i < 7; i++) {
            days.push({ date: "2026-09-0" + (i + 1), code: 1, maxTemp: 26 + i, minTemp: 15, rainChance: 20 + i * 5 });
        }
        return {
            temp: 22, maxTemp: 28, minTemp: 16, humidity: 62, rainChance: 30,
            windSpeed: 9, sunrise: "06:10", sunset: "18:05", code: 1, isNight: false,
            rain: 0, showers: 0, days: days
        };
    }

    // ---------------- verificador de sobreposição ----------------
    function isScrollBarObject(o) {
        return o && String(o).indexOf("ScrollBar") >= 0;
    }

    // Primeiro filho descendente visível que é uma ScrollBar vertical do flk.
    function findVisibleVBar(flk) {
        var kids = flk.data ? flk.data : [];
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i];
            if (isScrollBarObject(c) && c.visible && c.height > c.width && c.width > 0) {
                return c;
            }
        }
        return null;
    }

    // Borda direita (em coords do flk) da borda do conteúdo declarado.
    function contentMaxRight(flk) {
        var m = -100000;
        var kids = flk.contentItem ? flk.contentItem.children : [];
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i];
            if (!c.visible) continue;
            var p = c.mapToItem(flk, c.width, 0);
            if (p.x > m) m = p.x;
        }
        return m;
    }

    // Coleta todos os Flickable/ListView (sem controles com contentItem).
    function collectFlickables(pageItem, out) {
        var data = pageItem.data ? pageItem.data : [];
        for (var i = 0; i < data.length; i++) {
            var c = data[i];
            if (!c) continue;
            if (isScrollBarObject(c)) {
                continue; // conteúdo interno da barra não interessa
            }
            if (c.contentX !== undefined && c.contentItem !== null) {
                out.push(c);
            }
            if (c.data) {
                collectFlickables(c, out);
            }
        }
    }

    function waitForScrollbars(pageItem, test) {
        var deadline = Date.now() + 2000;
        var found = false;
        while (Date.now() < deadline) {
            var flicks = [];
            collectFlickables(pageItem, flicks);
            found = false;
            for (var i = 0; i < flicks.length; i++) {
                var bar = findVisibleVBar(flicks[i]);
                if (bar) { found = true; break; }
            }
            if (found) {
                test.wait(30);
                return true;
            }
            test.wait(30);
        }
        return false;
    }

    function assertNoScrollbarOverlap(pageItem, label, test) {
        // 1) precisamos de fato rolar: pelo menos uma barra vertical visível.
        var hasOverflow = waitForScrollbars(pageItem, test);
        test.verify(hasOverflow, label + ": esperava conteúdo excedendo o viewport (barra de rolagem visível)");
        // Deixa os bindings de largura dos delegates/colunas estabilizarem
        // depois que a barra aparece (a largura é reavaliada via `visible`).
        test.wait(250);

        var flicks = [];
        collectFlickables(pageItem, flicks);
        var checked = 0;
        for (var i = 0; i < flicks.length; i++) {
            var flk = flicks[i];
            var bar = findVisibleVBar(flk);
            if (!bar) continue;
            // só testa vistas realmente roláveis e com barra aparecendo.
            var maxRight = contentMaxRight(flk);
            var allowed = flk.width - bar.width + 0.5;
            test.verify(maxRight <= allowed,
                label + ": conteúdo sobrepõe a barra de rolagem (" + String(flk).split("(")[0]
                + " maxRight=" + Math.round(maxRight * 10) / 10
                + " > permitido=" + Math.round(allowed * 10) / 10 + ")");
            test.verify(maxRight <= flk.width,
                label + ": conteúdo invadiu o gutter do scrollbar");
            // A barra deve estar encostada na borda direita do viewport
            // (não flutuando longe do canto do widget).
            var barRight = bar.x + bar.width;
            test.verify(Math.abs(barRight - flk.width) < 0.5,
                label + ": barra não está encostada na borda direita (barRight="
                + Math.round(barRight * 10) / 10 + " vs flk.width=" + flk.width + ")");
            checked++;
        }
        test.verify(checked > 0, label + ": nenhum Flickable com barra visível foi analisado");
    }

    // Caso modelo: padrão usado pelas páginas (Flickable + ScrollBar + gutter).
    // Precisa estar visível para a barra entrar em AsNeeded e medir geometricamente.
    Flickable {
        id: sampleFlick
        width: 360
        height: 420
        clip: true
        contentHeight: sampleCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            id: sampleBar
            policy: ScrollBar.AsNeeded
        }
        Column {
            id: sampleCol
            width: parent.width - (sampleBar.visible ? sampleBar.width : 0)
            Repeater {
                model: 40
                Rectangle { width: 200; height: 40; color: "lightgray" }
            }
        }
    }

    // Coleta todos os cabeçalhos PageHeader (RowLayout com objectName
    // "pageHeaderRow") de uma página — deve haver exatamente um por página.
    function collectHeaders(pageItem, out) {
        var data = pageItem.data ? pageItem.data : [];
        for (var i = 0; i < data.length; i++) {
            var c = data[i];
            if (!c) continue;
            if (c.objectName === "pageHeaderRow") out.push(c);
            if (c.data) collectHeaders(c, out);
        }
    }

    TestCase {
        name: "scrollbarOverlap"
        when: windowShown
        id: tcase

        function test_padrao_flickable_reserva_gutter() {
            // conteúdo longo + barra visível + gutter respeitado
            wait(120);
            verify(sampleFlick.contentHeight > sampleFlick.height, "content overflow esperado")
            wait(100);
            verify(sampleBar.visible, "barra deve ficar visível")
            compare(sampleCol.width, sampleFlick.width - sampleBar.width,
                    "coluna deve terminar antes da barra")
            var mr = contentMaxRight(sampleFlick);
            verify(mr <= sampleFlick.width - sampleBar.width + 0.5, "sem sobreposição no padrão")
        }

        function test_notas_nao_sobrepoe() {
            var page = createPage("NotasPage", { width: 360, height: 420, notes: makeNotes(30) });
            assertNoScrollbarOverlap(page, "Notas", tcase);
            verify(page.scrollGutter > 0, "Notas: gutter calculado (>0)");
        }

        function test_todos_nao_sobrepoe() {
            var page = createPage("ToDoPage", { width: 360, height: 420, todos: makeTodos(25), completedTodos: makeTodos(12), showHistory: true });
            assertNoScrollbarOverlap(page, "Tarefas", tcase);
            verify(page.scrollGutter > 0, "Tarefas: gutter calculado (>0)");
        }

        function test_clima_nao_sobrepoe() {
            var page = createPage("ClimaPage", {
                width: 360, height: 420, weatherData: makeWeather(), weatherLoading: false,
                weatherCity: "Campinas", extraCities: [], extraWeatherData: ({}), selectedCityName: ""
            });
            assertNoScrollbarOverlap(page, "Clima", tcase);
            verify(page.scrollGutter > 0, "Clima: gutter calculado (>0)");
        }

        function test_clima_horas_visivel() {
            var w = makeWeather();
            var base = new Date();
            base.setMinutes(0, 0, 0);
            var hours = [];
            for (var i = 1; i <= 8; i++) {
                var t = new Date(base.getTime() + i * 3600000);
                hours.push({
                    time: t.toISOString(), temp: 22 + i,
                    code: i % 2 === 0 ? 2 : 61, rainChance: i * 10
                });
            }
            w.hours = hours;
            var page = createPage("ClimaPage", {
                width: 360, height: 800, weatherData: w, weatherLoading: false,
                weatherCity: "Campinas", extraCities: [], extraWeatherData: ({}), selectedCityName: ""
            });
            verify(page.chartPoints.length >= 6, "chartPoints >= 6, tem " + page.chartPoints.length);
            assertNoScrollbarOverlap(page, "Clima horas", tcase);
        }

        function test_resumo_nao_sobrepoe() {
            var page = createPage("ResumoPage", {
                width: 360, height: 420,
                events: makeEvents(20), todos: makeTodos(18), loading: false,
                weatherData: null, weatherLoading: false, weatherCity: ""
            });
            assertNoScrollbarOverlap(page, "Resumo", tcase);
            verify(page.scrollGutter > 0, "Resumo: gutter calculado (>0)");
        }

        function test_agenda_nao_sobrepoe() {
            var page = createPage("AgendaPage", {
                width: 360, height: 420, events: makeEvents(30), loading: false, notice: ""
            });
            assertNoScrollbarOverlap(page, "Agenda", tcase);
        }

        function test_listas_nao_sobrepoe() {
            var page = createPage("ListasPage", {
                width: 360, height: 420,
                lists: makeLists(14, false).concat(makeLists(3, true)),
                expandedList: -1, showHistory: false
            });
            page.showHistory = true;
            assertNoScrollbarOverlap(page, "Listas", tcase);
        }

        function test_headers_fixos_48px() {
            var cases = [
                { name: "AgendaPage", props: { width: 360, height: 420, events: makeEvents(3), loading: false, notice: "" } },
                { name: "ToDoPage", props: { width: 360, height: 420, todos: makeTodos(5), completedTodos: makeTodos(3), showHistory: true } },
                { name: "ClimaPage", props: { width: 360, height: 420, weatherData: makeWeather(), weatherLoading: false, weatherCity: "Campinas", extraCities: [], extraWeatherData: ({}), selectedCityName: "" } },
                { name: "NotasPage", props: { width: 360, height: 420, notes: makeNotes(5) } },
                { name: "ListasPage", props: { width: 360, height: 420, lists: makeLists(3, false), expandedList: -1, showHistory: false } },
                { name: "ResumoPage", props: { width: 360, height: 420, events: makeEvents(3), todos: makeTodos(3), loading: false, weatherData: null, weatherLoading: false, weatherCity: "" } },
                { name: "NewsPage", props: { width: 360, height: 420 } }
            ];
            for (var i = 0; i < cases.length; i++) {
                var c = cases[i];
                var page = createPage(c.name, c.props);
                var rows = [];
                collectHeaders(page, rows);
                compare(rows.length, 1, c.name + ": exatamente 1 PageHeader");
                compare(rows[0].height, 48, c.name + ": altura fixa do header === 48 px");
                page.destroy();
            }
        }
    }
}