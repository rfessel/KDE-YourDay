/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Camada de dados da agenda/to-dos do widget "Seu Dia...".

    Parser de calendários iCalendar (.ics) — VEVENT — sem dependências
    externas (rodando no motor JS do QML, Qt 6), cobrindo DTSTART/DTEND/
    DURATION, eventos de dia inteiro e recorrência FREQ=DAILY/WEEKLY/
    MONTHLY/YEARLY (com INTERVAL, UNTIL, BYDAY, BYMONTHDAY e BYMONTH).
    Também expõe a leitura de to-dos locais.

    Cada evento retornado tem o formato:
      { title, start (ms), end (ms), allDay (bool), source (string) }
*/

// ------------------------------------------------------------- utilitários

// "lines" em .ics são quebradas (folding): linhas que começam com espaço/tab
// continuam a propriedade anterior.
function unfold(text) {
    return String(text || "")
        .replace(/\r\n/g, "\n")
        .replace(/\r/g, "\n")
        .replace(/\n[ \t]/g, "");
}

// Normaliza um valor .ics (decodifica escapes básicos).
function unescapeIcs(s) {
    return String(s || "")
        .replace(/\\n/gi, "\n")
        .replace(/\\,/g, ",")
        .replace(/\\;/g, ";")
        .replace(/\\\\/g, "\\");
}

// Converte uma data .ics para timestamp (ms). Lida com:
//   DTSTART:20260531T100000Z      (UTC com Z)
//   DTSTART:20260531T100000        (local, sem fuso)
//   DTSTART;VALUE=DATE:20260531   (dia inteiro, data pura)
//   DTSTART:20260531T100000-0300  (fuso explícito)
function parseIcsDate(value) {
    var v = String(value || "").trim();
    if (!v) {
        return 0;
    }
    var m = v.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$/);
    if (m) {
        return new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime();
    }
    var mz = v.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/);
    if (mz) {
        return Date.UTC(+mz[1], +mz[2] - 1, +mz[3], +mz[4], +mz[5], +mz[6]);
    }
    var me = v.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})([+-]\d{2})(\d{2})$/);
    if (me) {
        return Date.UTC(
            +me[1], +me[2] - 1, +me[3], +me[4] - (+me[7]), +me[5] - (+me[8]), +me[6]
        );
    }
    var md = v.match(/^(\d{4})(\d{2})(\d{2})$/);
    if (md) {
        return new Date(+md[1], +md[2] - 1, +md[3], 0, 0, 0).getTime();
    }
    var ts = Date.parse(v.replace("T", " ").replace("Z", " UTC"));
    if (!isNaN(ts)) {
        return ts;
    }
    return 0;
}

// Extrai o valor de uma linha "PROP;PARAMS:value" -> o trecho após o último ":".
function propertyValue(line) {
    var colon = line.indexOf(":");
    if (colon < 0) {
        return "";
    }
    return line.substring(colon + 1);
}

// --------------------------------------------------------- parse de VEVENT

// Extrai um único evento sem expandir recorrências.
function parseEvent(ev) {
    var dtParams = String(ev.DTSTART_PARAMS || "").toUpperCase();
    var allDay = dtParams.indexOf("VALUE=DATE") !== -1;
    var start = parseIcsDate(ev.DTSTART);

    var end;
    if (ev.DTEND) {
        end = parseIcsDate(ev.DTEND);
    } else if (ev.DURATION) {
        var dm = String(ev.DURATION).match(/PT?(\d+D)?(\d+H)?(\d+M)?/i);
        var durMs = 0;
        if (dm) {
            durMs += (dm[1] ? parseInt(dm[1], 10) : 0) * 86400000;
            durMs += (dm[2] ? parseInt(dm[2], 10) : 0) * 3600000;
            durMs += (dm[3] ? parseInt(dm[3], 10) : 0) * 60000;
        }
        end = start + durMs;
    } else {
        end = start + (allDay ? 86400000 : 3600000);
    }

    var title = unescapeIcs(ev.SUMMARY || "(sem título)");
    var description = unescapeIcs(ev.DESCRIPTION || "");
    var location = unescapeIcs(ev.LOCATION || "");
    return { title: title, start: start, end: end, allDay: allDay, description: description, location: location };
}

// Extrai os blocos BEGIN:X ... END:X de uma cadeia de texto já unfolded.
function icsBlocks(text, tag) {
    var out = [];
    var re = new RegExp("BEGIN:" + tag + "([\\s\\S]*?)END:" + tag, "g");
    var m;
    while ((m = re.exec(text)) !== null) {
        var lines = m[1].split("\n");
        var prop = {};
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i].trim();
            if (!ln) {
                continue;
            }
            var eq = ln.indexOf(":");
            if (eq < 0) {
                continue;
            }
            var namePart = ln.substring(0, eq);
            var name = namePart.split(";")[0].toUpperCase();
            var semicolon = namePart.indexOf(";");
            var params = semicolon >= 0 ? namePart.substring(semicolon + 1) : "";
            var val = ln.substring(eq + 1);
            if (prop[name] === undefined) {
                prop[name] = val;
                prop[name + "_PARAMS"] = params;
            } else if (name === "RRULE" || name === "EXDATE" || name === "RDATE") {
                prop[name] += "\n" + val;
            }
        }
        out.push(prop);
    }
    return out;
}

// Extrai abstinência de horário de DTSTART (ms -> HH:MM:SS locais da parte do dia).
function timeOfDayMs(ms) {
    var d = new Date(ms);
    return d.getHours() * 3600000 + d.getMinutes() * 60000 + d.getSeconds() * 1000;
}

// Semana ISO: 1=segunda ... 7=domingo (usada em BYDAY e em nthWeekdayIndex).
var WD_ISO = { MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6, SU: 7 };

// Interpreta BYDAY como lista de { ord, wd } (wd em ISO). "MO" => ord=0 (todos),
// "1MO"/"-1FR" => ordinal (1º / último daquele weekday no período).
function parseByDayEntries(rrule) {
    var m = String(rrule).match(/BYDAY=([A-Z0-9\-,]+)/);
    if (!m) {
        return null;
    }
    var out = [];
    var parts = m[1].split(",");
    for (var i = 0; i < parts.length; i++) {
        var rm = parts[i].trim().match(/^(-?\d+)?([A-Z]{2})$/);
        if (!rm) {
            continue;
        }
        var wd = WD_ISO[rm[2].toUpperCase()];
        if (!wd) {
            continue;
        }
        var ord = rm[1] ? Math.max(-53, Math.min(53, parseInt(rm[1], 10))) : 0;
        out.push({ ord: ord, wd: wd });
    }
    return out.length ? out : null;
}

// Numerico BYMONTHDAY: lista de dias (positivos ou negativos, -1 = último).
function parseByMonthDay(rrule) {
    var m = String(rrule).match(/BYMONTHDAY=([^;\s]+)/);
    if (!m) {
        return null;
    }
    var out = [];
    var parts = m[1].split(",");
    for (var i = 0; i < parts.length; i++) {
        var v = parseInt(parts[i], 10);
        if (v !== 0 && Math.abs(v) <= 31) {
            out.push(v);
        }
    }
    return out.length ? out : null;
}

// BYMONTH: lista de meses 1..12.
function parseByMonth(rrule) {
    var m = String(rrule).match(/BYMONTH=([^;\s]+)/);
    if (!m) {
        return null;
    }
    var out = [];
    var parts = m[1].split(",");
    for (var i = 0; i < parts.length; i++) {
        var v = parseInt(parts[i], 10);
        if (v >= 1 && v <= 12) {
            out.push(v);
        }
    }
    return out.length ? out : null;
}

function daysInMonth(y, m) {
    return new Date(y, m + 1, 0).getDate();
}

// Dia do mês do n-ésimo weekday (wd em ISO). n>0 = 1º/2º/..., n<0 = último(-1)/
// penúltimo(-2)...; retorna 0 se o dia não existir no mês (JS year, month 0-11).
function nthWeekdayIndex(y, m, wd, n) {
    var dim = daysInMonth(y, m);
    var lastDay = new Date(y, m, dim).getDay();
    var lastIso = lastDay === 0 ? 7 : lastDay;
    if (n > 0) {
        var firstDay = new Date(y, m, 1).getDay();
        var firstIso = firstDay === 0 ? 7 : firstDay;
        var day = 1 + ((wd - firstIso + 7) % 7) + (n - 1) * 7;
        return day <= dim ? day : 0;
    }
    var dayB = dim - ((lastIso - wd + 7) % 7) - (Math.abs(n) - 1) * 7;
    return dayB >= 1 ? dayB : 0;
}

// Dias do mês em que a recorrência pode cair para FREQ=MONTHLY/YEARLY:
// por BYMONTHDAY, por BYDAY (com ordinal = n-ésimo weekday, sem ordinal =
// todos os daquele weekday no mês) ou o dia padrão de DTSTART. Dias que não
// existem no mês viram 0 (pular).
function monthCandidateDays(y, m, byMonthDay, byDay, dtStartDay) {
    var dim = daysInMonth(y, m);
    var out = [];
    var i, d;
    if (byDay) {
        for (i = 0; i < byDay.length; i++) {
            var e = byDay[i];
            if (e.ord !== 0) {
                var day = nthWeekdayIndex(y, m, e.wd, e.ord);
                if (day) {
                    out.push(day);
                }
            } else {
                for (d = 1; d <= dim; d++) {
                    var iso = ((new Date(y, m, d).getDay() + 6) % 7) + 1;
                    if (iso === e.wd) {
                        out.push(d);
                    }
                }
            }
        }
    } else if (byMonthDay) {
        for (i = 0; i < byMonthDay.length; i++) {
            var v = byMonthDay[i];
            var dn = v > 0 ? v : dim + 1 + v;
            if (dn >= 1 && dn <= dim) {
                out.push(dn);
            } else {
                out.push(0);
            }
        }
    } else {
        out.push(dtStartDay <= dim ? dtStartDay : 0);
    }
    return out;
}

// Expande FREQ=MONTHLY (com INTERVAL/UNTIL/BYMONTHDAY/BYDAY). Anda por blocos
// de mês alinhados a partir do mês de DTSTART; pula direto para o bloco que
// toca a janela (guard: 1024 blocos por evento).
function expandMonthly(start, tod, dur, occ, until, interval, targetStart, targetEnd, ev, rrule) {
    var d0 = new Date(start);
    var byMonthDay = parseByMonthDay(rrule);
    var byDay = parseByDayEntries(rrule);
    var startIdx = d0.getFullYear() * 12 + d0.getMonth();
    var win0 = new Date(targetStart).getFullYear() * 12 + new Date(targetStart).getMonth();
    var win1 = new Date(targetEnd).getFullYear() * 12 + new Date(targetEnd).getMonth();
    var step = Math.max(1, interval);
    var idx = startIdx + Math.floor((win0 - startIdx) / step) * step;
    var out = [];
    var guard = 0;
    while (idx <= win1 && guard < 1024) {
        var y = Math.floor(idx / 12);
        var m = idx % 12;
        var days = monthCandidateDays(y, m, byMonthDay, byDay, d0.getDate());
        for (var i = 0; i < days.length; i++) {
            if (!days[i]) {
                continue;
            }
            var occStart = new Date(y, m, days[i]).getTime() + tod;
            if (until && occStart > until + 86400000) {
                continue;
            }
            if (occStart >= targetEnd) {
                continue;
            }
            if (occStart + dur > targetStart) {
                out.push(occ(occStart));
            }
        }
        idx += step;
        guard++;
    }
    return out;
}

// Expande FREQ=YEARLY (com INTERVAL/UNTIL/BYMONTH/BYMONTHDAY/BYDAY). Anda por
// anos; dentro do ano, expande cada BYMONTH.
function expandYearly(start, tod, dur, occ, until, interval, targetStart, targetEnd, ev, rrule) {
    var d0 = new Date(start);
    var byMonth = parseByMonth(rrule);
    var byMonthDay = parseByMonthDay(rrule);
    var byDay = parseByDayEntries(rrule);
    var months = byMonth || [d0.getMonth() + 1];
    var startYr = d0.getFullYear();
    var win0 = new Date(targetStart).getFullYear();
    var win1 = new Date(targetEnd).getFullYear();
    var stepYr = Math.max(1, interval);
    var yr = startYr + Math.floor((win0 - startYr) / stepYr) * stepYr;
    var out = [];
    var guard = 0;
    while (yr <= win1 && guard < 1024) {
        for (var mi = 0; mi < months.length; mi++) {
            var m = months[mi] - 1;
            var days = monthCandidateDays(yr, m, byMonthDay, byDay, d0.getDate());
            for (var i = 0; i < days.length; i++) {
                if (!days[i]) {
                    continue;
                }
                var occStart = new Date(yr, m, days[i]).getTime() + tod;
                if (until && occStart > until + 86400000) {
                    continue;
                }
                if (occStart >= targetEnd) {
                    continue;
                }
                if (occStart + dur > targetStart) {
                    out.push(occ(occStart));
                }
            }
        }
        yr += stepYr;
        guard++;
    }
    return out;
}

// Expande ocorrências de um VEVENT segundo FREQ=DAILY, FREQ=WEEKLY,
// FREQ=MONTHLY ou FREQ=YEARLY (com INTERVAL, UNTIL, BYDAY, BYMONTHDAY e
// BYMONTH). targetStart/targetEnd = janela de interesse.
// Em vez de caminhar dia a dia de DTSTART até a janela (que travava para
// recorrências antigas: até 5000 passos no vazio por evento), dá um salto
// direto para a primeira ocorrência dentro da janela e caminha só o trecho
// visível (guard: 1024 ocorrências por evento, teto holandês).
function expandOccurrences(ev, targetStart, targetEnd) {
    var dtParams = String(ev.DTSTART_PARAMS || "").toUpperCase();
    var allDay = dtParams.indexOf("VALUE=DATE") !== -1;
    var start = parseIcsDate(ev.DTSTART);
    if (!start) {
        return [];
    }

    var end;
    if (ev.DTEND) {
        end = parseIcsDate(ev.DTEND);
    } else if (ev.DURATION) {
        var dm = String(ev.DURATION).match(/PT?(\d+D)?(\d+H)?(\d+M)?/i);
        var durMs = 0;
        if (dm) {
            durMs += (dm[1] ? parseInt(dm[1], 10) : 0) * 86400000;
            durMs += (dm[2] ? parseInt(dm[2], 10) : 0) * 3600000;
            durMs += (dm[3] ? parseInt(dm[3], 10) : 0) * 60000;
        }
        end = start + durMs;
    } else {
        end = start + (allDay ? 86400000 : 3600000);
    }

    var dur = end - start;
    var title = unescapeIcs(ev.SUMMARY || "(sem título)");
    var description = unescapeIcs(ev.DESCRIPTION || "");
    var location = unescapeIcs(ev.LOCATION || "");

    function occ(cursor) {
        return {
            title: title,
            start: cursor,
            end: cursor + dur,
            allDay: allDay,
            description: description,
            location: location
        };
    }

    // Sem recorrência.
    if (!ev.RRULE) {
        if (end > targetStart && start < targetEnd) {
            return [occ(start)];
        }
        return [];
    }

    var rrule = String(ev.RRULE).toUpperCase();
    var until = 0;
    var untilM = rrule.match(/UNTIL=([^;\s]+)/);
    if (untilM) {
        until = parseIcsDate(untilM[1]);
    }

    var interval = 1;
    var intM = rrule.match(/INTERVAL=(\d+)/);
    if (intM) {
        interval = parseInt(intM[1], 10) || 1;
    }

    var isDaily = rrule.indexOf("FREQ=DAILY") !== -1;
    var isWeekly = rrule.indexOf("FREQ=WEEKLY") !== -1;
    var isMonthly = rrule.indexOf("FREQ=MONTHLY") !== -1;
    var isYearly = rrule.indexOf("FREQ=YEARLY") !== -1;
    if (!isDaily && !isWeekly && !isMonthly && !isYearly) {
        // Frequência não suportada (HOURLY/MINUTELY/SECONDLY etc.): só a
        // primeira se cair na janela.
        if (end > targetStart && start < targetEnd) {
            return [occ(start)];
        }
        return [];
    }

    var tod = timeOfDayMs(start);

    var out = [];
    var guard = 0;
    var dayNm = { MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6, SU: 7 };

    if (isDaily) {
        var step = interval * 86400000;
        var cursor = start;
        if (start < targetStart && step > 0) {
            cursor = start + Math.ceil((targetStart - start) / step) * step;
        }
        while (cursor < targetEnd && guard < 1024) {
            if (until && cursor > until + 86400000) {
                break;
            }
            if (cursor + dur > targetStart) {
                out.push(occ(cursor));
            }
            cursor += step;
            guard++;
        }
        return out;
    }

    if (isWeekly) {
        // Weekly (com BYDAY opcional). A semana começa na segunda-feira da
        // semana de DTSTART; cada weekday listado (ou o weekday de DTSTART)
        // ocorre nela.
        var d0 = new Date(start);
        var monday0 = new Date(d0.getFullYear(), d0.getMonth(), d0.getDate() - ((d0.getDay() + 6) % 7), 0, 0, 0, 0).getTime();

        var byday = [];
        var bm = rrule.match(/BYDAY=([A-Z]{2}(?:,[A-Z]{2})*)/);
        if (bm) {
            var partsIo = bm[1].split(",");
            for (var bi = 0; bi < partsIo.length; bi++) {
                var iso = dayNm[partsIo[bi]];
                if (iso) {
                    byday.push(iso);
                }
            }
        }
        if (byday.length === 0) {
            byday.push(((d0.getDay() + 6) % 7) + 1);
        }
        byday.sort(function(a, b) { return a - b; });

        var wstep = interval * 7 * 86400000;
        var wstart = monday0;
        if (wstart < targetStart && wstep > 0) {
            wstart = monday0 + Math.floor((targetStart - monday0) / wstep) * wstep;
        }
        while (wstart < targetEnd && guard < 1024) {
            for (var wi = 0; wi < byday.length; wi++) {
                var occStart = wstart + (byday[wi] - 1) * 86400000 + tod;
                var occEnd = occStart + dur;
                if (until && occStart > until + 86400000) {
                    continue;
                }
                if (occStart >= targetEnd) {
                    continue;
                }
                if (occEnd > targetStart) {
                    out.push(occ(occStart));
                }
            }
            wstart += wstep;
            guard++;
        }
        out.sort(function(a, b) { return a.start - b.start; });
        return out;
    }

    if (isMonthly) {
        out = expandMonthly(start, tod, dur, occ, until, interval, targetStart, targetEnd, ev, rrule);
        out.sort(function(a, b) { return a.start - b.start; });
        return out;
    }

    out = expandYearly(start, tod, dur, occ, until, interval, targetStart, targetEnd, ev, rrule);
    out.sort(function(a, b) { return a.start - b.start; });
    return out;
}

// Retorna os eventos de uma fonte .ics que caem na janela [fromMs, toMs].
// without fromMs/toMs (callers antigos), retorna tudo (janela infinita).
function allEvents(text, source, fromMs, toMs) {
    var f = (typeof fromMs === "number") ? fromMs : 0;
    var t = (typeof toMs === "number") ? toMs : Number.MAX_SAFE_INTEGER;
    if (t < f) {
        var swap = f;
        f = t;
        t = swap;
    }
    var unfolded = unfold(text);
    var blocks = icsBlocks(unfolded, "VEVENT");
    var out = [];
    for (var i = 0; i < blocks.length; i++) {
        var evs = expandOccurrences(blocks[i], f, t);
        for (var j = 0; j < evs.length; j++) {
            evs[j].source = source;
            out.push(evs[j]);
        }
    }
    out.sort(function(a, b) { return (a.start - b.start) || (a.title < b.title ? -1 : 1); });
    return out;
}

// Dash de todos os eventos de uma fonte .ics que caem no dia [start,end].
function eventsForDay(text, start, end, source) {
    var unfolded = unfold(text);
    var blocks = icsBlocks(unfolded, "VEVENT");
    var out = [];
    for (var i = 0; i < blocks.length; i++) {
        var evs = expandOccurrences(blocks[i], start, end);
        for (var j = 0; j < evs.length; j++) {
            evs[j].source = source;
            out.push(evs[j]);
        }
    }
    out.sort(function(a, b) { return (a.start - b.start) || (a.title < b.title ? -1 : 1); });
    return out;
}

// Marcadores de início/fim do dia (local) de uma data.
function dayRange(now) {
    var d = new Date(now);
    var start = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime();
    var end = start + 86400000;
    return { start: start, end: end };
}

// Formata um horário "HH:MM" a partir de timestamp. allDay rende string vazia.
function formatTime(ms, allDay) {
    if (allDay) {
        return "";
    }
    var d = new Date(ms);
    var h = d.getHours();
    var m = d.getMinutes();
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
}

// ----------------------------------------------------------------- fluxo async

// Portão de conclusão exatamente-uma-vez, usado pelo refreshAgenda do widget
// para contar XHRs (fontes .ics + calendários Google).
//
// A regra de negócio protegida (bug recorrente): um handler que dispara em
// vários readyStates intermediários NÃO pode "zerar o pending" antes da hora
// e publicar a agenda incompleta. Aqui, mesmo que um caller chame next()
// repetidas vezes depois de concluir, o finalize() roda exatamente uma vez
// (fired) — e, se o total começa em 0, o finalize dispara imediatamente, que
// é o caso "sem fontes": agenda só com os eventos locais.
function makeCompleter(count, finalize) {
    var left = Math.max(0, count | 0);
    var fired = false;
    var gate = {
        next: function() {
            if (fired) {
                return false;
            }
            left--;
            if (left <= 0) {
                fired = true;
                if (typeof finalize === "function") {
                    finalize();
                }
            }
            return true;
        },
        // Watchdog: força o finalize mesmo com peers pendentes (XHR que nunca
        // responde não pode deixar a agenda vazia para sempre).
        force: function() {
            if (fired) {
                return false;
            }
            fired = true;
            if (typeof finalize === "function") {
                finalize();
            }
            return true;
        },
        isDone: function() {
            return fired;
        },
        remaining: function() {
            return left;
        }
    };
    if (left === 0 && typeof finalize === "function") {
        fired = true;
        finalize();
    }
    return gate;
}

// ------------------------------------------------------- carregamento

// Teto de bytes para arquivos .ics: acima disso a fonte é recusada (a thread
// da UI não pode engasgar num PDF gigante baixado como texto).
var MAX_ICS_BYTES = 2 * 1024 * 1024;

function withinIcsCap(text) {
    return String(text || "").length <= MAX_ICS_BYTES;
}

// Baixa uma URL .ics (http/https) via XHR e chama onReady(text) ou onError(código).
function loadUrl(url, onReady, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.timeout = 10000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) {
            return;
        }
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        var text = xhr.responseText;
        if (!withinIcsCap(text)) {
            onError(-3);
            return;
        }
        if (!text || text.indexOf("BEGIN:VCALENDAR") === -1) {
            onError(0);
            return;
        }
        onReady(text);
    };
    xhr.onerror = function() { onError(-1); };
    xhr.ontimeout = function() { onError(-2); };
    xhr.send(null);
}

// Verifica se o texto parece um arquivo .ics.
function looksLikeIcs(text) {
    return String(text || "").indexOf("BEGIN:VCALENDAR") !== -1;
}
