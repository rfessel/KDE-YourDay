/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: "Geral"
        icon: "configure"
        source: "configGeneral.qml"
    }

    ConfigCategory {
        name: "Feeds de notícias"
        icon: "view-pim-news"
        source: "configFeeds.qml"
    }

    ConfigCategory {
        name: "Agenda"
        icon: "view-calendar"
        source: "configAgenda.qml"
    }

    ConfigCategory {
        name: "Clima"
        icon: "weather-clear"
        source: "configWeather.qml"
    }

    ConfigCategory {
        name: "Listas"
        icon: "view-list"
        source: "configListas.qml"
    }
}