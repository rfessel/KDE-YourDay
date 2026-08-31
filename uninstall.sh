#!/usr/bin/env bash
# Remove o plasmoid "Seu Dia..." do usuário atual (Plasma 6).
set -euo pipefail

cd "$(dirname "$0")"
NAME="kde.yourday"

if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "$NAME"; then
    kpackagetool6 -t Plasma/Applet -r "$NAME"
    echo "Plasmoid $NAME removido."
else
    echo "Plasmoid $NAME não está instalado."
fi