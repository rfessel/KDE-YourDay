# Seu Dia...

Dashboard pessoal para **KDE Plasma 6** — resumo diário com notícias, agenda,
tarefas, clima, notas, listas e mais, tudo num só widget.

## Abas

| Aba | Descrição |
|-----|-----------|
| **Resumo** | Saudação com data, clima atual da cidade, próximos compromissos e tarefas de hoje |
| **Agenda** | Calendário mensal com os eventos do dia selecionado e fontes `.ics` |
| **Tarefas** | Tarefas com prazo de término, data de inclusão, histórico de concluídas e restauração |
| **Clima** | Card principal com umidade/vento/chuva, previsão de **7 dias** e múltiplas cidades |
| **Notas** | Post-its coloridos com editor em popup |
| **Listas** | Listas gerais e de compras, com itens, finalização, histórico e exportação TXT/CSV |
| **Notícias** | Feed RSS/Atom com cache offline, filtro e abertura no navegador |

## Recursos

- **7 abas** com navegação lateral por ícones e aba inicial configurável
- **Aparência no painel** em 3 modos:
  - **Ícone** — apenas o ícone do widget
  - **Ícone interativo** — ícone com o número do dia atual
  - **Relógio** — horas com a data completa embaixo (CompactClock)
- **Tooltip no hover**: data por extenso com dia da semana, cidade com a
  previsão atual (temperatura + condição) e relógio com segundos
- **Resumo** com tarefas em modo somente leitura (a finalização é feita na aba Tarefas)
- **Tarefas** com data de inclusão ("Incluído em") e **prazo de término**
  opcional, escolhido em um seletor de data do sistema (Kirigami DatePopup),
  exibido como selo com "Hoje", "Amanhã" ou dd/mm/aaaa e histórico de concluídas
- **Agenda** com eventos recorrentes (RRULE) e compromissos de dia inteiro
- **Clima** gratuito e sem API key (Open-Meteo), com geolocalização automática
  por IP e busca de cidade (Nominatim)
- **Parser RSS/Atom** próprio, sem dependências externas, com cache em SQLite,
  atualização automática e limite global de notícias
- **Tema** claro / escuro / automático (segue o sistema)
- **11 idiomas**: pt_BR, en, en_US, es, it, de, fr, ru, he, ja, zh_CN

## Requisitos

- KDE Plasma 6 (testado no Plasma 6.3) — Debian 13
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
**Seu Dia...**. Se o widget não aparecer na lista, reinicie o plasmashell:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

Para atualizar uma instalação existente use `-u` no lugar de `-i`, ou rode o
`install.sh` novamente.

## Configuração

Botão direito no widget → **Configure Seu Dia...**

- **Geral**: aba padrão, aparência no painel (ícone / ícone interativo /
  relógio), tema (claro/escuro/automático) e ícone do widget
- **Feeds de notícias**: adicionar/remover feeds RSS/Atom, ajustar limite por
  fonte e atualizar manualmente
- **Agenda**: fontes `.ics` (URL pessoal do Google Calendar / CalDAV ou
  caminho para arquivo local)
- **Clima**: cidade principal e cidades adicionais + serviço de geolocalização
- **Listas**: exportar todas as listas para TXT ou CSV
- **Exibição**: máximo total de notícias na lista (soma de todos os feeds) e
  linhas da chamada da matéria

## Estrutura

```
plasmoid/
├── metadata.json
├── po/                            # traduções
│   ├── translations.py            # catálogo de chaves por idioma
│   ├── extract.py                 # extrai strings i18n() dos QML
│   ├── fill_po.py                 # aplica traduções aos .po
│   └── build_translations.sh      # regenera template + catálogos + .mo
└── contents/
    ├── config/
    │   ├── config.qml             # agrupa os painéis de configuração
    │   └── main.xml               # esquema de configuração
    ├── locale/
    │   └── <lang>/LC_MESSAGES/*.mo
    ├── ui/
    │   ├── main.qml               # widget principal
    │   ├── CompactClock.qml       # relógio compacto para o painel
    │   ├── DayIcon.qml            # ícone interativo com o dia do mês
    │   ├── pages/
    │   │   ├── ResumoPage.qml
    │   │   ├── AgendaPage.qml
    │   │   ├── ToDoPage.qml
    │   │   ├── ClimaPage.qml
    │   │   ├── NotasPage.qml
    │   │   └── ListasPage.qml
    │   ├── configGeneral.qml
    │   ├── configFeeds.qml
    │   ├── configAgenda.qml
    │   ├── configWeather.qml
    │   ├── configListas.qml
    │   ├── configView.qml
    │   └── js/
    │       ├── feeds.js           # parser RSS/Atom + auto-refresh
    │       ├── weather.js         # Open-Meteo + Nominatim + ipinfo.io
    │       └── calendar.js        # parser .ics (VEVENT + RRULE)
├── KDE-YourDay.plasmoid           # pacote instalável gerado
├── scripts/
│   └── export_akonadi_calendar.py # exporta calendário do Akonadi para .ics
└── tests/                         # testes QML (qmltestrunner)
```

## Como executar os testes

```sh
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/
```

## Licença

GPL-2.0-or-later