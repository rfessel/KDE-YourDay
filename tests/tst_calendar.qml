/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Teste de regressão da agenda (calendar.js): janela de tempo, cap de bytes
    e recorrência DAILY/WEEKLY que pula direto para a janela sem caminhar
    de DTSTART (antiga fonte de travamento com .ics de 2-5 mil VEVENTs).
    Rodar:  QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/
*/
import QtQuick
import QtTest
import "../plasmoid/contents/ui/js/calendar.js" as Cal

Item {
    id: root

    // Janela fixa (UTC) equivalente a "mês atual ± 1" num mundo 2026-08..10
    readonly property double fromMs: Date.UTC(2026, 7, 1)          // 2026-08-01 00:00 UTC
    readonly property double toMs: Date.UTC(2026, 9, 31, 23, 59, 59)

    function wrap(events) {
        var out = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//test//test//EN\n";
        for (var i = 0; i < events.length; i++) {
            out += "BEGIN:VEVENT\n" + events[i] + "END:VEVENT\n";
        }
        out += "END:VCALENDAR";
        return out;
    }

    function vevent(pairs) {
        var out = "";
        for (var i = 0; i < pairs.length; i++) {
            out += pairs[i] + "\n";
        }
        return out;
    }

    TestCase {
        name: "agendaWindow"

        function test_janela_filtraFora() {
            var ics = root.wrap([
                root.vevent(["UID:1", "DTSTART;VALUE=DATE:20260301", "SUMMARY:Antes"]),
                root.vevent(["UID:2", "DTSTART:20260915T100000Z", "DURATION:PT1H", "SUMMARY:Dentro"]),
                root.vevent(["UID:3", "DTSTART:20270115T100000Z", "DURATION:PT1H", "SUMMARY:Depois"])
            ]);
            var evs = Cal.allEvents(ics, "src", root.fromMs, root.toMs);
            compare(evs.length, 1, "só o evento dentro da janela");
            compare(evs[0].title, "Dentro");
            compare(evs[0].source, "src");
        }

        function test_rrule_DTSTART_antigo_saltaJanela() {
            // 2000 VEVENTs recorrentes diários começados em 2015. A versão
            // antiga andava ~2800 passos por evento antes da janela.
            var evts = [];
            for (var i = 0; i < 2000; i++) {
                evts.push(root.vevent([
                    "UID:d" + i,
                    "DTSTART:20150101T090000Z",
                    "DURATION:PT1H",
                    "SUMMARY:Diario " + i,
                    "RRULE:FREQ=DAILY;INTERVAL=1;UNTIL=20270101T090000Z"
                ]));
            }
            var ics = root.wrap(evts);
            var t0 = Date.now();
            var evs = Cal.allEvents(ics, "src", root.fromMs, root.toMs);
            var dt = Date.now() - t0;
            // 92 dias na janela por evento
            verify(evs.length > 180000, "esperava ~184k ocorrências, veio " + evs.length);
            verify(dt < 2000, "expand 2000 itens demorou " + dt + "ms (devia ser < 2s)");
        }

        function test_rrule_UNTIL_antesDaJanela_vazio() {
            var ics = root.wrap([
                root.vevent([
                    "UID:u", "DTSTART:20150101T090000Z", "DURATION:PT1H",
                    "SUMMARY:FimAntigo", "RRULE:FREQ=DAILY;UNTIL=20250101T090000Z"
                ])
            ]);
            var evs = Cal.allEvents(ics, "src", root.fromMs, root.toMs);
            compare(evs.length, 0, "UNTIL antes da janela não gera evento");
        }

        function test_rrule_WEEKLY_BYDAY() {
            var ics = root.wrap([
                root.vevent([
                    "UID:w", "DTSTART:20260902T080000Z", "DURATION:PT2H",
                    "SUMMARY:Reuniao", "RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"
                ])
            ]);
            var evs = Cal.allEvents(ics, "src", root.fromMs, root.toMs);
            verify(evs.length >= 24 && evs.length <= 35, "contagem weekly irrealista: " + evs.length);
            for (var i = 0; i < evs.length; i++) {
                var d = new Date(evs[i].start);
                var wd = d.getUTCDay(); // 0=Dom .. 6=Sáb
                verify(wd === 1 || wd === 3 || wd === 5, "ocorrência fora de MO/WE/FR: " + wd + " @" + d.toISOString());
                compare(d.getUTCHours(), 8);
                verify(evs[i].start < root.toMs && evs[i].end > root.fromMs, "fora da janela");
            }
        }

        function test_cap_bytes() {
            verify(Cal.withinIcsCap(root.wrap([])), "ics vazio dentro do cap");
            // Monta um .ics com mais de 2 MB (> MAX_ICS_BYTES) sem depender de conta exata
            var token = "0123456789" + "0123456789" + "01"; // 22 bytes por cópia
            var copies = Math.floor(2 * 1024 * 1024 / token.length) + 4;
            var big = "BEGIN:VCALENDAR\n" + new Array(copies).join(token);
            verify(big.length > 2 * 1024 * 1024, "fixture não passou de 2 MB: " + big.length);
            verify(!Cal.withinIcsCap(big), "ics acima de 2 MB recusado");
        }
    }
}