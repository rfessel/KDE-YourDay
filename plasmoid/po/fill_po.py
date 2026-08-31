#!/usr/bin/env python3
"""Aplica as traduções de translations.py em um po/<lang>.po.
Uso: python3 fill_po.py <lang>   (ex.: python3 fill_po.py es)
Lida com msgids/msgstrs quebrados em várias linhas pelo gettext.
"""

import os, re, sys

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)

from translations import TRANS


def decode(s):
    return (s.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\'))


def encode(s):
    return (s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n'))


def parse(text):
    """Retorna lista de entradas: dict(msgid, msgstr, mparts, sparts, start).
    msgid/msgstr são as formas decodificadas (sem escapes gettext)."""
    lines = text.split('\n')
    entries, cur = [], None
    for idx, line in enumerate(lines):
        if line.startswith('msgid '):
            if cur:
                entries.append(cur)
            cur = {'msgid': '', 'mparts': [], 'str': '', 'sparts': [], 'start': idx}
            raw = line[6:].strip()
            if raw.startswith('"') and raw.endswith('"'):
                cur['mparts'].append(raw)
                cur['msgid'] = decode(raw[1:-1])
        elif line.startswith('msgstr ') and cur is not None:
            raw = line[7:].strip()
            if raw.startswith('"') and raw.endswith('"'):
                cur['sparts'].append(raw)
                cur['str'] = decode(raw[1:-1])
        elif line.startswith('"') and cur is not None:
            frag = line.strip()
            frag_inner = frag[1:-1]
            if cur['sparts']:
                cur['sparts'].append(frag)
                cur['str'] += decode(frag_inner)
            else:
                cur['mparts'].append(frag)
                cur['msgid'] += decode(frag_inner)
    if cur:
        entries.append(cur)
    return entries


def fill(path, lang):
    trans = TRANS[lang]
    text = open(path, encoding='utf-8').read()
    lines = text.split('\n')
    entries = parse(text)
    edits = {}
    missing = []
    for e in entries:
        if e['msgid'] == '':
            continue
        if e['msgid'] not in trans:
            missing.append(e['msgid'])
            continue
        edits[e['start']] = e
    if missing:
        print('%s: SEM TRADUCAO: %d' % (lang, len(missing)))
        for m in missing:
            print(' -', repr(m))
    out = []
    i = 0
    while i < len(lines):
        if i in edits:
            e = edits[i]
            val = trans[e['msgid']]
            out.append('msgid "%s"' % encode(e['msgid']))
            out.append('msgstr "%s"' % encode(val))
            i = e['start'] + len(e['mparts']) + len(e['sparts'])
        else:
            out.append(lines[i])
            i += 1
    open(path, 'w', encoding='utf-8').write('\n'.join(out))
    done = sum(1 for e in entries if e['msgid'] and e['msgid'] in trans and trans[e['msgid']])
    print('%s: %d/54 traduzidas' % (lang, done))


def main():
    if len(sys.argv) < 2:
        print('Uso: python3 fill_po.py <lang>')
        sys.exit(2)
    lang = sys.argv[1]
    if lang not in TRANS:
        print('Língua %r não está em translations.py' % lang)
        sys.exit(2)
    fill(os.path.join(BASE, '%s.po' % lang), lang)


if __name__ == '__main__':
    main()