/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Parser e carregador de feeds RSS/Atom usado pelo widget.
    Roda no motor JavaScript do QML (Qt 6). Não depende de DOMParser nem
    de XmlListModel: faz a varredura XML linear (uma passada), pulando
    comentários e CDATA, cobrindo entidades, atributos (href/url) e tags
    de namespace (media:content).
*/

.pragma library

// --------------------------------------------------------------- utilitários

function decodeEntities(s) {
    if (!s) {
        return "";
    }
    return String(s)
        .replace(/&lt;/gi, "<")
        .replace(/&gt;/gi, ">")
        .replace(/&quot;/gi, '"')
        .replace(/&apos;/gi, "'")
        .replace(/&#39;/gi, "'")
        .replace(/&nbsp;/gi, " ")
        .replace(/&amp;/gi, "&");
}

function stripTags(html) {
    if (!html) {
        return "";
    }
    var t = String(html);
    // Separa parágrafos e quebras de linha, depois remove as tags restantes.
    t = t.replace(/<\/(p|div|li|h[1-6])>/gi, " ");
    t = t.replace(/<br\s*\/?>/gi, " ");
    t = t.replace(/<[^>]*>/g, "");
    return decodeEntities(t).replace(/\s+/g, " ").trim();
}

function parseDate(value) {
    if (!value) {
        return 0;
    }
    var str = String(value).trim();
    var t = Date.parse(str);
    if (isNaN(t)) {
        // RFC822 "Wed, 26 Aug 26 08:00:00 GMT": o ano de 2 dígitos vem antes da hora.
        var m = str.match(/^[^\d]*(\d{1,2})\s+([A-Za-z]{3})\s+(\d{2})\s+(\d{2}:\d{2}:\d{2})/);
        if (m) {
            t = Date.parse(m[1] + " " + m[2] + " 20" + m[3] + " " + m[4]);
        }
    }
    return isNaN(t) ? 0 : t;
}

// -------------------------------------------------------------- tokenização
// Scanner linear: uma única passada no texto, pulando comentários e CDATA
// (o parse antigo rescanava o documento inteiro para cada campo — O(n²) na
// thread da UI, era a causa do freeze com feeds grandes).

var MAX_FEED_BYTES = 512000;   // feeds maiores que 512 KB são cortados
var MAX_FEED_ITEMS = 30;       // para o scan no N-ésimo item por feed

// Próxima tag de ABERTURA em [from, to). to < 0 = até o fim.
// Retorna {name, attrs, selfClose, start, end} ou null.
function nextTag(xml, from, to) {
    var i = from;
    var len = to < 0 ? xml.length : Math.min(to, xml.length);
    while (i < len) {
        var lt = xml.indexOf("<", i);
        if (lt === -1 || lt >= len) {
            return null;
        }
        if (xml.slice(lt, lt + 4) === "<!--") {
            var ce = xml.indexOf("-->", lt + 4);
            if (ce === -1 || ce >= len) {
                return null;
            }
            i = ce + 3;
            continue;
        }
        if (xml.slice(lt, lt + 9) === "<![CDATA[") {
            var cd = xml.indexOf("]]>", lt + 9);
            if (cd === -1 || cd >= len) {
                return null;
            }
            i = cd + 3;
            continue;
        }
        var gt = xml.indexOf(">", lt + 1);
        if (gt === -1 || gt >= len) {
            return null;
        }
        if (xml.charCodeAt(lt + 1) === 47) { // tag de fechamento
            i = gt + 1;
            continue;
        }
        var txt = xml.slice(lt + 1, gt);
        var nm = /^\s*([a-zA-Z][\w.:-]*)/.exec(txt);
        if (!nm) {
            i = gt + 1;
            continue;
        }
        return {
            name: nm[1].toLowerCase(),
            attrs: txt.slice(nm[0].length),
            selfClose: txt.charCodeAt(txt.length - 1) === 47,
            start: lt,
            end: gt + 1
        };
    }
    return null;
}

// Index do ">" da tag de fechamento </name> que casa com a abertura corrente
// (profundidade-aware), pulando comentários/CDATA. limit < 0 = até o fim.
function findClose(xml, from, name, limit) {
    var depth = 1;
    var i = from;
    var len = limit < 0 ? xml.length : Math.min(limit, xml.length);
    while (i < len) {
        var lt = xml.indexOf("<", i);
        if (lt === -1 || lt >= len) {
            return -1;
        }
        if (xml.slice(lt, lt + 4) === "<!--") {
            var ce = xml.indexOf("-->", lt + 4);
            if (ce === -1 || ce >= len) {
                return -1;
            }
            i = ce + 3;
            continue;
        }
        if (xml.slice(lt, lt + 9) === "<![CDATA[") {
            var cd = xml.indexOf("]]>", lt + 9);
            if (cd === -1 || cd >= len) {
                return -1;
            }
            i = cd + 3;
            continue;
        }
        var gt = xml.indexOf(">", lt + 1);
        if (gt === -1 || gt >= len) {
            return -1;
        }
        if (xml.charCodeAt(lt + 1) === 47) {
            var cm = /^\s*\/\s*([a-zA-Z][\w.:-]*)/.exec(xml.slice(lt + 1, gt));
            if (cm && cm[1].toLowerCase() === name) {
                depth--;
                if (depth === 0) {
                    return gt;
                }
            }
            i = gt + 1;
            continue;
        }
        var txt = xml.slice(lt + 1, gt);
        if (txt.charCodeAt(txt.length - 1) !== 47) {
            var om = /^\s*([a-zA-Z][\w.:-]*)/.exec(txt);
            if (om && om[1].toLowerCase() === name) {
                depth++;
            }
        }
        i = gt + 1;
    }
    return -1;
}

// Blocos <name> do documento: [{contentStart, contentEnd}]. Para o scan no
// limite de itens (não parseia o feed inteiro na UI thread).
function itemSpans(xml, name, limit) {
    var spans = [];
    var from = 0;
    for (;;) {
        if (spans.length >= limit) {
            break;
        }
        var tag = nextTag(xml, from, -1);
        if (!tag) {
            break;
        }
        if (tag.name === name && !tag.selfClose) {
            var close = findClose(xml, tag.end, name, -1);
            if (close === -1) {
                break;
            }
            spans.push({ contentStart: tag.end, contentEnd: close - name.length - 2 });
            from = close + 1;
            continue;
        }
        from = tag.end;
    }
    return spans;
}

// Primeiro campo <field> dentro de um bloco.
// Retorna {attrs, contentStart, contentEnd, selfClose} ou null.
function child(xml, block, field) {
    var from = block.contentStart;
    var to = block.contentEnd;
    for (;;) {
        var tag = nextTag(xml, from, to);
        if (!tag) {
            break;
        }
        if (tag.name === field) {
            if (tag.selfClose) {
                return { attrs: tag.attrs, contentStart: tag.end, contentEnd: tag.end, selfClose: true };
            }
            var close = findClose(xml, tag.end, field, to);
            if (close === -1) {
                return null;
            }
            return { attrs: tag.attrs, contentStart: tag.end, contentEnd: close - field.length - 2, selfClose: false };
        }
        from = tag.end;
    }
    return null;
}

function childText(xml, block, field) {
    var b = child(xml, block, field);
    if (!b) {
        return "";
    }
    return innerText(xml.slice(b.contentStart, b.contentEnd));
}

function childRaw(xml, block, field) {
    var b = child(xml, block, field);
    if (!b) {
        return "";
    }
    return xml.slice(b.contentStart, b.contentEnd);
}

function attrChild(xml, block, field, attr) {
    var b = child(xml, block, field);
    if (!b) {
        return "";
    }
    return getAttr(b.attrs, attr);
}

function getAttr(raw, name) {
    if (!raw) {
        return "";
    }
    var re = new RegExp("\\b" + name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") +
                        "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]*))", "i");
    var m = re.exec(raw);
    if (!m) {
        return "";
    }
    var val = m[1] !== undefined && m[1] !== null ? m[1]
              : (m[2] !== undefined && m[2] !== null ? m[2] : m[3]);
    return decodeEntities(val);
}

function innerText(content) {
    if (!content) {
        return "";
    }
    var t = String(content).trim();
    // Conteúdo inteiro em CDATA: devolve decodificado, sem tags.
    if (t.indexOf("<![CDATA[") === 0 && t.slice(-3) === "]]>") {
        return decodeEntities(t.slice(9, t.length - 3));
    }
    return stripTags(t);
}

// Limpa o resumo: se estiver inteiro em CDATA, remove o invólucro, tira tags,
// decodifica entidades e limita o tamanho (não renderiza a descrição inteira).
function cleanSummary(raw) {
    var t = String(raw || "");
    var cdata = t.match(/^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/);
    if (cdata) {
        t = cdata[1];
    }
    return stripTags(t).slice(0, 240);
}

function rootName(xml) {
    var clean = String(xml).replace(/^\ufeff/, "").replace(/<!--[\s\S]*?-->/g, "");
    var m = clean.match(/^\s*<\?xml[\s\S]*?\?>\s*<([a-zA-Z][\w.:-]*)/) ||
            clean.match(/^\s*<([a-zA-Z][\w.:-]*)\b/);
    return m ? m[1].toLowerCase() : "";
}

function isAtom(xml) {
    return rootName(xml) === "feed";
}

function isFeed(xml) {
    var r = rootName(xml);
    return r === "feed" || r === "rss" || r === "rdf";
}

function feedSourceName(xml) {
    var doc = { contentStart: 0, contentEnd: xml.length };
    var b = child(xml, doc, "title");
    if (!b) {
        return "";
    }
    var label = innerText(xml.slice(b.contentStart, b.contentEnd)).trim();
    if (label && label.length <= 80) {
        return label;
    }
    return "";
}

// ----------------------------------------------------------- extração e item

function firstImageUrl(xml, block) {
    var names = ["enclosure", "media:content", "media:thumbnail", "thumbnail"];
    for (var n = 0; n < names.length; n++) {
        var b = child(xml, block, names[n]);
        if (!b) {
            continue;
        }
        var url = getAttr(b.attrs, "url") || getAttr(b.attrs, "href");
        if (url) {
            return url;
        }
    }
    return "";
}

function imageFromDescription(descRaw) {
    var m = String(descRaw).match(/<img[^>]*?\ssrc=["']([^"']+)["']/i);
    return m ? m[1] : "";
}

function normalizeItem(title, link, time, source, summary, image) {
    return {
        title: String(title || link || "Sem título").trim(),
        link: String(link || "").trim(),
        source: String(source || "").trim(),
        time: time,
        summary: summary,
        image: image || ""
    };
}

function parseRSSItems(xml, source) {
    var out = [];
    var spans = itemSpans(xml, "item", MAX_FEED_ITEMS);
    for (var k = 0; k < spans.length; k++) {
        var item = spans[k];
        var title = childText(xml, item, "title");
        var link = childText(xml, item, "link");
        if (!link) {
            link = attrChild(xml, item, "link", "href") || attrChild(xml, item, "atom:link", "href");
        }
        if (!link) {
            var g = childText(xml, item, "guid") || childText(xml, item, "id");
            if (/^https?:\/\//.test(g)) {
                link = g;
            }
        }
        if (!title && !link) {
            continue;
        }
        var descRaw = childRaw(xml, item, "description");
        var summary = cleanSummary(descRaw);
        var image = firstImageUrl(xml, item) || imageFromDescription(descRaw);
        out.push(normalizeItem(
            title,
            link,
            parseDate(childText(xml, item, "pubDate") || childText(xml, item, "date")),
            source,
            summary,
            image
        ));
    }
    return out;
}

function parseAtomItems(xml, source) {
    var out = [];
    var spans = itemSpans(xml, "entry", MAX_FEED_ITEMS);
    for (var k = 0; k < spans.length; k++) {
        var entry = spans[k];
        var title = childText(xml, entry, "title");
        var link = attrChild(xml, entry, "link", "href");
        if (!title && !link) {
            continue;
        }
        var updated = childText(xml, entry, "updated") || childText(xml, entry, "published");
        var summary = cleanSummary(childRaw(xml, entry, "summary") || childRaw(xml, entry, "content"));
        var image = firstImageUrl(xml, entry) || imageFromDescription(childRaw(xml, entry, "summary"));
        out.push(normalizeItem(
            title,
            link,
            parseDate(updated),
            source,
            summary,
            image
        ));
    }
    return out;
}

// ---------------------------------------------------------------- carregador

function loadFeed(url, onReady, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.timeout = 15000;
    try {
        xhr.setRequestHeader("User-Agent", "YourDay/1.0");
    } catch (e) { /* alguns contextos proíbem alterar o User-Agent */ }

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) {
            return;
        }
        if (!(xhr.status >= 200 && xhr.status < 300)) {
            onError(xhr.status);
            return;
        }
        var text = xhr.responseText;
        if (text.length > MAX_FEED_BYTES) {
            text = text.slice(0, MAX_FEED_BYTES);
        }
        if (!isFeed(text)) {
            onError(0); // conteúdo não parece RSS/Atom
            return;
        }
        var source = feedSourceName(text);
        var items = isAtom(text) ? parseAtomItems(text, source) : parseRSSItems(text, source);
        onReady(items);
    };
    xhr.onerror = function() {
        onError(-1);
    };
    xhr.ontimeout = function() {
        onError(-2);
    };
    xhr.send(null);
}

// ------------------------------------------------- mesclagem com limites

// Grupos: [{items, cap}]. cap <= 0 = sem limite por feed.
// totalLimit <= 0 = sem limite global. Ordena do mais recente para o mais antigo.
function applyLimits(groups, totalLimit) {
    var out = [];
    for (var g = 0; g < groups.length; g++) {
        var grp = groups[g];
        var n = grp.items.length;
        if (grp.cap > 0 && n > grp.cap) {
            n = grp.cap;
        }
        for (var i = 0; i < n; i++) {
            out.push(grp.items[i]);
        }
    }
    out.sort(function(a, b) { return b.time - a.time; });
    if (totalLimit > 0 && out.length > totalLimit) {
        out.length = totalLimit;
    }
    return out;
}

// ----------------------------------------------------------- tempo relativo

function relativeTime(timestamp, now) {
    if (!timestamp || timestamp <= 0) {
        return "";
    }
    now = now || Date.now();
    var diff = Math.max(0, now - timestamp);
    var min = Math.floor(diff / 60000);
    if (min < 1) {
        return "agora";
    }
    if (min < 60) {
        return "há " + min + " min";
    }
    var h = Math.floor(min / 60);
    if (h < 24) {
        return "há " + h + " h";
    }
    var d = Math.floor(h / 24);
    if (d < 7) {
        return "há " + d + " dias";
    }
    var date = new Date(timestamp);
    var months = ["jan", "fev", "mar", "abr", "mai", "jun",
                  "jul", "ago", "set", "out", "nov", "dez"];
    return date.getDate() + " " + months[date.getMonth()];
}