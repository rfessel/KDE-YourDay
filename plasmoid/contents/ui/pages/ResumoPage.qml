/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Página de Resumo: visão geral do dia — calendário dinâmico, próximos
    compromissos (agenda) e tarefas a fazer (to-dos) em um só lugar.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

import "../js/calendar.js" as Cal
import "../js/weather.js" as Weather

Item {
    id: page

    required property var events
    required property var todos
    required property bool loading
    required property var weatherData
    required property bool weatherLoading
    required property string weatherCity

    signal gotoAgenda()
    signal gotoTodos()
    signal toggleTodoId(int index)

    readonly property var nextEvents: {
        var now = Date.now();
        var upcoming = [];
        for (var i = 0; i < page.events.length; i++) {
            var ev = page.events[i];
            if (ev.end > now) {
                upcoming.push(ev);
            }
        }
        upcoming.sort(function(a, b) { return a.start - b.start; });
        return upcoming.slice(0, 3);
    }

    readonly property var rootGreeting: ({
        capFirst: function(s) {
            if (!s) return "";
            return s.charAt(0).toUpperCase() + s.slice(1);
        },
        greeting: function() {
            var h = new Date().getHours();
            var raw = "Boa noite";
            if (h >= 5 && h < 12) raw = "Bom dia";
            else if (h >= 12 && h < 18) raw = "Boa tarde";
            return root.t(raw);
        }
    })

    Flickable {
        id: pageFlick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: rootCol.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: rootCol
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            // Saudação + clima (mesma linha)
            KCoreAddons.KUser {
                id: kuserInfo
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                // Saudação à esquerda
                ColumnLayout {
                    spacing: 2

                    PlasmaExtras.Heading {
                        level: 3
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                        text: rootGreeting.capFirst(rootGreeting.greeting()) + ", " + rootGreeting.capFirst(kuserInfo.loginName)
                    }
                    PlasmaComponents3.Label {
                        text: new Date().toLocaleString(Qt.locale(), "dddd, dd MMMM")
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                        opacity: 0.6
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                // Clima à direita (bloco único)
                ColumnLayout {
                    visible: page.weatherCity !== "" && !page.weatherLoading && page.weatherData !== null
                    spacing: 2

                    // Cidade + ícone + temperatura (mesma linha)
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaExtras.Heading {
                            level: 3
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                            text: page.weatherCity
                        }

                        Kirigami.Icon {
                            source: Weather.weatherIconWithRain(page.weatherData ? page.weatherData.code : 0, page.weatherData ? page.weatherData.isNight : false, page.weatherData ? page.weatherData.rain : 0, page.weatherData ? page.weatherData.showers : 0)
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                        }

                        PlasmaExtras.Heading {
                            level: 3
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                            text: page.weatherData ? Math.round(page.weatherData.temp) + "°C" : ""
                        }
                    }

                    // Max/min/chuva
                    PlasmaComponents3.Label {
                        text: {
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                            if (!page.weatherData) return "";
                            var s = "Max " + Math.round(page.weatherData.maxTemp) + "°  Min " + Math.round(page.weatherData.minTemp) + "°";
                            if (page.weatherData.rainChance !== undefined && page.weatherData.rainChance !== null) {
                                s += "  ·  Chuva " + page.weatherData.rainChance + "%";
                            }
                            return s;
                        }
                        font.pixelSize: 11
                        opacity: 0.6
                    }
                }

                // Loading
                QQC2.BusyIndicator {
                    visible: page.weatherCity !== "" && page.weatherLoading
                    running: visible
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }

                // Fallback
                PlasmaComponents3.Label {
                    visible: page.weatherCity !== "" && !page.weatherLoading && page.weatherData === null
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                    text: root.t("Toque para atualizar")
                    font.pixelSize: 10
                    opacity: 0.4
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshWeather()
                    }
                }
            }

            // Separador
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.15)
            }

            // Seção: Próximos compromissos
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                PlasmaExtras.Heading {
                    level: 4
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                    text: root.t("Próximos compromissos")
                    Layout.fillWidth: true
                }
                PlasmaComponents3.ToolButton {
                    text: "›"
                    Accessible.name: root.t("Ver agenda")
                    onClicked: page.gotoAgenda()
                }
            }

            QQC2.BusyIndicator {
                visible: page.loading
                running: visible
                Layout.alignment: Qt.AlignHCenter
            }

            Kirigami.PlaceholderMessage {
                visible: !page.loading && page.nextEvents.length === 0
                Layout.fillWidth: true
                text: root.t("Nenhum compromisso próximo")
                icon.name: "view-calendar-day"
            }

            Repeater {
                model: page.nextEvents
                delegate: eventRow
            }

            // Seção: Tarefas a fazer
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                PlasmaExtras.Heading {
                    level: 4
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                    text: root.t("Tarefas do dia")
                    Layout.fillWidth: true
                }
                PlasmaComponents3.ToolButton {
                    text: "›"
                    Accessible.name: root.t("Ver to-dos")
                    onClicked: page.gotoTodos()
                }
            }

            Kirigami.PlaceholderMessage {
                visible: page.todos.length === 0
                Layout.fillWidth: true
                text: root.t("Nenhuma tarefa para hoje")
                icon.name: "task-new"
            }

            Repeater {
                model: page.todos
                delegate: todoRow
            }
        }
    }

    Component {
        id: eventRow
        Rectangle {
            required property var model
            Layout.fillWidth: true
            Layout.preferredHeight: contentRow.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.smallSpacing
            color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), 0.05)
            border.width: 1
            border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.08)

            RowLayout {
                id: contentRow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    spacing: 0
                    Layout.preferredWidth: 52

                    PlasmaComponents3.Label {
                        text: model.allDay ? i18n("Dia") : Cal.formatTime(model.start, model.allDay)
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    PlasmaComponents3.Label {
                        text: {
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                            var d = new Date(model.start);
                            var now = new Date();
                            var diff = Math.floor((d - now) / 86400000);
                            if (diff === 0) return i18n("Hoje");
                            if (diff === 1) return i18n("Amanhã");
                            return d.toLocaleString(Qt.locale(), "dd/MM");
                        }
                        font.pixelSize: 9
                        opacity: 0.5
                    }
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                    text: model.title
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                }
            }
        }
    }

    Component {
        id: todoRow
        RowLayout {
            required property var model
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                checked: false
                onToggled: page.toggleTodoId(index)
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                        color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                text: model.text
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: 13
            }
        }
    }
}
