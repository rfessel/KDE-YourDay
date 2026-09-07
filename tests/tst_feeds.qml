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

            // 200 itens com descrição de 5 KB (~475 KB ao todo) num único
            // scan linear, sem loop: standalone ~15 ms; sob carga do
            // qmltestrunner já veio 52 ms. O teto de 125 ms ainda pega o
            // parser quadrático antigo (que levava segundos) sem flakear.
            verify(dt < 125, "parse de 200 itens demorou " + dt + "ms");
        }

        function test_seiscentosKB_capSemCongelar() {
            // Feed com > 500 KB passado INTEIRO ao parser: a varredura para
            // no N-ésimo <item> (cap), não pode percorrer o documento todo
            // nem entrar em loop.
            var xml = root.buildRss(200, 8000);
            verify(xml.length > 520000, "fixture deveria passar de 520 KB, veio " + xml.length);

            var t0 = Date.now();
            var items = FeedParser.parseRSSItems(xml, "Fonte");
            var dt = Date.now() - t0;
            verify(dt < 300, "parse de ~500 KB demorou " + dt + "ms");
            verify(items.length > 0 && items.length <= 30, "deveria renderizar até 30 itens, veio " + items.length);

            // capFeed (usado pelo loadFeed) corta no teto exato antes do parse
            var capped = FeedParser.capFeed(xml);
            compare(capped.length, FeedParser.MAX_FEED_BYTES);
            var items2 = FeedParser.parseRSSItems(capped, "Fonte");
            verify(items2.length > 0, "feed cortado ainda renderiza itens");
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

        function test_applyLimits_naoDescartaOMaisNovo() {
            // Feed fora de ordem (mais antigo primeiro): o post mais recente
            // está no FIM do array. O cap por feed precisa ficar com os N
            // MAIS NOVOS (ordena antes de cortar), não com os N primeiros
            // crus — senão o post mais relevante some da lista.
            var feat = [
                { title: "velho1", time: 1000 },
                { title: "velho2", time: 2000 },
                { title: "velho3", time: 3000 },
                { title: "novo", time: 99000 }
            ];
            var out = FeedParser.applyLimits([{ items: feat, cap: 3 }], 0);
            compare(out.length, 3);
            compare(out[0].time, 99000, "post mais novo foi descartado pelo cap do feed");
            compare(out[1].time, 3000);
            // totalLimit global continua valendo depois da ordenação
            var out2 = FeedParser.applyLimits([{ items: feat, cap: 3 }], 2);
            compare(out2.length, 2);
            compare(out2[0].time, 99000);
            compare(out2[1].time, 3000);
        }

        function test_newsRefreshState_busyLoopGuard() {
            // refreshMinutes=0 ⇒ desligado. A regressão antiga forçava
            // running=true com intervalo 0 e virava um busy loop.
            var off = FeedParser.newsRefreshState(0, true);
            compare(off.running, false);
            compare(off.interval, 0);

            var on = FeedParser.newsRefreshState(10, true);
            compare(on.running, true);
            compare(on.interval, 600000);

            compare(FeedParser.newsRefreshState(30, false).running, false,
                    "sem feeds não liga o timer, mesmo com minutos > 0");
            compare(FeedParser.newsRefreshState(-5, true).running, false);
            compare(FeedParser.newsRefreshState(NaN, true).running, false);
            compare(FeedParser.newsRefreshState(undefined, true).running, false);
        }

        function test_defaultTab_abreNoticiasNaoListas() {
            compare(FeedParser.clampDefaultTab(6), 6, "defaultTab=6 deve abrir Notícias");
            compare(FeedParser.clampDefaultTab(5), 5);
            compare(FeedParser.clampDefaultTab(0), 0);
            compare(FeedParser.clampDefaultTab(99), 0, "fora do intervalo cai em Resumo, não aponta lista errada");
            compare(FeedParser.clampDefaultTab(-1), 0);
            compare(FeedParser.clampDefaultTab(undefined), 0);
            compare(FeedParser.clampDefaultTab(null), 0);
        }
    }
}