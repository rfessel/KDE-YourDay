/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: "Feeds de notícias"
        icon: "view-pim-news"
        source: "configGeneral.qml"
    }

    ConfigCategory {
        name: "Exibição"
        icon: "preferences-desktop-display"
        source: "configView.qml"
    }
}