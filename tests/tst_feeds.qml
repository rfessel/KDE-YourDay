/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Teste de regressão do parser de feeds (feeds.js).
    Rodar:  QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/
    O parser é linear e para no N-ésimo item: parar de rescanear o documento
    inteiro por campo era a causa do freeze do plasmashell na antiga versão.
*/
import QtQuick
import QtTest
import "../plasmoid/contents/ui/js/feeds.js" as FeedParser

Item {
    id: root

    function buildRss(n, descSize) {
        var html = "";
        for (var h = 0; h < descSize; h += 160) {
            html += "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit " + h + "</p>";
        }
        var d = '<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0">' +
                "<channel><title>Canal Teste Gordo</title>";
        for (var i = 0; i < n; i++) {
            d += "<item>" +
                 "<title>Item " + i + "</title>" +
                 "<link>http://exemplo.com/" + i + "</link>" +
                 "<pubDate>Thu, 03 Sep 2026 12:00:00 GMT</pubDate>" +
                 "<description><![CDATA[" + html +
                     "<img src='http://exemplo.com/foto" + i + ".jpg'>" +
                     "<item>FAKE dentro de CDATA</item>" +
                     "</title><link>http://fake</link>" +
                 "]]></description>" +
                 "</item>";
        }
        d += "</channel></rss>";
        return d;
    }

    function mkItems(n, baseDay) {
        var arr = [];
        for (var i = 0; i < n; i++) {
            arr.push({ title: "N" + i, link: "l" + i, time: (baseDay * 24 * 3600000) - i * 1000, source: "x", summary: "", image: "" });
        }
        return arr;
    }

    TestCase {
        name: "bigFeed"

        function test_duzentosItens_cepNoCap_eRapido() {
            var xml = root.buildRss(200, 5000);
            var t0 = Date.now();
            var items = FeedParser.parseRSSItems(xml, "Fonte");
            var dt = Date.now() - t0;

            verify(items.length <= 30, "deveria parar no cap de itens, veio " + items.length);
            verify(items.length > 0, "nenhum item parseado");

            // o <item>/<title> fakes dentro do CDATA não podem contaminar o bloco
            compare(items[0].title, "Item 0");
            compare(items[0].link, "http://exemplo.com/0");
            compare(items[0].source, "Fonte");

            // parse < 50 ms é a meta para um feed de ~1 MB na thread da UI
            verify(dt < 300, "parse de 200 itens demorou " + dt + "ms");
        }

        function test_meioMegabyte_capRecusaSemCongelar() {
            var xml = root.buildRss(200, 3000);
            var sliced = xml.slice(0, 512000);
            var t0 = Date.now();
            var items = FeedParser.parseRSSItems(sliced, "Fonte");
            var dt = Date.now() - t0;
            verify(dt < 300, "parse de 512 KB demorou " + dt + "ms");
            verify(items.length > 0, "feed cortado ainda renderiza itens");
        }

        function test_applyLimits_ordenaAntesDoCap() {
            var groups = [
                { items: root.mkItems(5, 2), cap: 3 },
                { items: root.mkItems(6, 1), cap: 0 }
            ];
            var out = FeedParser.applyLimits(groups, 4);
            verify(out.length <= 4, "limite global ignorado: " + out.length);
            for (var i = 1; i < out.length; i++) {
                verify(out[i - 1].time >= out[i].time, "não ordenou do mais novo para o mais antigo");
            }
        }
    }
}