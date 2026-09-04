/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kcmutils as KCM
import "js/i18n.js" as I18n

import "js/weather.js" as Weather

KCM.SimpleKCM {
    function t(text) {
        var lang = Plasmoid.configuration.language || "";
        if (!lang) return text;
        return I18n.translate(text, lang);
    }
    id: page

    property var cityResults: []
    property var extraCities: []
    property bool geoLoading: false

    function loadExtraCities() {
        try {
            var raw = Plasmoid.configuration.weatherCities;
            page.extraCities = raw ? JSON.parse(raw) : [];
        } catch (e) {
            page.extraCities = [];
        }
    }

    function saveExtraCities() {
        Plasmoid.configuration.weatherCities = JSON.stringify(page.extraCities);
    }

    function addExtraCity(city) {
        var arr = page.extraCities.slice();
        arr.push({ name: city.name, lat: city.lat, lon: city.lon });
        page.extraCities = arr;
        page.saveExtraCities();
    }

    function removeExtraCity(idx) {
        var arr = page.extraCities.slice();
        arr.splice(idx, 1);
        page.extraCities = arr;
        page.saveExtraCities();
    }

    function setAsMain(city) {
        Plasmoid.configuration.weatherCity = city.name;
        Plasmoid.configuration.weatherLatitude = city.lat;
        Plasmoid.configuration.weatherLongitude = city.lon;
    }

    Component.onCompleted: loadExtraCities()

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: t("Busque uma cidade e escolha se ela será a principal ou adicional.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: citySearchField
                Layout.fillWidth: true
                placeholderText: t("Buscar cidade...")
                onAccepted: citySearchButton.clicked()
            }

            QQC2.Button {
                id: citySearchButton
                text: t("Buscar")
                icon.name: "edit-find"
                onClicked: {
                    var q = citySearchField.text.trim();
                    if (!q) return;
                    Weather.searchCity(q,
                        function(cities) { page.cityResults = cities; },
                        function(code) { page.cityResults = []; }
                    );
                }
            }

            QQC2.Button {
                text: page.geoLoading ? i18n("Obtendo localização...") : i18n("Minha localização")
                icon.name: page.geoLoading ? "view-refresh" : "geo-location"
                enabled: !page.geoLoading
                onClicked: {
                    page.geoLoading = true;
                    Weather.fetchLocationByIP(
                        function(loc) {
                            page.geoLoading = false;
                            Plasmoid.configuration.weatherCity = loc.name;
                            Plasmoid.configuration.weatherLatitude = loc.lat;
                            Plasmoid.configuration.weatherLongitude = loc.lon;
                            page.cityResults = [];
                            citySearchField.text = "";
                        },
                        function(code) {
                            page.geoLoading = false;
                            page.cityResults = [];
                        }
                    );
                }
            }
        }

        Repeater {
            model: page.cityResults
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                Layout.topMargin: 2

                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData.label
                    elide: Text.ElideMiddle
                }

                QQC2.ToolButton {
                    icon.name: "go-home"
                    Accessible.name: i18n("Definir como principal")
                    onClicked: {
                        page.setAsMain(modelData);
                        page.cityResults = [];
                        citySearchField.text = "";
                    }
                }

                QQC2.ToolButton {
                    icon.name: "list-add"
                    Accessible.name: i18n("Adicionar como adicional")
                    onClicked: {
                        page.addExtraCity(modelData);
                        page.cityResults = [];
                        citySearchField.text = "";
                    }
                }
            }
        }

        PlasmaComponents3.Label {
            visible: Plasmoid.configuration.weatherCity !== ""
            Layout.fillWidth: true
            text: t("Cidade principal: %1", Plasmoid.configuration.weatherCity)
            opacity: 0.6
            font.pixelSize: 11
        }

        QQC2.Button {
            visible: Plasmoid.configuration.weatherCity !== ""
            text: t("Limpar principal")
            icon.name: "edit-clear"
            onClicked: {
                Plasmoid.configuration.weatherCity = "";
                Plasmoid.configuration.weatherLatitude = 0;
                Plasmoid.configuration.weatherLongitude = 0;
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: t("Cidades adicionais:")
            font.pixelSize: 12
            font.bold: true
        }

        Repeater {
            model: page.extraCities
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 6

                Kirigami.Icon {
                    source: "weather-clear"
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: modelData.name
                    font.pixelSize: 12
                }

                QQC2.ToolButton {
                    icon.name: "list-remove"
                    Accessible.name: i18n("Remover")
                    onClicked: page.removeExtraCity(index)
                }
            }
        }

        PlasmaComponents3.Label {
            visible: page.extraCities.length === 0
            Layout.fillWidth: true
            opacity: 0.5
            font.pixelSize: 11
            text: t("Nenhuma cidade adicional.")
        }
    }
}
