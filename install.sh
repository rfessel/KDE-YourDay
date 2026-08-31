#!/usr/bin/env bash
# Instala o plasmoid "Seu Dia..." para o usuário atual (Plasma 6).
set -euo pipefail

cd "$(dirname "$0")"
PACKAGE_DIR="plasmoid"
NAME="kde.yourday"

if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "$NAME"; then
    echo "Plasmoid já instalado. Atualizando..."
    kpackagetool6 -t Plasma/Applet -u "$PACKAGE_DIR"
else
    echo "Instalando $NAME..."
    kpackagetool6 -t Plasma/Applet -i "$PACKAGE_DIR"
fi

echo
echo "Pronto! Para usar:"
echo "  • Botão direito no desktop → “Adicionar Widgets” → procure por “Seu Dia...”."
echo "  • Se já estiver aberto, reinicie o plasmashell (kquitapp6 plasmashell && kstart plasmashell) para o widget aparecer na lista."