/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: "General"
        icon: "configure"
        source: "configGeneral.qml"
    }

    ConfigCategory {
        name: "News feeds"
        icon: "view-pim-news"
        source: "configFeeds.qml"
    }

    ConfigCategory {
        name: "Calendar"
        icon: "view-calendar"
        source: "configAgenda.qml"
    }

    ConfigCategory {
        name: "Weather"
        icon: "weather-clear"
        source: "configWeather.qml"
    }

    ConfigCategory {
        name: "Lists"
        icon: "view-list"
        source: "configListas.qml"
    }
}
