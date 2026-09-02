#!/usr/bin/env python3
"""
Exporta calendários do Akonadi (Merkuro/KDE) para um único arquivo .ics.
Mantém apenas eventos a partir de 2024 com campos essenciais.
Uso: python3 export_akonadi_calendar.py [caminho_de_saída]
Saída padrão: ~/.local/share/yourday/calendar.ics
"""
import sqlite3
import os
import re
import sys

DB_PATH = os.path.expanduser("~/.local/share/akonadi/akonadi.db")
OUTPUT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/yourday/calendar.ics")

def main():
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT p.data FROM PartTable p
        JOIN PimItemTable pim ON pim.id = p.pimItemId
        JOIN MimeTypeTable mt ON mt.id = pim.mimeTypeId
        JOIN PartTypeTable pt ON pt.id = p.partTypeId
        WHERE mt.name = 'application/x-vnd.akonadi.calendar.event'
        AND pt.name = 'RFC822'
    """)

    keep_props = re.compile(
        r'^(BEGIN:VEVENT|END:VEVENT|SUMMARY|DTSTART|DTEND|DURATION|RRULE|UID|LOCATION|DESCRIPTION|STATUS|CATEGORIES)',
        re.IGNORECASE
    )
    events = []

    for row in cursor.fetchall():
        data = row[0]
        if not data:
            continue
        text = data.decode("utf-8", errors="replace") if isinstance(data, bytes) else str(data)
        if "BEGIN:VEVENT" not in text:
            continue
        starts = re.findall(r"DTSTART[^:]*:(\d{8})", text)
        if not any(s >= "20240101" for s in starts):
            continue
        ev_match = re.search(r"(BEGIN:VEVENT.*?END:VEVENT)", text, re.DOTALL)
        if not ev_match:
            continue
        ev_block = ev_match.group(1)
        slim = []
        for line in ev_block.split("\n"):
            prop = line.split(":")[0].split(";")[0].strip().upper()
            if prop in ("BEGIN", "END", "SUMMARY", "DTSTART", "DTEND", "DURATION",
                        "RRULE", "UID", "LOCATION", "DESCRIPTION", "STATUS", "CATEGORIES"):
                slim.append(line.strip())
        if slim:
            events.append("\n".join(slim))

    conn.close()

    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write("BEGIN:VCALENDAR\n")
        f.write("PRODID:-//YourDay//Akonadi Export//PT\n")
        f.write("VERSION:2.0\n")
        for ev in events:
            f.write(ev + "\n")
        f.write("END:VCALENDAR\n")

    size_kb = os.path.getsize(OUTPUT) / 1024
    print(f"Exportados {len(events)} eventos para {OUTPUT} ({size_kb:.0f} KB)")

if __name__ == "__main__":
    main()
