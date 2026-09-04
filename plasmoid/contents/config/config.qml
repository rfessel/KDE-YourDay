/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

import org.kde.plasma.configuration 2.0

import "../ui/js/i18n.js" as I18n

ConfigModel {
    id: cfgModel

    property string _lang: Plasmoid.configuration.language || ""

    function t(text) {
        if (!_lang) return text;
        return I18n.translate(text, _lang);
    }

    ConfigCategory {
        name: cfgModel.t("Geral")
        icon: "configure"
        source: "configGeneral.qml"
    }

    ConfigCategory {
        name: cfgModel.t("Feeds de notícias")
        icon: "view-pim-news"
        source: "configFeeds.qml"
    }

    ConfigCategory {
        name: cfgModel.t("Agenda")
        icon: "view-calendar"
        source: "configAgenda.qml"
    }

    ConfigCategory {
        name: cfgModel.t("Clima")
        icon: "weather-clear"
        source: "configWeather.qml"
    }

    ConfigCategory {
        name: cfgModel.t("Listas")
        icon: "view-list"
        source: "configListas.qml"
    }
}