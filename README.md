# Seu Dia...

Dashboard pessoal para KDE Plasma 6 — resumo diário com notícias, agenda,
tarefas, clima, notas, listas e mais, tudo num só lugar.

## Abas

| Aba | Descrição |
|-----|-----------|
| **Resumo** | Saudação, clima atual, próximos compromissos e tarefas do dia |
| **Agenda** | Calendário mensal + eventos do dia selecionado |
| **Tarefas** | Gerenciamento de tarefas com histórico |
| **Clima** | Card principal, previsão 7 dias, multi-cidades |
| **Notas** | Post-its coloridos com editor popup |
| **Listas** | Listas gerais/compras com exportação TXT/CSV |
| **Notícias** | Feed RSS/Atom com cache e cards |

## Recursos

- 7 abas com navegação lateral por ícones
- Tema claro/escuro/automático (segue o sistema)
- Geolocalização automática para o clima (via IP)
- Previsão do tempo para múltiplas cidades (Open-Meteo)
- Parser RSS/Atom customizado (sem dependências externas)
- Exportação de listas para TXT e CSV
- Calendário com suporte a eventos recorrentes (RRULE)
- Atualização automática de feeds e clima
- Traduções: pt_BR, en, en_US, es, it, de, fr, ru, he, ja, zh_CN

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

## Configuração

Botão direito no widget → **Configure Seu Dia...**

- **Geral**: Aba padrão, ícone do widget, tema
- **Feeds de notícias**: Adicionar/remover feeds RSS, limite de itens
- **Agenda**: Fontes .ics (Google Calendar export, URL, arquivo local)
- **Clima**: Cidade principal e cidades adicionais
- **Listas**: Exportar listas para TXT ou CSV

## Estrutura

```
plasmoid/
├── metadata.json
├── po/                            # traduções
│   └── build_translations.sh
└── contents/
    ├── config/
    │   ├── config.qml             # categorias de config
    │   └── main.xml               # esquema de configuração
    ├── locale/
    │   └── <lang>/LC_MESSAGES/*.mo
    └── ui/
        ├── main.qml               # widget principal
        ├── pages/
        │   ├── ResumoPage.qml
        │   ├── AgendaPage.qml
        │   ├── ToDoPage.qml
        │   ├── ClimaPage.qml
        │   ├── NotasPage.qml
        │   ├── ListasPage.qml
        │   └── (Notícias inline no main.qml)
        ├── configGeneral.qml
        ├── configFeeds.qml
        ├── configAgenda.qml
        ├── configWeather.qml
        ├── configListas.qml
        └── js/
            ├── feeds.js           # parser RSS/Atom
            ├── weather.js         # Open-Meteo + Nominatim + ipinfo.io
            └── calendar.js        # parser .ics
```

## Licença

GPL-2.0-or-later
