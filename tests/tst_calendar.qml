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

        function test_2000_vevents_semRecorrencia_janelaDe1Mes() {
            // 2000 VEVENTs avulsos espalhados por 2 anos (mês = i%24). Só os
            // de 2026-08/09/10 podem aparecer: um loop ingênuo por ano inteiro
            // traria os ~2000 (e era a regressão do "agenda anos inteiros").
            var evts = [];
            for (var i = 0; i < 2000; i++) {
                var month = String((i % 12) + 1);
                if (month.length < 2) month = "0" + month;
                var day = i % 26 + 1;
                var dayStr = String(day);
                if (dayStr.length < 2) dayStr = "0" + dayStr;
                var year = 2025 + Math.floor((i % 24) / 12);
                evts.push(root.vevent([
                    "UID:f" + i,
                    "DTSTART;VALUE=DATE:" + year + month + dayStr,
                    "SUMMARY:Avulso " + i
                ]));
            }
            var ics = root.wrap(evts);
            var t0 = Date.now();
            var evs = Cal.allEvents(ics, "src", root.fromMs, root.toMs);
            var dt = Date.now() - t0;

            compare(evs.length, 249, "esperava 249 eventos na janela de 1 mês, veio " + evs.length);
            verify(dt < 1000, "parse de 2000 avulsos demorou " + dt + "ms");
            for (var k = 0; k < evs.length; k++) {
                verify(evs[k].end > root.fromMs && evs[k].start < root.toMs, "evento fora da janela vazou");
            }
        }
    }

    TestCase {
        name: "completer"

        function test_gate_readyStatesRepetidos_naoZeramPendingCedo() {
            // Mock do Google Calendar: um handler dispara em vários readyStates
            // intermediários e chama gate.next() em cada um, mas só o DONE é
            // que realmente conclui. O finalize precisa rodar exatamente uma vez.
            var calls = 0;
            var gate = Cal.makeCompleter(1, function() { calls++; });
            gate.next();
            gate.next();
            gate.next();
            compare(calls, 1, "finalize rodou " + calls + " vezes (qualquer coisa != 1 é o bug do pending zerado cedo)");
            verify(gate.isDone(), "gate deveria estar concluído");
            compare(gate.remaining(), 0);
        }

        function test_gate_esperaTodosOsPeers() {
            var calls = [];
            var gate = Cal.makeCompleter(2, function() { calls.push("done"); });
            compare(gate.isDone(), false);
            verify(gate.remaining() === 2, "deveria faltar 2 peers");
            gate.next();
            compare(calls.length, 0, "ainda falta 1 peer, não pode publicar");
            compare(gate.isDone(), false);
            gate.next();
            compare(calls.length, 1);
            // Chamadas extras depois da conclusão são no-ops
            gate.next();
            compare(calls.length, 1, "next() pós-conclusão re-disparou o finalize");
            verify(gate.isDone(), true);
        }

        function test_gate_zero_publicaImediatamente() {
            var calls = [];
            var g0 = Cal.makeCompleter(0, function() { calls.push("x"); });
            compare(calls.length, 1, "sem fontes, finalize roda na construção");
            verify(g0.isDone(), true);
            g0.next();
            compare(calls.length, 1);
        }

        function test_gate_force_publicaMesmoComPeersPendentes() {
            // Watchdog: peer que nunca responde (XHR pendurada) não pode
            // deixar a agenda parada para sempre — force() publica o que há.
            var calls = 0;
            var gate = Cal.makeCompleter(3, function() { calls++; });
            gate.next();
            compare(calls, 0, "2 peers ainda pendentes, não publica");
            verify(!gate.isDone(), "gate ainda pendente após 1 peer");
            compare(gate.force(), true, "force publica e avisa que finalizou");
            compare(calls, 1, "force() finalizou a agenda pendente");
            verify(gate.isDone(), true);
            // Depois do force, o peer lento responde: next() é no-op.
            compare(gate.next(), false);
            compare(calls, 1, "next() pós-force não re-disparou o finalize");
            compare(gate.force(), false, "segundo force é no-op");
            compare(calls, 1);
        }
    }
}