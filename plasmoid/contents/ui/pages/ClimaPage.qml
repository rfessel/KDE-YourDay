/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Página de Clima: previsão do tempo.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "../js/weather.js" as Weather

Item {
    id: page

    required property var weatherData
    required property bool weatherLoading
    required property string weatherCity
    required property var extraCities
    required property var extraWeatherData
    required property string selectedCityName

    property var allCities: {
        var arr = [];
        if (page.weatherCity) {
            arr.push({ name: page.weatherCity, lat: 0, lon: 0, isMain: true });
        }
        for (var i = 0; i < page.extraCities.length; i++) {
            arr.push({ name: page.extraCities[i].name, lat: page.extraCities[i].lat, lon: page.extraCities[i].lon, isMain: false });
        }
        return arr;
    }

    property var currentData: {
        if (page.selectedCityName === page.weatherCity || page.selectedCityName === "") {
            return page.weatherData;
        }
        return page.extraWeatherData[page.selectedCityName] || null;
    }

    property var otherCities: {
        var arr = [];
        // Adicionar cidade principal se não for a selecionada
        if (page.weatherCity && page.weatherCity !== page.selectedCityName) {
            arr.push({ name: page.weatherCity, data: page.weatherData });
        }
        // Adicionar cidades extras que não são a selecionada
        for (var i = 0; i < page.extraCities.length; i++) {
            var c = page.extraCities[i];
            if (c.name !== page.selectedCityName) {
                arr.push({ name: c.name, data: page.extraWeatherData[c.name] || null });
            }
        }
        return arr;
    }

    function getCityData(name) {
        if (name === page.weatherCity) return page.currentData;
        return page.extraWeatherData[name] || null;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // Loading
        QQC2.BusyIndicator {
            visible: page.weatherLoading
            running: visible
            Layout.alignment: Qt.AlignHCenter
        }

        // Placeholder
        Kirigami.PlaceholderMessage {
            visible: !page.weatherLoading && page.currentData === null
            Layout.fillWidth: true
            text: page.weatherCity
                  ? i18n("Toque em atualizar para carregar os dados.")
                  : i18n("Nenhuma cidade configurada.\nVá em Configurações → Clima para adicionar.")
            icon.name: "weather-clear"
            helpfulAction: Kirigami.Action {
                text: root.t("Atualizar")
                icon.name: "view-refresh"
                onTriggered: root.refreshWeather()
            }
        }

        Flickable {
            visible: !page.weatherLoading && page.currentData !== null
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: weatherCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

            ColumnLayout {
                id: weatherCol
                width: parent.width
                spacing: Kirigami.Units.largeSpacing

                // ========== Card principal ==========
                Rectangle {
                    Layout.fillWidth: true
                    radius: Kirigami.Units.largeSpacing
                    color: root.isDarkTheme ? Qt.rgba(0.25, 0.25, 0.25, 1) : Qt.rgba(0.92, 0.92, 0.92, 1)
                    border.width: 1
                    border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
                    implicitHeight: cardCol.implicitHeight + Kirigami.Units.largeSpacing * 2

                    ColumnLayout {
                        id: cardCol
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        // Cidade
                        PlasmaExtras.Heading {
                            level: 2
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                            text: page.selectedCityName || i18n("Clima")
                            Layout.fillWidth: true
                        }

                        // Descrição
                        PlasmaComponents3.Label {
                            text: page.currentData ? Weather.weatherDescription(page.currentData.code) : ""
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                            font.pixelSize: 13
                            opacity: 0.7
                        }

                        // Ícone + temperatura
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                source: Weather.weatherIconWithRain(page.currentData ? page.currentData.code : 0, page.currentData ? page.currentData.isNight : false, page.currentData ? page.currentData.rain : 0, page.currentData ? page.currentData.showers : 0)
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                            }

                            ColumnLayout {
                                spacing: 4

                                PlasmaExtras.Heading {
                                    level: 1
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                    text: page.currentData ? Math.round(page.currentData.temp) + "°C" : ""
                                }

                                RowLayout {
                                    spacing: Kirigami.Units.largeSpacing

                                    PlasmaComponents3.Label {
                                        text: root.t("Máx: %1°", page.currentData && page.currentData.maxTemp !== undefined ? Math.round(page.currentData.maxTemp) : "—")
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    PlasmaComponents3.Label {
                                        text: root.t("Mín: %1°", page.currentData && page.currentData.minTemp !== undefined ? Math.round(page.currentData.minTemp) : "—")
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                        font.pixelSize: 13
                                        opacity: 0.6
                                    }
                                }
                            }
                        }

                        Kirigami.Separator { Layout.fillWidth: true }

                        // Detalhes
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: Kirigami.Units.largeSpacing
                            rowSpacing: Kirigami.Units.smallSpacing

                            ColumnLayout { spacing: 0
                                PlasmaComponents3.Label { text: root.t("Umidade"); font.pixelSize: 10; opacity: 0.5 }
                                PlasmaComponents3.Label { text: page.currentData && page.currentData.humidity !== undefined ? page.currentData.humidity + "%" : "—"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            }
                            ColumnLayout { spacing: 0
                                PlasmaComponents3.Label { text: root.t("Chuva"); font.pixelSize: 10; opacity: 0.5 }
                                PlasmaComponents3.Label { text: page.currentData && page.currentData.rainChance !== undefined ? page.currentData.rainChance + "%" : "—"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            }
                            ColumnLayout { spacing: 0
                                PlasmaComponents3.Label { text: root.t("Vento"); font.pixelSize: 10; opacity: 0.5 }
                                PlasmaComponents3.Label { text: page.currentData && page.currentData.windSpeed !== undefined ? Math.round(page.currentData.windSpeed) + " km/h" : "—"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            }
                            ColumnLayout { spacing: 0
                                PlasmaComponents3.Label { text: root.t("Sol"); font.pixelSize: 10; opacity: 0.5 }
                                PlasmaComponents3.Label {
                                    text: page.currentData && page.currentData.sunrise ? Weather.formatTime(page.currentData.sunrise) + "/" + Weather.formatTime(page.currentData.sunset) : "—"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                // ========== Previsão 7 dias ==========
                Rectangle {
                    visible: page.currentData && page.currentData.days && page.currentData.days.length > 1
                    Layout.fillWidth: true
                    radius: Kirigami.Units.largeSpacing
                    color: root.isDarkTheme ? Qt.rgba(0.25, 0.25, 0.25, 1) : Qt.rgba(0.95, 0.95, 0.95, 1)
                    border.width: 1
                    border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
                    implicitHeight: forecastCol.implicitHeight + Kirigami.Units.largeSpacing * 2

                    ColumnLayout {
                        id: forecastCol
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaExtras.Heading {
                            level: 4
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                            text: root.t("Previsão 7 dias")
                        }

                        Repeater {
                            model: page.currentData ? page.currentData.days : []
                            delegate: RowLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                PlasmaComponents3.Label {
                                    Layout.preferredWidth: 90
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                    text: Weather.formatDayName(modelData.date)
                                    font.pixelSize: 12
                                    font.weight: index === 0 ? Font.Bold : Font.Normal
                                }

                                Kirigami.Icon {
                                    source: Weather.weatherIcon(modelData.code, false)
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                }

                                Item { Layout.fillWidth: true }

                                PlasmaComponents3.Label {
                                    text: modelData.rainChance !== undefined ? modelData.rainChance + "%" : ""
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                    font.pixelSize: 11
                                    opacity: 0.5
                                    Layout.preferredWidth: 35
                                    horizontalAlignment: Text.AlignRight
                                }

                                PlasmaComponents3.Label {
                                    text: modelData.maxTemp !== undefined ? Math.round(modelData.maxTemp) + "°" : "—"
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: 30
                                    horizontalAlignment: Text.AlignRight
                                }

                                PlasmaComponents3.Label {
                                    text: modelData.minTemp !== undefined ? Math.round(modelData.minTemp) + "°" : "—"
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                    font.pixelSize: 12
                                    opacity: 0.5
                                    Layout.preferredWidth: 30
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }

                // ========== Outras cidades ==========
                Repeater {
                    model: page.otherCities
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        radius: Kirigami.Units.largeSpacing
                        color: root.isDarkTheme ? Qt.rgba(0.25, 0.25, 0.25, 1) : Qt.rgba(0.92, 0.92, 0.92, 1)
                        border.width: 1
                        border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
                        implicitHeight: extraCol.implicitHeight + Kirigami.Units.largeSpacing * 2

                        property var cityWeather: modelData.data

                        ColumnLayout {
                            id: extraCol
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaExtras.Heading {
                                level: 4
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                text: modelData.name
                            }

                            RowLayout {
                                spacing: Kirigami.Units.largeSpacing

                                Kirigami.Icon {
                                    source: cityWeather ? Weather.weatherIconWithRain(cityWeather.code, cityWeather.isNight, cityWeather.rain, cityWeather.showers) : ""
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                }

                                ColumnLayout {
                                    spacing: 2

                                    PlasmaComponents3.Label {
                                        text: cityWeather ? Math.round(cityWeather.temp) + "°C" : "—"
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                        font.pixelSize: 18
                                        font.weight: Font.DemiBold
                                    }

                                    PlasmaComponents3.Label {
                                        text: cityWeather ? Weather.weatherDescription(cityWeather.code) : ""
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                        font.pixelSize: 11
                                        opacity: 0.7
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                ColumnLayout {
                                    spacing: 0
                                    PlasmaComponents3.Label { text: root.t("Máx"); font.pixelSize: 10; opacity: 0.5 }
                                    PlasmaComponents3.Label { text: cityWeather && cityWeather.maxTemp !== undefined ? Math.round(cityWeather.maxTemp) + "°" : "—"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                }

                                ColumnLayout {
                                    spacing: 0
                                    PlasmaComponents3.Label { text: root.t("Mín"); font.pixelSize: 10; opacity: 0.5 }
                                    PlasmaComponents3.Label { text: cityWeather && cityWeather.minTemp !== undefined ? Math.round(cityWeather.minTemp) + "°" : "—"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Seletor de cidade + Atualizar
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: root.t("Cidade:")
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                font.pixelSize: 12
                opacity: 0.7
            }

            QQC2.ComboBox {
                id: cityCombo
                Layout.fillWidth: true
                model: page.allCities
                textRole: "name"
                currentIndex: {
                    for (var i = 0; i < page.allCities.length; i++) {
                        if (page.allCities[i].name === page.selectedCityName) return i;
                    }
                    return 0;
                }
                onActivated: {
                    var city = page.allCities[index];
                    root.selectedCityName = city.name;
                }
            }

            QQC2.Button {
                visible: !page.weatherLoading
                text: root.t("Atualizar")
                icon.name: "view-refresh"
                onClicked: root.refreshWeather()
            }
        }
    }
}
