/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Página de Agenda: calendário mensal + compromissos do dia selecionado.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "../js/calendar.js" as Cal

Item {
    id: page

    required property var events
    required property bool loading

    // Estado do calendário
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property var selectedDate: new Date()
    property var selectedEvents: []

    function updateSelectedEvents() {
        var range = Cal.dayRange(selectedDate.getTime());
        var out = [];
        for (var i = 0; i < page.events.length; i++) {
            var ev = page.events[i];
            if (ev.start < range.end && ev.end > range.start) {
                out.push(ev);
            }
        }
        out.sort(function(a, b) { return (a.start - b.start); });
        page.selectedEvents = out;
    }

    function prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear--; }
        else { viewMonth--; }
    }

    function nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear++; }
        else { viewMonth++; }
    }

    function selectDate(y, m, d) {
        selectedDate = new Date(y, m, d, 0, 0, 0, 0);
        updateSelectedEvents();
    }

    function isToday(y, m, d) {
        var now = new Date();
        return y === now.getFullYear() && m === now.getMonth() && d === now.getDate();
    }

    function isSelected(y, m, d) {
        return y === selectedDate.getFullYear() && m === selectedDate.getMonth() && d === selectedDate.getDate();
    }

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate();
    }

    function firstDayOfWeek(y, m) {
        return new Date(y, m, 1).getDay();
    }

    Component.onCompleted: updateSelectedEvents()

    onEventsChanged: updateSelectedEvents()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: 0

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.Heading {
                level: 4
                Layout.fillWidth: true
                text: root.t("Estes são os seus compromissos para esta data...")
                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                elide: Text.ElideRight
                font.pixelSize: 13
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
            opacity: 0.15
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            // Calendário à esquerda
            ColumnLayout {
                Layout.preferredWidth: 260
                Layout.minimumWidth: 220
                Layout.maximumWidth: 300
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.smallSpacing

            // Navegação mês
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.ToolButton {
                    text: "‹"
                    contentItem: Text {
                        text: "‹"
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: prevMonth()
                }

                PlasmaExtras.Heading {
                    level: 4
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        var months = ["Janeiro","Fevereiro","Março","Abril","Maio","Junho",
                                      "Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"];
                        return months[viewMonth] + " " + viewYear;
                    }
                }

                PlasmaComponents3.ToolButton {
                    text: "›"
                    contentItem: Text {
                        text: "›"
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: nextMonth()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.ToolButton {
                    text: root.t("Hoje")
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    contentItem: Text {
                        text: root.t("Hoje")
                        font.pixelSize: 10
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        var now = new Date();
                        viewYear = now.getFullYear();
                        viewMonth = now.getMonth();
                        selectDate(viewYear, viewMonth, now.getDate());
                    }
                }
            }

            // Cabeçalho dias da semana
            Grid {
                columns: 7
                Layout.fillWidth: true

                Repeater {
                    model: ["Do", "Se", "Te", "Qa", "Qi", "Se", "Sa"]
                    delegate: PlasmaComponents3.Label {
                        width: 32
                        text: modelData
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: (root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.5, 0.5, 0.5, 1))
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Dias do mês
            Grid {
                columns: 7
                Layout.fillWidth: true

                Repeater {
                    model: {
                        var first = firstDayOfWeek(viewYear, viewMonth);
                        var total = daysInMonth(viewYear, viewMonth);
                        var items = [];
                        for (var i = 0; i < first; i++) {
                            items.push({ day: 0, month: viewMonth, year: viewYear });
                        }
                        for (var d = 1; d <= total; d++) {
                            items.push({ day: d, month: viewMonth, year: viewYear });
                        }
                        while (items.length % 7 !== 0) {
                            items.push({ day: 0, month: viewMonth, year: viewYear });
                        }
                        return items;
                    }
                    delegate: Rectangle {
                        required property var model
                        property bool isCurrentDay: model.day > 0 && isToday(model.year, model.month, model.day)
                        property bool isSelectedDay: model.day > 0 && isSelected(model.year, model.month, model.day)

                        width: 32
                        height: 28
                        radius: 4
                        color: isSelectedDay
                               ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), 0.4)
                               : (isCurrentDay ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), 0.2)
                                  : (model.day > 0 ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.06) : "transparent"))

                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            text: model.day > 0 ? model.day : ""
                            font.pixelSize: 10
                            font.weight: isCurrentDay ? Font.Bold : Font.Normal
                            color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                            opacity: model.day > 0 ? 1.0 : 0.0
                        }

                        MouseArea {
                            anchors.fill: parent
                            visible: model.day > 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selectDate(model.year, model.month, model.day)
                        }
                    }
                }
            }
        }

        // Separador vertical
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: (root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1))
        }

        // Compromissos do dia selecionado
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 300
            spacing: 0

            QQC2.BusyIndicator {
                visible: page.loading
                running: visible
                Layout.alignment: Qt.AlignHCenter
            }

            Kirigami.PlaceholderMessage {
                visible: !page.loading && page.selectedEvents.length === 0
                Layout.fillWidth: true
                text: root.t("Nenhum compromisso neste dia")
                icon.name: "view-calendar-day"
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: eventsCol.height
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: eventsCol
                    width: parent.width
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: page.selectedEvents
                        delegate: Rectangle {
                            required property var model
                            Layout.fillWidth: true
                            Layout.preferredHeight: contentRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                            radius: Kirigami.Units.smallSpacing
                            color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), model.allDay ? 0.14 : 0.06)
                            border.width: 1
                            border.color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)), 0.5)

                            property bool hovered: false

                            RowLayout {
                                id: contentRow
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing

                                PlasmaComponents3.Label {
                                    Layout.preferredWidth: 50
                                    text: model.allDay ? i18n("Dia todo") : Cal.formatTime(model.start, model.allDay)
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                }

                                PlasmaComponents3.Label {
                                    Layout.fillWidth: true
                                    text: model.title
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 3
                                    font.pixelSize: 13
                                    color: (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                            }

                            QQC2.ToolTip {
                                visible: parent.hovered && (model.description !== "" || model.location !== "")
                                delay: 500
                                timeout: 5000
                                text: {
                                    var lines = [];
                                    if (model.location !== "") {
                                        lines.push("📍 " + model.location);
                                    }
                                    if (model.description !== "") {
                                        lines.push(model.description);
                                    }
                                    return lines.join("\n");
                                }
                                background: Rectangle {
                                    color: Qt.rgba(0.15, 0.15, 0.15, 0.95)
                                    radius: 6
                                }
                                contentItem: ColumnLayout {
                                    spacing: 4
                                    QQC2.Label {
                                        text: model.location !== "" ? "📍 " + model.location : ""
                                        visible: model.location !== ""
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#ffffff"
                                        wrapMode: Text.Wrap
                                        Layout.maximumWidth: 300
                                    }
                                    QQC2.Label {
                                        text: model.description !== "" ? model.description : ""
                                        visible: model.description !== ""
                                        font.pixelSize: 11
                                        color: "#ffffff"
                                        wrapMode: Text.Wrap
                                        Layout.maximumWidth: 300
                                        opacity: 0.9
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
}
