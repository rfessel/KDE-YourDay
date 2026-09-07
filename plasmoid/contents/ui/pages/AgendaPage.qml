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
    required property string notice

    // Callbacks para gerenciamento de eventos locais
    property var onAddEvent: function(title, startMs, endMs, allDay, description, location) {}
    property var onUpdateEvent: function(id, title, startMs, endMs, allDay, description, location) {}
    property var onRemoveEvent: function(id) {}

    // Estado do calendário
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property var selectedDate: new Date()
    property var selectedEvents: []

    // Estado do diálogo de evento
    property bool dialogOpen: false
    property bool dialogEditing: false
    property var editingEvent: null
    property string dialogTitle: ""
    property string dialogDescription: ""
    property string dialogLocation: ""
    property bool dialogAllDay: false
    property string dialogDate: ""
    property string dialogStartTime: "09:00"
    property string dialogEndTime: "10:00"

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

    function weekdayHeader() {
        // 2023-01-08 era domingo: nomes curtos traduzidos via locale
        var base = new Date(2023, 0, 8);
        var out = [];
        for (var i = 0; i < 7; i++) {
            var d = new Date(base);
            d.setDate(base.getDate() + i);
            out.push(d.toLocaleString(Qt.locale(), "ddd"));
        }
        return out;
    }

    function monthName(m) {
        return new Date(2020, m, 15).toLocaleString(Qt.locale(), "MMMM");
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function formatDateStr(d) {
        return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
    }

    function openNewEventDialog() {
        page.dialogEditing = false;
        page.editingEvent = null;
        page.dialogTitle = "";
        page.dialogDescription = "";
        page.dialogLocation = "";
        page.dialogAllDay = false;
        page.dialogDate = formatDateStr(page.selectedDate);
        page.dialogStartTime = "09:00";
        page.dialogEndTime = "10:00";
        page.dialogOpen = true;
    }

    function openEditEventDialog(ev) {
        page.dialogEditing = true;
        page.editingEvent = ev;
        page.dialogTitle = ev.title || "";
        page.dialogDescription = ev.description || "";
        page.dialogLocation = ev.location || "";
        page.dialogAllDay = !!ev.allDay;
        var d = new Date(ev.start);
        page.dialogDate = formatDateStr(d);
        if (ev.allDay) {
            page.dialogStartTime = "00:00";
            page.dialogEndTime = "23:59";
        } else {
            var sd = new Date(ev.start);
            var ed = new Date(ev.end);
            page.dialogStartTime = pad2(sd.getHours()) + ":" + pad2(sd.getMinutes());
            page.dialogEndTime = pad2(ed.getHours()) + ":" + pad2(ed.getMinutes());
        }
        page.dialogOpen = true;
    }

    function saveDialog() {
        var title = page.dialogTitle.trim();
        if (!title) return;

        var parts = page.dialogDate.split("-");
        var year = parseInt(parts[0]) || new Date().getFullYear();
        var month = (parseInt(parts[1]) || 1) - 1;
        var day = parseInt(parts[2]) || 1;

        var startMs, endMs;
        if (page.dialogAllDay) {
            startMs = new Date(year, month, day, 0, 0, 0, 0).getTime();
            endMs = startMs + 86400000;
        } else {
            var st = page.dialogStartTime.split(":");
            var et = page.dialogEndTime.split(":");
            startMs = new Date(year, month, day, parseInt(st[0]) || 0, parseInt(st[1]) || 0, 0, 0).getTime();
            endMs = new Date(year, month, day, parseInt(et[0]) || 0, parseInt(et[1]) || 0, 0, 0).getTime();
            if (endMs <= startMs) endMs = startMs + 3600000;
        }

        if (page.dialogEditing && page.editingEvent) {
            page.onUpdateEvent(page.editingEvent.id, title, startMs, endMs, page.dialogAllDay, page.dialogDescription, page.dialogLocation);
        } else {
            page.onAddEvent(title, startMs, endMs, page.dialogAllDay, page.dialogDescription, page.dialogLocation);
        }
        page.dialogOpen = false;
    }

    function isLocalEvent(ev) {
        return ev && ev.source === "local";
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
                text: i18n("Estes são os seus compromissos para esta data...")
                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                elide: Text.ElideRight
                font.pixelSize: 13
            }

            PlasmaComponents3.ToolButton {
                icon.name: "list-add"
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                QQC2.ToolTip.text: i18n("Novo evento")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: 500
                contentItem: Kirigami.Icon {
                    source: "list-add"
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                }
                onClicked: openNewEventDialog()
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
                    text: page.monthName(viewMonth) + " " + viewYear;
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
                    text: i18n("Hoje")
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    contentItem: Text {
                        text: i18n("Hoje")
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
                    model: page.weekdayHeader()
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

            PlasmaComponents3.Label {
                visible: page.notice.length > 0
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                text: page.notice
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: 11
                color: Qt.rgba(0.9, 0.5, 0.1, 1)
            }

            Kirigami.PlaceholderMessage {
                visible: !page.loading && page.selectedEvents.length === 0
                Layout.fillWidth: true
                text: i18n("Nenhum compromisso neste dia")
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
                            color: {
                                if (model.color) {
                                    return Qt.alpha(model.color, model.allDay ? 0.25 : 0.15);
                                }
                                return Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), model.allDay ? 0.14 : 0.06);
                            }
                            border.width: 1
                            border.color: {
                                if (model.color) {
                                    return Qt.alpha(model.color, 0.4);
                                }
                                return Qt.alpha((root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)), 0.5);
                            }

                            HoverHandler {
                                id: hoverHandler
                                target: parent
                                onHoveredChanged: parent.hovered = hovered
                            }
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

                                // Botões de editar/remover apenas para eventos locais
                                RowLayout {
                                    spacing: 2
                                    visible: page.isLocalEvent(model)

                                    PlasmaComponents3.ToolButton {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        icon.name: "document-edit"
                                        QQC2.ToolTip.text: i18n("Editar evento")
                                        QQC2.ToolTip.visible: hovered
                                        QQC2.ToolTip.delay: 500
                                        contentItem: Kirigami.Icon {
                                            source: "document-edit"
                                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                        }
                                        onClicked: page.openEditEventDialog(model)
                                    }

                                    PlasmaComponents3.ToolButton {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        icon.name: "edit-delete"
                                        QQC2.ToolTip.text: i18n("Remover evento")
                                        QQC2.ToolTip.visible: hovered
                                        QQC2.ToolTip.delay: 500
                                        contentItem: Kirigami.Icon {
                                            source: "edit-delete"
                                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                        }
                                        onClicked: page.onRemoveEvent(model.id)
                                    }
                                }
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

    // Diálogo de criar/editar evento
    Rectangle {
        visible: page.dialogOpen
        anchors.fill: parent
        z: 100
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            onClicked: page.dialogOpen = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 340
            height: dialogCol.implicitHeight + 32
            radius: 8
            color: root.isDarkTheme ? Qt.rgba(0.2, 0.2, 0.2, 1) : Qt.rgba(0.96, 0.96, 0.96, 1)
            border.width: 1
            border.color: root.isDarkTheme ? Qt.rgba(0.4, 0.4, 0.4, 1) : Qt.rgba(0.8, 0.8, 0.8, 1)

            ColumnLayout {
                id: dialogCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                PlasmaExtras.Heading {
                    level: 4
                    text: page.dialogEditing ? i18n("Editar evento") : i18n("Novo evento")
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    font.pixelSize: 15
                    Layout.fillWidth: true
                }

                // Título
                QQC2.TextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: i18n("Título do evento")
                    text: page.dialogTitle
                    onTextChanged: page.dialogTitle = text
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    background: Rectangle {
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                    }
                }

                // Dia todo
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    QQC2.CheckBox {
                        id: allDayCheck
                        text: i18n("Dia todo")
                        checked: page.dialogAllDay
                        onCheckedChanged: page.dialogAllDay = checked
                        QQC2.Label {
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        }
                    }
                }

                // Data
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    QQC2.Label {
                        text: i18n("Data:")
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        font.pixelSize: 12
                    }
                    QQC2.TextField {
                        id: dateField
                        Layout.fillWidth: true
                        text: page.dialogDate
                        onTextChanged: page.dialogDate = text
                        placeholderText: "YYYY-MM-DD"
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        background: Rectangle {
                            radius: 4
                            color: "transparent"
                            border.width: 1
                            border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                        }
                    }
                }

                // Horários (oculto se dia todo)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !page.dialogAllDay
                    QQC2.Label {
                        text: i18n("Início:")
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        font.pixelSize: 12
                    }
                    QQC2.TextField {
                        id: startTimeField
                        Layout.preferredWidth: 70
                        text: page.dialogStartTime
                        onTextChanged: page.dialogStartTime = text
                        placeholderText: "HH:MM"
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        background: Rectangle {
                            radius: 4
                            color: "transparent"
                            border.width: 1
                            border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                        }
                    }
                    QQC2.Label {
                        text: i18n("Fim:")
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        font.pixelSize: 12
                    }
                    QQC2.TextField {
                        id: endTimeField
                        Layout.preferredWidth: 70
                        text: page.dialogEndTime
                        onTextChanged: page.dialogEndTime = text
                        placeholderText: "HH:MM"
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        background: Rectangle {
                            radius: 4
                            color: "transparent"
                            border.width: 1
                            border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                        }
                    }
                }

                // Local
                QQC2.TextField {
                    Layout.fillWidth: true
                    placeholderText: i18n("Local (opcional)")
                    text: page.dialogLocation
                    onTextChanged: page.dialogLocation = text
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    background: Rectangle {
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                    }
                }

                // Descrição
                QQC2.TextArea {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    placeholderText: i18n("Descrição (opcional)")
                    text: page.dialogDescription
                    onTextChanged: page.dialogDescription = text
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    background: Rectangle {
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                    }
                }

                // Botões
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Layout.topMargin: 4

                    Item { Layout.fillWidth: true }

                    PlasmaComponents3.ToolButton {
                        text: i18n("Cancelar")
                        contentItem: Text {
                            text: i18n("Cancelar")
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: page.dialogOpen = false
                    }

                    PlasmaComponents3.ToolButton {
                        text: i18n("Salvar")
                        contentItem: Text {
                            text: i18n("Salvar")
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 4
                            color: Qt.rgba(0.15, 0.5, 0.85, 1)
                        }
                        onClicked: page.saveDialog()
                    }
                }
            }
        }
    }
}
}

