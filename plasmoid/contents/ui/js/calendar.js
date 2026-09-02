/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Camada de dados da agenda/to-dos do widget "Seu Dia...".

    Parser de calendários iCalendar (.ics) — VEVENT — sem dependências
    externas (rodando no motor JS do QML, Qt 6), cobrindo DTSTART/DTEND/
    DURATION, eventos de dia inteiro e recorrência diária simples (RRULE
    FREQ=DAILY com UNTIL). Também expõe a leitura de to-dos locais.

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

// Expande ocorrências de um VEVENT segundo uma recorrência diária simples.
// targetStart/targetEnd = limites (ms) do dia de interesse.
function expandOccurrences(ev, targetStart, targetEnd) {
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

    // Sem recorrência.
    if (!ev.RRULE) {
        if (end > targetStart && start < targetEnd) {
            return [{ title: title, start: start, end: end, allDay: allDay }];
        }
        return [];
    }

    // Recorrência: suporta FREQ=DAILY (com INTERVAL e UNTIL).
    var rrule = String(ev.RRULE).toUpperCase();
    var until = 0;
    var untilM = rrule.match(/UNTIL=([^;\s]+)/);
    if (untilM) {
        until = parseIcsDate(untilM[1]);
    }
    var isDaily = rrule.indexOf("FREQ=DAILY") !== -1;
    if (!isDaily) {
        // Não suportado — retorna só a primeira se cair no dia.
        if (end > targetStart && start < targetEnd) {
            return [{ title: title, start: start, end: end, allDay: allDay }];
        }
        return [];
    }

    var interval = 1;
    var intM = rrule.match(/INTERVAL=(\d+)/);
    if (intM) {
        interval = parseInt(intM[1], 10) || 1;
    }

    // Walk a partir de "start" até cobrir o targetEnd (com teto de segurança).
    var out = [];
    var dur = end - start;
    var step = interval * 86400000;
    var cursor = start;
    var guard = 0;
    while (cursor < targetEnd && guard < 5000) {
        if (start && until && cursor > until + 86400000) {
            break;
        }
        var e = cursor + dur;
        if (e > targetStart && cursor < targetEnd) {
            var evStart = cursor;
            var evEnd = e;
            out.push({
                title: title,
                start: evStart,
                end: evEnd,
                allDay: allDay
            });
        }
        cursor += step;
        guard++;
    }
    return out;
}

// Retorna todos os eventos de uma fonte .ics (sem filtro de data).
function allEvents(text, source) {
    var unfolded = unfold(text);
    var blocks = icsBlocks(unfolded, "VEVENT");
    var out = [];
    for (var i = 0; i < blocks.length; i++) {
        var ev = parseEvent(blocks[i]);
        if (ev) {
            ev.source = source;
            out.push(ev);
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

// ------------------------------------------------------- carregamento

// Baixa uma URL .ics (http/https) via XHR e chama onReady(text) ou onError(código).
function loadUrl(url, onReady, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) {
            return;
        }
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        var text = xhr.responseText;
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
