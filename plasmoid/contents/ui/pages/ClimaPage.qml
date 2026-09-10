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

    // Rotula o dia da previsão seguindo o locale do sistema; "Today" via i18n.
    function dayLabel(dateStr) {
        var d = new Date(dateStr + "T12:00:00");
        if (d.toDateString() === new Date().toDateString()) {
            return i18n("Today");
        }
        var s = d.toLocaleString(Qt.locale(), "ddd, d MMM").replace(/\./g, "");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

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

    // Espaço reservado para a barra de rolagem vertical (desenhada por cima
    // do conteúdo no QQC2): os cards do clima não ficam escondidos sob ela.
    readonly property real scrollGutter: climaScrollBar.visible ? climaScrollBar.width : 0

    // Até 6 próximas horas para o gráfico de linha (temperatura + chuva).
    readonly property var chartPoints: page.currentData && page.currentData.hours
                                       ? page.currentData.hours.slice(0, 6) : []

    // Cores FIXAS do gráfico de horas, independentes de tema/accent:
    // legenda e traços usam exatamente as mesmas cores.
    readonly property color tempLineColor: Qt.rgba(0.25, 0.55, 0.95, 1)
    readonly property color rainLineColor: Qt.rgba(0.9, 0.25, 0.25, 1)

    function getCityData(name) {
        if (name === page.weatherCity) return page.currentData;
        return page.extraWeatherData[name] || null;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.bottomMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: 0
        spacing: Kirigami.Units.largeSpacing

        // Cabeçalho padrão (48 px) — previsão + refresh manual do clima.
        PageHeader {
            title: i18n("Forecast")
            margins: 0

            PlasmaComponents3.ToolButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                QQC2.ToolTip.text: i18n("Refresh")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: 500
                contentItem: Kirigami.Icon {
                    source: "view-refresh"
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    RotationAnimation on rotation {
                        running: page.weatherLoading
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }
                onClicked: root.refreshWeather()
            }
        }

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
                  ? i18n("Tap refresh to load data.")
                  : i18n("No city configured.\nGo to Settings → Weather to add one.")
            icon.name: "weather-clear"
            helpfulAction: Kirigami.Action {
                text: i18n("Refresh")
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

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                id: climaScrollBar
                policy: QQC2.ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: weatherCol
                width: parent.width - page.scrollGutter - Kirigami.Units.largeSpacing
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
                            text: page.selectedCityName || i18n("Weather")
                            Layout.fillWidth: true
                        }

                        // Descrição
                        PlasmaComponents3.Label {
                            text: page.currentData ? i18n(Weather.weatherDescription(page.currentData.code)) : ""
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
                                        text: i18n("High: %1°", page.currentData && page.currentData.maxTemp !== undefined ? Math.round(page.currentData.maxTemp) : "—")
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    PlasmaComponents3.Label {
                                        text: i18n("Low: %1°", page.currentData && page.currentData.minTemp !== undefined ? Math.round(page.currentData.minTemp) : "—")
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
                                PlasmaComponents3.Label { text: i18n("Humidity"); font.pixelSize: 10; opacity: 0.5 }
                                PlasmaComponents3.Label { text: page.currentData && page.currentData.humidity !== undefined ? page.currentData.humidity + "%" : "—"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            }
                            ColumnLayout { spacing: 0
                                PlasmaComponents3.Label { text: i18n("Rain"); font.pixelSize: 10; opacity: 0.5 }
                                PlasmaComponents3.Label { text: page.currentData && page.currentData.rainChance !== undefined ? page.currentData.rainChance + "%" : "—"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            }
                            ColumnLayout { spacing: 0
                                PlasmaComponents3.Label { text: i18n("Wind"); font.pixelSize: 10; opacity: 0.5 }
                                PlasmaComponents3.Label { text: page.currentData && page.currentData.windSpeed !== undefined ? Math.round(page.currentData.windSpeed) + " km/h" : "—"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            }
                            ColumnLayout { spacing: 0
                                PlasmaComponents3.Label { text: i18n("Sun"); font.pixelSize: 10; opacity: 0.5 }
                                PlasmaComponents3.Label {
                                    text: page.currentData && page.currentData.sunrise ? Weather.formatTime(page.currentData.sunrise) + "/" + Weather.formatTime(page.currentData.sunset) : "—"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                // ========== Próximas horas (gráfico de linha) ==========
                Rectangle {
                    id: hoursCard
                    objectName: "hoursCard"
                    visible: page.chartPoints.length >= 2
                    Layout.fillWidth: true
                    radius: Kirigami.Units.largeSpacing
                    color: root.isDarkTheme ? Qt.rgba(0.25, 0.25, 0.25, 1) : Qt.rgba(0.95, 0.95, 0.95, 1)
                    border.width: 1
                    border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)
                    implicitHeight: hoursCardCol.implicitHeight + Kirigami.Units.largeSpacing * 2

                    ColumnLayout {
                        id: hoursCardCol
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaExtras.Heading {
                                objectName: "hoursHeader"
                                level: 4
                                Layout.fillWidth: true
                                color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                text: i18n("Next hours")
                            }

                            Row {
                                spacing: 4
                                Rectangle {
                                    width: 14; height: 3; radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: page.tempLineColor
                                }
                                PlasmaComponents3.Label {
                                    text: i18n("Temperature")
                                    font.pixelSize: 10
                                    color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                    opacity: 0.7
                                }
                            }

                            Row {
                                spacing: 4
                                Rectangle {
                                    width: 14; height: 3; radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: page.rainLineColor
                                }
                                PlasmaComponents3.Label {
                                    text: i18n("Rain")
                                    font.pixelSize: 10
                                    color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                    opacity: 0.7
                                }
                            }
                        }

                        // Duas linhas: temperatura (azul) e chance de chuva (vermelha), cores fixas
                        Canvas {
                            id: hoursChart
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            readonly property var pts: page.chartPoints

                            function xFor(i) {
                                var n = pts.length;
                                return 6 + (n > 1 ? i * (width - 16) / (n - 1) : (width - 16) / 2);
                            }

                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            Connections {
                                target: page
                                function onChartPointsChanged() { hoursChart.requestPaint(); }
                            }
                            Connections {
                                target: root
                                function onIsDarkThemeChanged() { hoursChart.requestPaint(); }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                var n = pts.length;
                                var topPad = 18, bottomPad = 18, leftPad = 6, rightPad = 10;
                                var plotW = width - leftPad - rightPad;
                                var plotH = height - topPad - bottomPad;
                                ctx.reset();
                                if (n < 2 || plotW <= 0 || plotH <= 0) return;

                                var tmin = Infinity, tmax = -Infinity;
                                for (var i = 0; i < n; i++) {
                                    if (pts[i].temp < tmin) tmin = pts[i].temp;
                                    if (pts[i].temp > tmax) tmax = pts[i].temp;
                                }
                                if (tmin === Infinity) { tmin = 0; tmax = 1; }
                                if (tmax - tmin < 4) {
                                    var pad = (4 - (tmax - tmin)) / 2;
                                    tmin -= pad;
                                    tmax += pad;
                                }
                                // Temperatura com escala própria; chuva em 0..100%.
                                function yFor(t) { return topPad + (1 - (t - tmin) / (tmax - tmin)) * plotH; }
                                function yRain(v) { return topPad + (1 - Math.max(0, Math.min(100, v)) / 100) * plotH; }

                                var acc = page.tempLineColor;
                                var rainLine = page.rainLineColor;
                                var rainText = page.rainLineColor;
                                var subtle = root.isDarkTheme ? "rgba(0.93,0.93,0.93,0.6)" : "rgba(0.13,0.13,0.13,0.6)";
                                var textClr = root.textMain || Qt.rgba(0.13, 0.13, 0.13, 1);
                                // só desenha "N%" quando a chance de chuva é > 0, para não
                                // sujar a base do gráfico (onde ficam as horas) de vermelho
                                function hasRain(d) { return (pts[d].rainChance || 0) > 0; }

                                // grade (linhas sutis)
                                ctx.strokeStyle = root.isDarkTheme ? "rgba(255,255,255,0.07)" : "rgba(0,0,0,0.07)";
                                ctx.lineWidth = 1;
                                for (var g = 0; g <= 2; g++) {
                                    var gy = topPad + g * plotH / 2;
                                    ctx.beginPath();
                                    ctx.moveTo(leftPad, gy);
                                    ctx.lineTo(leftPad + plotW, gy);
                                    ctx.stroke();
                                }

                                // linha da precipitação (0..100%) em vermelho vivo, sem halo para não
                                // "lavar" a cor perto de valores baixos
                                ctx.strokeStyle = rainLine;
                                ctx.lineWidth = 3;
                                ctx.beginPath();
                                for (var r = 0; r < n; r++) {
                                    var rxx = xFor(r);
                                    var ryy = yRain(pts[r].rainChance || 0);
                                    if (r === 0) ctx.moveTo(rxx, ryy); else ctx.lineTo(rxx, ryy);
                                }
                                ctx.stroke();

                                // linha da temperatura
                                ctx.strokeStyle = acc;
                                ctx.lineWidth = 2;
                                ctx.beginPath();
                                for (var p = 0; p < n; p++) {
                                    var px = xFor(p);
                                    var py = yFor(pts[p].temp);
                                    if (p === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                                }
                                ctx.stroke();

                                ctx.font = "9px sans-serif";
                                ctx.textAlign = "center";
                                var bottomY = height - 5;
                                for (var d = 0; d < n; d++) {
                                    var dx = xFor(d);
                                    var dy = yFor(pts[d].temp);
                                    var dy_ = yRain(pts[d].rainChance || 0);
                                    // ponto da precipitação
                                    ctx.fillStyle = rainLine;
                                    ctx.beginPath();
                                    ctx.arc(dx, dy_, 2, 0, 2 * Math.PI);
                                    ctx.fill();
                                    // ponto da temperatura
                                    ctx.fillStyle = acc;
                                    ctx.beginPath();
                                    ctx.arc(dx, dy, 3, 0, 2 * Math.PI);
                                    ctx.fill();
                                    // temperatura em cima
                                    ctx.fillStyle = textClr;
                                    ctx.fillText(Math.round(pts[d].temp) + "°", dx, dy - 8);
                                    // % de precipitação logo abaixo da linha (só se houver chance de chuva)
                                    if (hasRain(d)) {
                                        var pct = Math.round(pts[d].rainChance || 0) + "%";
                                        var pyl = dy_ + 11;
                                        if (pyl > bottomY - 4) pyl = dy_ - 9;
                                        ctx.fillStyle = rainText;
                                        ctx.fillText(pct, dx, pyl);
                                    }
                                    // hora embaixo, sozinha, na cor do texto do tema
                                    ctx.fillStyle = textClr;
                                    ctx.fillText(new Date(pts[d].time).getHours() + "h", dx, bottomY);
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
                            text: i18n("7-day forecast")
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
                                    text: page.dayLabel(modelData.date)
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
                            objectName: "hoursHeader"
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
                                        text: cityWeather ? i18n(Weather.weatherDescription(cityWeather.code)) : ""
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                        font.pixelSize: 11
                                        opacity: 0.7
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                ColumnLayout {
                                    spacing: 0
                                    PlasmaComponents3.Label { text: i18n("High"); font.pixelSize: 10; opacity: 0.5 }
                                    PlasmaComponents3.Label { text: cityWeather && cityWeather.maxTemp !== undefined ? Math.round(cityWeather.maxTemp) + "°" : "—"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                }

                                ColumnLayout {
                                    spacing: 0
                                    PlasmaComponents3.Label { text: i18n("Low"); font.pixelSize: 10; opacity: 0.5 }
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
                text: i18n("City:")
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
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onClicked: root.refreshWeather()
            }
        }
    }
}
