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

// Extrai abstinência de horário de DTSTART (ms -> HH:MM:SS locais da parte do dia).
function timeOfDayMs(ms) {
    var d = new Date(ms);
    return d.getHours() * 3600000 + d.getMinutes() * 60000 + d.getSeconds() * 1000;
}

// Expande ocorrências de um VEVENT segundo FREQ=DAILY ou FREQ=WEEKLY
// (com INTERVAL, UNTIL e BYDAY). targetStart/targetEnd = janela de interesse.
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
    if (!isDaily && !isWeekly) {
        // Frequência não suportada (MONTHLY/YEARLY etc.): só a primeira se cair na janela.
        if (end > targetStart && start < targetEnd) {
            return [occ(start)];
        }
        return [];
    }

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

    // Weekly (com BYDAY opcional). A semana começa na segunda-feira da semana
    // de DTSTART; cada weekday listado (ou o weekday de DTSTART) ocorre nela.
    var d0 = new Date(start);
    var monday0 = new Date(d0.getFullYear(), d0.getMonth(), d0.getDate() - ((d0.getDay() + 6) % 7), 0, 0, 0, 0).getTime();
    var tod = timeOfDayMs(start);

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
