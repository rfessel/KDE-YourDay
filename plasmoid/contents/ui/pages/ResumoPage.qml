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

    // Re-renderiza saudação/data a cada tick do relógio (1 min).
    readonly property int timeTick: root.clockTick

    // Fração do dia já decorrida (0..1) para o anel de progresso do herói.
    // Depende de root.clockTick (tick do relógio) só para re-avaliar; o valor
    // é calculado de Date.now().
    readonly property real dayProgress: {
        var _tick = root.clockTick;
        var now = new Date();
        var start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0).getTime();
        var end = start + 86400000;
        var frac = (now.getTime() - start) / (end - start);
        return Math.max(0, Math.min(1, frac));
    }

    function dayProgressText() {
        var pct = Math.round(page.dayProgress * 100);
        return pct + "%";
    }

    // Próximos compromissos: só pré-visualiza os CONFIRMADOS, vivos agora ou
    // no futuro (ev.end > agora). Conforme o relógio passa, os que terminaram
    // saem e entram os próximos — atualizado a cada minuto (Timer) e a cada
    // republicação da agenda (onEventsChanged). A chave de cache evita
    // recriar os delegates do Repeater sem necessidade (relógio bate a 1 Hz).
    property var nextEvents: []

    property string nextEventsKey: ""

    function updateNextEvents() {
        var now = Date.now();
        var upcoming = [];
        var key = [];
        var evs = page.events;
        for (var i = 0; i < evs.length && upcoming.length < 3; i++) {
            var ev = evs[i];
            if (ev.end > now) {
                upcoming.push(ev);
                key.push(ev.start + "|" + ev.title);
            }
        }
        var joined = key.join(";");
        if (joined !== page.nextEventsKey) {
            page.nextEventsKey = joined;
            page.nextEvents = upcoming;
        }
    }

    onEventsChanged: page.updateNextEvents()

    Timer {
        interval: 60000
        repeat: true
        onTriggered: page.updateNextEvents()
    }

    Component.onCompleted: page.updateNextEvents()

    readonly property var rootGreeting: ({
        capFirst: function(s) {
            if (!s) return "";
            return s.charAt(0).toUpperCase() + s.slice(1);
        },
        greeting: function() {
            var h = new Date().getHours();
            if (h >= 5 && h < 12) return i18n("Good morning");
            if (h >= 12 && h < 18) return i18n("Good afternoon");
            return i18n("Good evening");
        }
    })

    function createdDateText(ms) {
        if (!ms) return "";
        var d = new Date(ms);
        var now = new Date();
        if (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()) {
            return i18n("Today");
        }
        return d.toLocaleString(Qt.locale(), "dd/MM");
    }

    function dueDateText(ms) {
        if (!ms) return "";
        var d = new Date(ms);
        var now = new Date();
        var t0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        var d0 = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        var diffDays = Math.round((d0 - t0) / 86400000);
        if (diffDays === 0) return i18n("Today");
        if (diffDays === 1) return i18n("Tomorrow");
        return d.toLocaleString(Qt.locale(), "dd/MM/yyyy");
    }

    // Espaço reservado para a barra de rolagem vertical (desenhada por cima
    // do conteúdo no QQC2): os cards do resumo não ficam escondidos sob ela.
    readonly property real scrollGutter: resumoScrollBar.visible ? resumoScrollBar.width : 0

    Flickable {
        id: pageFlick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: rootCol.implicitHeight + Kirigami.Units.largeSpacing * 2

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            id: resumoScrollBar
            policy: QQC2.ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: rootCol
            width: parent.width - page.scrollGutter - Kirigami.Units.largeSpacing
            anchors.top: parent.top
            anchors.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            // Saudação + progresso do dia + clima (herói com gradiente suave)
            KCoreAddons.KUser {
                id: kuserInfo
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: heroRow.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.largeSpacing
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.accentSoft }
                    GradientStop { position: 1.0; color: "transparent" }
                }

                RowLayout {
                    id: heroRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    // Saudação à esquerda
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        PlasmaExtras.Heading {
                            level: 3
                            color: root.textMain
                            text: (page.timeTick, rootGreeting.capFirst(rootGreeting.greeting()) + ", " + rootGreeting.capFirst(kuserInfo.loginName))
                        }
                        PlasmaComponents3.Label {
                            text: (page.timeTick, new Date().toLocaleString(Qt.locale(), "dddd, dd MMMM"))
                            color: root.textMain
                            opacity: 0.6
                            font.pixelSize: 11
                        }
                    }

                    // Anel de progresso do dia
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Canvas {
                            id: progressRing
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            Layout.alignment: Qt.AlignHCenter
                            readonly property real fraction: page.dayProgress
                            onFractionChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                var w = width, h = height;
                                ctx.clearRect(0, 0, w, h);
                                var cx = w / 2, cy = h / 2;
                                var r = Math.min(w, h) / 2 - 3;
                                ctx.lineWidth = 3.5;
                                ctx.lineCap = "round";

                                ctx.strokeStyle = Qt.alpha(root.accentMain, 0.18);
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                ctx.stroke();

                                ctx.strokeStyle = root.accentMain;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progressRing.fraction);
                                ctx.stroke();
                            }
                        }

                        PlasmaComponents3.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: page.dayProgressText()
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: root.textSubtle
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
                                color: root.textMain
                                text: page.weatherCity
                            }

                            Kirigami.Icon {
                                source: Weather.weatherIconWithRain(page.weatherData ? page.weatherData.code : 0, page.weatherData ? page.weatherData.isNight : false, page.weatherData ? page.weatherData.rain : 0, page.weatherData ? page.weatherData.showers : 0)
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                            }

                            PlasmaExtras.Heading {
                                level: 3
                                color: root.textMain
                                text: page.weatherData ? Math.round(page.weatherData.temp) + "°C" : ""
                            }
                        }

                        // Max/min/chuva
                        PlasmaComponents3.Label {
                            Layout.alignment: Qt.AlignRight
                            color: root.textMain
                            text: {
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
                        visible: page.weatherCity !== "" && page.weatherLoading && page.weatherData === null
                        running: visible
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                    }

                    // Fallback
                    PlasmaComponents3.Label {
                        visible: page.weatherCity !== "" && !page.weatherLoading && page.weatherData === null
                        color: root.textMain
                        text: i18n("Tap to refresh")
                        font.pixelSize: 10
                        opacity: 0.4
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshWeather()
                        }
                    }
                }
            }

            // Separador
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(root.textMain, 0.15)
            }

            // Seção: Próximos compromissos
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                PlasmaExtras.Heading {
                    level: 4
                    color: root.textMain
                    text: i18n("Upcoming appointments")
                    Layout.fillWidth: true
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
                text: i18n("No upcoming appointments")
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
                    color: root.textMain
                    text: i18n("Today's tasks")
                    Layout.fillWidth: true
                }
            }

            Kirigami.PlaceholderMessage {
                visible: page.todos.length === 0
                Layout.fillWidth: true
                text: i18n("No tasks for today")
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
            color: root.accentSoft
            border.width: 1
            border.color: Qt.alpha(root.accentMain, 0.18)

            // Filete colorido no topo identifica o tipo de compromisso.
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                radius: 1
                visible: model.allDay
                color: root.accentMain
                opacity: 0.5
            }

            RowLayout {
                id: contentRow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    spacing: 0
                    Layout.preferredWidth: 52

                    PlasmaComponents3.Label {
                        text: model.allDay ? i18n("Day") : Cal.formatTime(model.start, model.allDay)
                        color: root.textMain
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    PlasmaComponents3.Label {
                        color: root.textMain
                        text: {
                            // Diferença em DIAS do calendário (virada da
                            // meia-noite local), não em horas decorridas:
                            // um compromisso que começa amanhã cedo (menos de
                            // 24h de agora) aparecia como "hoje" de noite.
                            var d = new Date(model.start);
                            var now = new Date();
                            var t0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
                            var d0 = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
                            var diff = Math.round((d0 - t0) / 86400000);
                            if (diff === 0) return i18n("Today");
                            if (diff === 1) return i18n("Tomorrow");
                            return d.toLocaleString(Qt.locale(), "dd/MM");
                        }
                        font.pixelSize: 9
                        opacity: 0.5
                    }
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    color: root.textMain
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
        Rectangle {
            required property int index
            required property var model
            Layout.fillWidth: true
            Layout.preferredHeight: contentRow.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.smallSpacing
            color: root.accentSoft
            border.width: 1
            border.color: Qt.alpha(root.accentMain, 0.18)

            RowLayout {
                id: contentRow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                // Data de inclusão (como nos compromissos: rótulo + data embaixo)
                ColumnLayout {
                    spacing: 0
                    Layout.preferredWidth: 62
                    visible: model.createdAt > 0

                    PlasmaComponents3.Label {
                        color: root.textMain
                        text: i18n("Added on")
                        font.pixelSize: 9
                        opacity: 0.55
                    }
                    PlasmaComponents3.Label {
                        color: root.textMain
                        text: page.createdDateText(model.createdAt)
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    color: model.done ? Qt.rgba(0.4, 0.4, 0.4, 0.6) : root.textMain
                    text: model.text
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    font.strikeout: model.done
                }

                // Prazo de término (quando definido) — visual igual à aba Tarefas
                Rectangle {
                    visible: model.dueDate > 0
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: Math.max(dueText.implicitWidth + Kirigami.Units.smallSpacing * 2, 34)
                    radius: 11
                    color: Qt.alpha("#e05c10", 0.18)
                    border.width: 1
                    border.color: Qt.alpha("#e05c10", 0.35)

                    PlasmaComponents3.Label {
                        id: dueText
                        anchors.centerIn: parent
                        text: page.dueDateText(model.dueDate)
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: "#e05c10"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
