# Seu Dia...

Widget de leitura de notícias RSS/Atom para PLASMA 6 — seu resumo diário
de notícias, tudo num só lugar.

## Recursos

- Adicionar feeds RSS ou Atom manualmente (URL)
- Múltiplos feeds ao mesmo tempo; as notícias são mescladas e ordenadas
  por data.
- Visual limpo,com miniatura   da imagem quando o feed fornecee um breve resumo
- Clique na notícia abre o link no navegador; passe o mouse para ver o
  resumo.
- Atualização manual ou automática editável na aba feeds.
- Limite de notícias configurável (exibição).
- Feed sem XML válido é ignorado com aviso discreto.

## Requisitos

- KDE Plasma 6 (testado no Plasma 6.3) - DEBIAN 13
- `kpackagetool6` (parte do `plasma-workspace`)

## Instalação

```sh
cd ~/YourDay
./install.sh
```

Ou manualmente:

```sh
kpackagetool6 -t Plasma/Applet -i ./plasmoid
```

Depois: botão direito no desktop → **Adicionar Widgets** → pesquise por
**Seu Dia...**. Se o widget não aparecer na lista, reinicie o
plasmashell:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

Ou via Gerenciador de Widgets
...
Baixar o plasmoid e adicionar diretamente na edição de desktop/widgets
...

## Uso

1. Adicione o widget ao desktop (ou ao painel — na versão compacta, o
   ícone abre o popup).
2. Clique no botão **+** no cabeçalho e cole a URL de um feed, ou
   adicione pelas configurações (botão direito → *Configure Seu Dia...*).
3. Feeds sugeridos para testar:
   - `https://g1.globo.com/rss/g1/tecnologia/`
   - `https://www.tweakers.net/nieuws/overzicht/feed.xml`
   - `https://feeds.npr.org/1001/rss.xml`

## Desinstalação

```sh
cd ~/YourDay
./uninstall.sh
```

## Estrutura

```
plasmoid/
├── metadata.json                 # metadados do pacote (Plasma/Applet)
├── po/                           # fontes de tradução (.pot/.po) + scripts
│   ├── extract.py                # extrai i18n("...") dos QML -> template.pot
│   ├── translations.py           # dicionários de tradução por idioma
│   ├── fill_po.py                # aplica as traduções em um po/<lang>.po
│   └── build_translations.sh     # gera template.pot, mescla e compila .mo
└── contents/
    ├── config/
    │   ├── config.qml            # define a página de configurações
    │   └── main.xml              # esquema de configuração (feeds, maxItems)
    ├── locale/
    │   └── <lang>/LC_MESSAGES/plasma_applet_kde.yourday.mo
    └── ui/
        ├── main.qml              # widget (PlasmoidItem + UI estilo Win11)
        ├── configGeneral.qml     # página: adicionar/remover feeds
        └── js/feeds.js           # parser RSS/Atom + carregamento (JS puro)
```

`feeds.js` não depende de `DOMParser` nem de `XmlListModel` (indisponíveis
neste Qt 6): faz a varredura XML com tokenização própria, cobrindo RSS 2.0,
Atom, CDATA, entidades, `enclosure`/`media:content` e links do tipo
`<atom:link href="…"/>` (Google Notícias).

## Traduções

O widget segue o idioma do sistema (Plasma carrega automaticamente os
catálogos embutidos em `contents/locale/`). Os textos-fonte estão em
português; já há catálogos para **pt_BR, en, en_US, es, it, de, fr, ru,
he, ja e zh_CN**. O idioma do sistema que não tiver catálogo cai de volta
para o português.

Para adicionar/atualizar idiomas:

```sh
cd plasmoid/po
msginit --no-translator --locale=fr --input=template.pot -o fr.po
# edite fr.po (traduza as msgstr) OU adicione o dicionário `fr` em translations.py
sh build_translations.sh        # reextrai strings, mescla, compensa .mo
```

Depois de mudar qualquer texto nos QML: `sh plasmoid/po/build_translations.sh`
e reinstale o widget (`./install.sh`).

## Testes

O parser é testado com `qmltestrunner` (Qt Quick Test), incluindo um teste
de ponta a ponta com o feed do G1:

```sh
cd tests
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tst_feeds.qml
```

## Licença

GPL-2.0-or-later
