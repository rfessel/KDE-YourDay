#!/bin/sh
# Constrói os catálogos de tradução do widget.
# Uso: sh build_translations.sh   (a partir de po/ ou de qualquer lugar)
set -eu
cd "$(dirname "$0")"
DOMAIN=plasma_applet_kde.yourday

# 1) extrai strings i18n("...") dos QML -> template.pot
python3 extract.py > template.pot

# 2) mescla o template nos .po existentes (preserva traduções já feitas)
for PO in *.po; do
    msgmerge --update --no-fuzzy-matching "${PO}" template.pot >/dev/null
done

# 3) aplica as traduções conhecidas
for PO in *.po; do
    LANGNAME="${PO%.po}"
    python3 fill_po.py "${LANGNAME}" || true
done

# 4) limpa e recompila .mo dentro do pacote (contents/locale/<lang>/LC_MESSAGES/)
rm -rf ../contents/locale
for PO in *.po; do
    LANGNAME="${PO%.po}"
    mkdir -p "../contents/locale/${LANGNAME}/LC_MESSAGES"
    msgfmt "${PO}" -o "../contents/locale/${LANGNAME}/LC_MESSAGES/${DOMAIN}.mo"
done

# 'en' genérica (inglês) usa a mesma tradução do en_US
mkdir -p "../contents/locale/en/LC_MESSAGES"
msgfmt en_US.po -o "../contents/locale/en/LC_MESSAGES/${DOMAIN}.mo"

echo "Traduções compiladas com sucesso."
echo "Idiomas: $(find ../contents/locale -name '*.mo' -printf '%h\n' | sed 's#.*/locale/##' | sort -u | tr '\n' ' ')"