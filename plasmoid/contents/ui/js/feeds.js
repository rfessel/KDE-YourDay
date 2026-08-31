/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Parser e carregador de feeds RSS/Atom usado pelo widget.
    Roda no motor JavaScript do QML (Qt 6). Não depende de DOMParser nem
    de XmlListModel: faz a varredura XML com tokenização própria, cobrindo
    CDATA, entidades, atributos (href/url) e tags de namespace (media:content).
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

// Captura tags e a string BRUTA de todos os atributos (grupo 3) de uma vez.
var TAG_RE = /<\s*(\/?)\s*([a-zA-Z][\w.:-]*)((?:\s[^\s>=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>=]*))?)*)\s*(\/?)>/g;

function allTags(xml, from) {
    var out = [];
    TAG_RE.lastIndex = from || 0;
    var m;
    while ((m = TAG_RE.exec(xml))) {
        out.push({
            name: m[2].toLowerCase(),
            closing: m[1] === "/",
            selfClose: m[4] === "/",
            start: m.index,
            end: m.index + m[0].length,
            attrs: m[3] || ""
        });
    }
    return out;
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

// Primeiro bloco (abre..fecha, ou tag auto-fechada) de um elemento nomeado.
function firstBlock(xml, name, from) {
    name = name.toLowerCase();
    var tags = allTags(xml, from || 0);
    var found = -1;
    for (var i = 0; i < tags.length; i++) {
        var t = tags[i];
        if (!t.closing && t.name === name) {
            found = i;
            break;
        }
    }
    if (found === -1) {
        return null;
    }
    var open = tags[found];
    if (open.selfClose) {
        return { attrs: open.attrs, contentStart: open.end, contentEnd: open.end, endIndex: open.end };
    }
    var depth = 1;
    for (var j = found + 1; j < tags.length; j++) {
        var tj = tags[j];
        if (tj.name !== name) {
            continue;
        }
        if (tj.closing && !tj.selfClose) {
            depth--;
            if (depth === 0) {
                return {
                    attrs: open.attrs,
                    contentStart: open.end,
                    contentEnd: tj.start, // posição até onde o conteúdo interno vai
                    endIndex: tj.end
                };
            }
        } else if (!tj.closing && !tj.selfClose) {
            depth++;
        }
    }
    // sem par de fechamento: conteúdo vazio
    return { attrs: open.attrs, contentStart: open.end, contentEnd: open.end, endIndex: open.end };
}

function forEach(xml, name, callback) {
    name = name.toLowerCase();
    var from = 0;
    for (;;) {
        var b = firstBlock(xml, name, from);
        if (!b) {
            return;
        }
        callback(b);
        from = b.endIndex;
    }
}

// Conteúdo interno de um campo filho: tira tags e decodifica entidades.
function childText(xml, block, field) {
    var b = firstBlock(xml, field, block.contentStart);
    if (!b || b.contentStart > block.contentEnd) {
        return "";
    }
    return innerText(xml.slice(b.contentStart, b.contentEnd));
}

function childRaw(xml, block, field) {
    var b = firstBlock(xml, field, block.contentStart);
    if (!b || b.contentStart > block.contentEnd) {
        return "";
    }
    return xml.slice(b.contentStart, b.contentEnd);
}

function attrChild(xml, block, field, attr) {
    var b = firstBlock(xml, field, block.contentStart);
    if (!b || b.contentStart > block.contentEnd) {
        return "";
    }
    return getAttr(b.attrs, attr);
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

// Limpa o resumo: se estiver inteiro em CDATA, remove o invólucro
// e depois tira as tags e decodifica as entidades.
function cleanSummary(raw) {
    var t = String(raw || "");
    var cdata = t.match(/^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/);
    if (cdata) {
        t = cdata[1];
    }
    return stripTags(t);
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
    var b = firstBlock(xml, "title", 0);
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
        var b = firstBlock(xml, names[n], block.contentStart);
        if (!b || b.contentStart > block.contentEnd) {
            continue;
        }
        var url = getAttr(b.attrs, "url") || getAttr(b.attrs, "href");
        if (!url) {
            var inner = firstBlock(xml, "img", b.contentStart);
            if (inner && inner.contentStart <= block.contentEnd) {
                url = getAttr(inner.attrs, "src");
            }
        }
        if (url) {
            return url;
        }
    }
    // último recurso: imagem dentro da descrição
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
    forEach(xml, "item", function(item) {
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
            return; // continua o forEach
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
    });
    return out;
}

function parseAtomItems(xml, source) {
    var out = [];
    forEach(xml, "entry", function(entry) {
        var title = childText(xml, entry, "title");
        var link = attrChild(xml, entry, "link", "href");
        if (!title && !link) {
            return;
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
    });
    return out;
}

// ---------------------------------------------------------------- carregador

function loadFeed(url, onReady, onError) {
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