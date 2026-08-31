#!/usr/bin/env python3
import os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'contents'))

def unesc(s):
    return (s.replace('\\"', '"')
             .replace('\\\\', '\\')
             .replace('\\n', '\n')
             .replace('\\t', '\t'))

def parse_args(s, pos, end):
    """Extract double-quoted string literals starting at pos, until end (the char after closing paren)."""
    args = []
    i = pos
    while i < end:
        while i < end and s[i] in ' \t\r\n':
            i += 1
        if i >= end or s[i] != '"':
            # skip to next quote or end
            while i < end and s[i] != '"':
                i += 1
            continue
        i += 1
        buf = []
        while i < end:
            c = s[i]
            if c == '\\':
                nxt = s[i + 1] if i + 1 < end else ''
                buf.append('\\' + nxt)
                i += 2
                continue
            if c == '"':
                i += 1
                break
            buf.append(c)
            i += 1
        args.append(unesc(''.join(buf)))
    return args

def find_open(s, name_idx):
    i = name_idx
    while i < len(s) and s[i] != '(':
        i += 1
    return i

def find_close(s, open_idx):
    depth = 0
    in_str = False
    esc = False
    i = open_idx
    while i < len(s):
        c = s[i]
        if in_str:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    return i

entries = {}  # (ctxt, msgid) -> files sorted
order = []

pattern = re.compile(r'\bi18n([a-z]*)')

for dirpath, _, fns in sorted(os.walk(ROOT)):
    for fn in sorted(fns):
        if not fn.endswith('.qml'):
            continue
        path = os.path.join(dirpath, fn)
        text = open(path, encoding='utf-8').read()
        for m in pattern.finditer(text):
            func = m.group(1)
            if func not in ('', 'c', 'd') and not func.startswith('c'):
                continue
            if func.startswith('c') and func not in ('c',):
                continue
            op = find_open(text, m.start())
            cl = find_close(text, op)
            args = parse_args(text, op + 1, cl)
            if func == '':
                if len(args) < 1:
                    continue
                msgid = args[0]
                ctxt = ''
            elif func == 'c':
                if len(args) < 2:
                    continue
                ctxt, msgid = args[0], args[1]
            elif func == 'd':
                if len(args) < 2:
                    continue
                ctxt = 'd:' + args[0]
                msgid = args[1]
            else:
                continue
            key = (ctxt, msgid)
            rel = os.path.relpath(path, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
            if key not in entries:
                entries[key] = []
                order.append(key)
            if rel not in entries[key]:
                entries[key].append(rel)

out = sys.stdout
out.write('# SOME DESCRIPTIVE TITLE.\n# Copyright (C) YEAR Seu Dia... contributors\n# This file is distributed under the same license as the widget.\n# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.\n#\n'
          'msgid ""\nmsgstr ""\n"Project-Id-Version: Seu Dia... 1.0\\n"\n"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n\n')

for key in order:
    ctxt, msgid = key
    files = entries[key]
    for rel in files:
        out.write('#: %s\n' % rel)
    if ctxt and not ctxt.startswith('d:'):
        out.write('#. %s\n' % ctxt)
        out.write('msgctxt "%s"\n' % ctxt)
    elif ctxt.startswith('d:'):
        out.write('#. (domain %s)\n' % ctxt[2:])
    out.write('msgid "%s"\n' % msgid.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n'))
    out.write('msgstr ""\n\n')

# Strings orig integradas dinamicamente (greeting) - manuais:
greeting = [
    'Bom dia', 'Boa tarde', 'Boa noite',
]
for g in greeting:
    key = ('', g)
    if key not in entries:
        entries[key] = ['<dinamico>']
        order.append(key)
for g in greeting:
    out.write('#: <saudacao dinamica>\n')
    out.write('msgid "%s"\n' % g.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n'))
    out.write('msgstr ""\n\n')