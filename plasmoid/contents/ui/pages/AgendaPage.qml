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
    // Lista de destinos ao criar evento: [{ id, label, color }] (Local + calendários Google)
    property var calendarTargets: [{ id: "local", label: i18n("Local"), color: "#34a853" }]

    // Callbacks para gerenciamento de eventos locais
    property var onAddEvent: function(title, startMs, endMs, allDay, description, location, calendarId) {}
    property var onUpdateEvent: function(id, title, startMs, endMs, allDay, description, location) {}
    property var onRemoveEvent: function(id) {}

    // Estado do calendário
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property var selectedDate: new Date()
    property var selectedEvents: []

    // Estado do popup de seleção de data no diálogo
    property int calPickerMonth: new Date().getMonth()
    property int calPickerYear: new Date().getFullYear()
    property var calPickerDays: []

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
    property string dialogCalendar: "local"

    function calendarLabel(id) {
        for (var i = 0; i < page.calendarTargets.length; i++) {
            if (page.calendarTargets[i].id === id) {
                return page.calendarTargets[i].label;
            }
        }
        return id;
    }

    function calendarColor(id) {
        for (var i = 0; i < page.calendarTargets.length; i++) {
            if (page.calendarTargets[i].id === id) {
                return page.calendarTargets[i].color;
            }
        }
        return "#34a853";
    }

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

    // Abre o drop box do seletor de horário abaixo do campo clicado.
    function openTimePicker(field) {
        var hh, mm;
        timePicker.pickStart = (field === startTimeBtn);
        if (timePicker.pickStart) {
            hh = parseInt(page.dialogStartTime.split(":")[0]) || 0;
            mm = parseInt(page.dialogStartTime.split(":")[1]) || 0;
        } else {
            hh = parseInt(page.dialogEndTime.split(":")[0]) || 0;
            mm = parseInt(page.dialogEndTime.split(":")[1]) || 0;
        }
        timePicker.visible = true;
        hList.setIndex(hh);
        mList.setIndex(Math.round(mm / 5));
        var pt = field.mapToItem(dialogRect, 0, field.height + 6);
        timePicker.x = Math.min(Math.max(0, pt.x), dialogRect.width - timePicker.width - 8);
        timePicker.y = pt.y;
        if (timePicker.y + timePicker.height > dialogRect.height - 8) {
            var top = field.mapToItem(dialogRect, 0, 0).y;
            timePicker.y = Math.max(0, top - timePicker.height - 6);
        }
        timePicker.visible = true;
    }

    function pickTimeApply() {
        var hh = hList.selectedIndex();
        var mm = mList.selectedIndex() * 5;
        var t = page.pad2(hh) + ":" + page.pad2(mm);
        if (timePicker.pickStart) {
            page.dialogStartTime = t;
            page.dialogEndTime = page.pad2((hh + 1) % 24) + ":" + page.pad2(mm);
        } else {
            page.dialogEndTime = t;
        }
        timePicker.visible = false;
    }

    // Abre o popup de calendário abaixo do campo de data clicado.
    function openDatePicker(btn) {
        var parts = page.dialogDate.split("-");
        page.calPickerYear = parseInt(parts[0]) || new Date().getFullYear();
        page.calPickerMonth = Math.max(0, Math.min(11, (parseInt(parts[1]) || 1) - 1));
        page.rebuildCalDays();
        var pt = btn.mapToItem(dialogRect, 0, btn.height + 6);
        datePicker.x = Math.min(Math.max(0, pt.x), dialogRect.width - datePicker.width - 8);
        datePicker.y = pt.y;
        if (datePicker.y + datePicker.height > dialogRect.height - 8) {
            var top = btn.mapToItem(dialogRect, 0, 0).y;
            datePicker.y = Math.max(0, top - datePicker.height - 6);
        }
        datePicker.visible = true;
    }

    // Dias do mês exibido no popup (0 = célula vazia para alinhar a semana).
    function rebuildCalDays() {
        var first = page.firstDayOfWeek(page.calPickerYear, page.calPickerMonth);
        var total = page.daysInMonth(page.calPickerYear, page.calPickerMonth);
        var items = [];
        for (var i = 0; i < first; i++) {
            items.push(0);
        }
        for (var d = 1; d <= total; d++) {
            items.push(d);
        }
        while (items.length % 7 !== 0) {
            items.push(0);
        }
        page.calPickerDays = items;
    }

    function calPickerPrev() {
        page.calPickerMonth--;
        if (page.calPickerMonth < 0) {
            page.calPickerMonth = 11;
            page.calPickerYear--;
        }
        page.rebuildCalDays();
    }

    function calPickerNext() {
        page.calPickerMonth++;
        if (page.calPickerMonth > 11) {
            page.calPickerMonth = 0;
            page.calPickerYear++;
        }
        page.rebuildCalDays();
    }

    function calPickerToday() {
        var now = new Date();
        page.calPickerYear = now.getFullYear();
        page.calPickerMonth = now.getMonth();
        page.rebuildCalDays();
    }

    function calPickerSelect(day) {
        page.dialogDate = page.formatDateStr(new Date(page.calPickerYear, page.calPickerMonth, day));
        datePicker.visible = false;
    }

    // Dia destacado no popup deve acompanhar a data do diálogo (dialogDate).
    function calIsSelected(day) {
        var parts = page.dialogDate.split("-");
        var y = parseInt(parts[0]) || 0;
        var m = (parseInt(parts[1]) || 1) - 1;
        var d = parseInt(parts[2]) || 0;
        return page.calPickerYear === y && page.calPickerMonth === m && day === d;
    }

    function formatDateShort(d) {
        return d.toLocaleString(Qt.locale(), "dd MMM yyyy");
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
        page.dialogCalendar = "local";
        if (calendarCombo && calendarCombo.model) {
            for (var ci = 0; ci < calendarCombo.model.length; ci++) {
                if (calendarCombo.model[ci].id === "local") {
                    calendarCombo.currentIndex = ci;
                    break;
                }
            }
        }
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
            page.onUpdateEvent(page.eventKey(page.editingEvent), title, startMs, endMs, page.dialogAllDay, page.dialogDescription, page.dialogLocation);
        } else {
            page.onAddEvent(title, startMs, endMs, page.dialogAllDay, page.dialogDescription, page.dialogLocation, page.dialogCalendar);
        }
        page.dialogOpen = false;
    }

    // Chave para onUpdateEvent/onRemoveEvent: id local, ou googleId no caso
    // de compromisso nativo do Google (que não tem campo id próprio).
    function eventKey(ev) {
        if (!ev) return "";
        return ev.source === "local" ? (ev.id || "") : (ev.googleId || ev.id || "");
    }

    // Eventos que o widget pode editar/apagar: locais e do Google (com
    // googleId). Compromissos de fontes ICS (url/file) ficam somente leitura.
    function canEditEvent(ev) {
        if (!ev) return false;
        if (ev.source === "local") return true;
        return ev.source === "google" && !!ev.googleId;
    }

    // Cor do evento: a do calendário Google quando disponível (source "google"
    // traz color), senão verde de "Local".
    function eventColor(ev) {
        if (ev && ev.color) {
            return ev.color;
        }
        return "#34a853";
    }

    // Cores distintas dos eventos que caem no dia y/m/d (bolinhas do grid).
    function dayColors(y, m, d) {
        var start = new Date(y, m, d, 0, 0, 0, 0).getTime();
        var end = start + 86400000;
        var out = [];
        var seen = {};
        var evs = page.events;
        for (var i = 0; i < evs.length; i++) {
            var ev = evs[i];
            if (ev.start < end && ev.end > start) {
                var c = page.eventColor(ev);
                if (!seen[c]) {
                    seen[c] = true;
                    out.push(c);
                }
            }
        }
        return out;
    }

    Component.onCompleted: updateSelectedEvents()

    onEventsChanged: updateSelectedEvents()

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: 0
        spacing: 0

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.Heading {
                level: 4
                Layout.fillWidth: true
                text: i18n("These are your appointments for this date...")
                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                elide: Text.ElideRight
                font.pixelSize: 13
            }

            PlasmaComponents3.ToolButton {
                icon.name: "list-add"
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                QQC2.ToolTip.text: i18n("New event")
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
            Layout.rightMargin: Kirigami.Units.smallSpacing
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
                    text: i18n("Today")
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    contentItem: Text {
                        text: i18n("Today")
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
                        property var dotColors: model.day > 0 ? page.dayColors(model.year, model.month, model.day) : []

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

                        // Bolinhas coloridas: uma por calendário com compromisso no dia.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            spacing: 3
                            visible: page.dotColors.length > 0
                            Repeater {
                                model: page.dotColors.slice(0, 3)
                                Rectangle {
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: modelData
                                }
                            }
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
                text: i18n("No appointments on this day")
                icon.name: "view-calendar-day"
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: eventsCol.height
                boundsBehavior: Flickable.StopAtBounds

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                    id: agendaScrollBar
                    policy: QQC2.ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: eventsCol
                    width: parent.width - (agendaScrollBar.visible ? agendaScrollBar.width : 0) - Kirigami.Units.smallSpacing
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
                                    text: model.allDay ? i18n("All day") : Cal.formatTime(model.start, model.allDay)
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

                                // Botões de editar/remover para eventos locais e do Google
                                RowLayout {
                                    spacing: 2
                                    visible: page.canEditEvent(model)

                                    PlasmaComponents3.ToolButton {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        icon.name: "document-edit"
                                        QQC2.ToolTip.text: i18n("Edit event")
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
                                        QQC2.ToolTip.text: i18n("Remove event")
                                        QQC2.ToolTip.visible: hovered
                                        QQC2.ToolTip.delay: 500
                                        contentItem: Kirigami.Icon {
                                            source: "edit-delete"
                                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                        }
                                        onClicked: page.onRemoveEvent(page.eventKey(model))
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

        // O diálogo fecha somente pelos botões Ok/Cancelar/Salvar; cliques no
        // escuro não fecham (evita perder digitação por clique acidental).
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: dialogRect
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
                    text: page.dialogEditing ? i18n("Edit event") : i18n("New event")
                    color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    font.pixelSize: 15
                    Layout.fillWidth: true
                }

                // Destino do evento (Local ou um calendário Google)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !page.dialogEditing && page.calendarTargets.length > 1

                    QQC2.Label {
                        text: i18n("Add to:")
                        font.pixelSize: 12
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                    }

                    Rectangle {
                        id: calSwatch
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: page.calendarColor(page.dialogCalendar)
                    }

                    QQC2.ComboBox {
                        id: calendarCombo
                        Layout.fillWidth: true
                        model: page.calendarTargets
                        textRole: "label"
                        font.pixelSize: 12
                        onActivated: page.dialogCalendar = model[index].id
                    }
                }

                // Título
                QQC2.TextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: i18n("Event title")
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
                        text: i18n("All day")
                        checked: page.dialogAllDay
                        onCheckedChanged: page.dialogAllDay = checked
                        QQC2.Label {
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        }
                    }
                }

                // Data (clique abre o popup de calendário)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    QQC2.Label {
                        text: i18n("Date:")
                        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                        font.pixelSize: 12
                    }
                    PlasmaComponents3.ToolButton {
                        id: dateFieldBtn
                        objectName: "dateFieldBtn"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        contentItem: Text {
                            text: {
                                var p = page.dialogDate.split("-");
                                var y = parseInt(p[0]) || 0;
                                var m = parseInt(p[1]) || 1;
                                var d = parseInt(p[2]) || 1;
                                if (y === 0) return "";
                                return page.formatDateShort(new Date(y, m - 1, d));
                            }
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: page.openDatePicker(dateFieldBtn)
                    }
                }

                // Horários (oculto se dia todo) — clique abre o drop box do seletor
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !page.dialogAllDay
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        QQC2.Label {
                            text: i18n("Start:")
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 12
                        }
                        PlasmaComponents3.ToolButton {
                            id: startTimeBtn
                            Layout.preferredWidth: 88
                            Layout.preferredHeight: 26
                            contentItem: Text {
                                text: page.dialogStartTime
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: page.openTimePicker(startTimeBtn)
                        }
                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        QQC2.Label {
                            text: i18n("End:")
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 12
                        }
                        PlasmaComponents3.ToolButton {
                            id: endTimeBtn
                            Layout.preferredWidth: 88
                            Layout.preferredHeight: 26
                            contentItem: Text {
                                text: page.dialogEndTime
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: page.openTimePicker(endTimeBtn)
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                // Local
                QQC2.TextField {
                    Layout.fillWidth: true
                    placeholderText: i18n("Location (optional)")
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

                // Descrição: caixa com quebra de linha e barra de rolagem própria
                // (TextArea do Qt 6 não exibe barra de forma confiável).
                Rectangle {
                    id: descBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                    clip: true

                    readonly property bool descNeedsScroll: descText.implicitHeight > descFlick.height

                    Text {
                        visible: descText.text === ""
                        z: -1
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 6
                        text: i18n("Description (optional)")
                        font.pixelSize: Math.min(12, descBox.height * 0.4)
                        color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.35, 0.35, 0.35, 1)
                    }

                    Flickable {
                        id: descFlick
                        anchors.fill: parent
                        anchors.rightMargin: descBox.descNeedsScroll ? 7 : 1
                        clip: true
                        contentWidth: width
                        contentHeight: descText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: descText
                            width: descFlick.width + 1
                            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                            text: page.dialogDescription
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            selectionColor: root.accentMain
                            selectedTextColor: "white"
                            selectByMouse: true
                            persistentSelection: true
                            padding: 6
                            onTextChanged: page.dialogDescription = text
                            // Mantém o cursor visível enquanto digita: a barra e a caixa
                            // descem automaticamente, e voltam se o cursor ficar acima.
                            onCursorRectangleChanged: {
                                var cr = descText.cursorRectangle;
                                if (cr.y < descFlick.contentY) {
                                    descFlick.contentY = cr.y;
                                } else if (cr.y + cr.height > descFlick.contentY + descFlick.height) {
                                    descFlick.contentY = cr.y + cr.height - descFlick.height;
                                }
                            }
                        }
                    }

                    // Barra de rolagem vertical (só quando o texto extrapola)
                    Rectangle {
                        visible: descBox.descNeedsScroll
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: 5
                        radius: 2.5
                        color: "transparent"

                        Rectangle {
                            id: descHandle
                            width: 5
                            radius: 2.5
                            color: root.isDarkTheme ? Qt.rgba(0.5, 0.8, 1, 0.6) : Qt.rgba(0.15, 0.5, 0.85, 0.55)
                            height: descHandle.implicitH
                            property real implicitH: Math.max(18, descTrack.height * descFlick.height / Math.max(1, descText.implicitHeight))
                            y: descTrack.height > descHandle.height
                               ? (descText.implicitHeight > descFlick.height
                                  ? descFlick.contentY / (descText.implicitHeight - descFlick.height)
                                    * (descTrack.height - descHandle.height)
                                  : 0)
                               : 0
                        }
                    }

                    // Arrastar a barra com o mouse
                    MouseArea {
                        id: descTrack
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: 8
                        visible: descBox.descNeedsScroll
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => descGrab(mouse.y)
                        onPositionChanged: (mouse) => descGrab(mouse.y)
                        function descGrab(ty) {
                            var range = Math.max(1, descText.implicitHeight - descFlick.height);
                            var trav = Math.max(1, descTrack.height - descHandle.height);
                            descFlick.contentY = Math.max(0, Math.min(range, (ty - descHandle.height / 2) / trav * range));
                        }
                    }
                }

                // Botões
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Layout.topMargin: 4

                    Item { Layout.fillWidth: true }

                    PlasmaComponents3.ToolButton {
                        text: i18n("Cancel")
                        contentItem: Text {
                            text: i18n("Cancel")
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: page.dialogOpen = false
                    }

                    PlasmaComponents3.ToolButton {
                        text: i18n("Save")
                        contentItem: Text {
                            text: i18n("Save")
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

            // Drop box do seletor de horário (aberto pelo clique no horário)
            Rectangle {
                id: timePicker
                objectName: "timePicker"
                property bool pickStart: true
                visible: false
                z: 60
                width: 168
                height: pickCol.implicitHeight + 18
                radius: 8
                color: root.isDarkTheme ? Qt.rgba(0.16, 0.16, 0.16, 1) : Qt.rgba(1, 1, 1, 1)
                border.width: 1
                border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.75, 0.75, 0.75, 1)

                // Bloqueia cliques em áreas vazias: só Ok/Cancelar fecham o seletor.
                MouseArea {
                    anchors.fill: parent
                    z: 0
                }

                ColumnLayout {
                    id: pickCol
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Roda das horas (arraste ou scroll do mouse)
                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 96
                            radius: 4
                            color: "transparent"
                            border.width: 1
                            border.color: root.isDarkTheme ? Qt.rgba(0.45, 0.45, 0.45, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                            // Faixa central destacada
                            Rectangle {
                                y: parent.height / 2 - 16
                                width: parent.width
                                height: 32
                                radius: 2
                                color: root.isDarkTheme ? Qt.rgba(0.4, 0.7, 1, 0.18) : Qt.rgba(0.15, 0.5, 0.85, 0.16)
                            }
                            ListView {
                                id: hList
                                objectName: "timeWheelHours"
                                anchors.fill: parent
                                anchors.margins: 1
                                clip: true
                                model: 24
                                header: Item { width: 1; height: 31 }
                                footer: Item { width: 1; height: 31 }
                                delegate: QQC2.Label {
                                    width: hList.width
                                    height: 32
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: page.pad2(modelData)
                                    font.pixelSize: 14
                                    font.bold: Math.abs(index * 32 - hList.contentY - (hList.height - 32) / 2) < 8
                                    color: Math.abs(index * 32 - hList.contentY - (hList.height - 32) / 2) < 8
                                        ? (root.isDarkTheme ? Qt.rgba(0.5, 0.8, 1, 1) : Qt.rgba(0.15, 0.5, 0.85, 1))
                                        : (root.isDarkTheme ? Qt.rgba(0.9, 0.9, 0.9, 1) : Qt.rgba(0.25, 0.25, 0.25, 1))
                                    opacity: Math.abs(index * 32 - hList.contentY - (hList.height - 32) / 2) < 8 ? 1 : 0.5
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: hList.setIndex(index)
                                    }
                                }
                                onMovementEnded: {
                                    var off = (hList.height - 32) / 2;
                                    var n = Math.round((hList.contentY + off) / 32);
                                    if (n < 0) n = 0;
                                    if (n > hList.count - 1) n = hList.count - 1;
                                    hList.contentY = n * 32 - off;
                                }
                                function setIndex(i) {
                                    hList.contentY = i * 32 - (hList.height - 32) / 2;
                                }
                                function selectedIndex() {
                                    var n = Math.round((hList.contentY + (hList.height - 32) / 2) / 32);
                                    if (n < 0) n = 0;
                                    if (n > hList.count - 1) n = hList.count - 1;
                                    return n;
                                }
                                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                                    width: 5
                                    policy: QQC2.ScrollBar.AsNeeded
                                    z: 4
                                    contentItem: Rectangle {
                                        implicitWidth: 5
                                        radius: 2
                                        color: root.isDarkTheme ? Qt.rgba(0.5, 0.8, 1, 0.6) : Qt.rgba(0.15, 0.5, 0.85, 0.55)
                                    }
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                }
                            }
                        }

                        // Roda dos minutos (passos de 5)
                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 96
                            radius: 4
                            color: "transparent"
                            border.width: 1
                            border.color: root.isDarkTheme ? Qt.rgba(0.45, 0.45, 0.45, 1) : Qt.rgba(0.7, 0.7, 0.7, 1)
                            // Faixa central destacada
                            Rectangle {
                                y: parent.height / 2 - 16
                                width: parent.width
                                height: 32
                                radius: 2
                                color: root.isDarkTheme ? Qt.rgba(0.4, 0.7, 1, 0.18) : Qt.rgba(0.15, 0.5, 0.85, 0.16)
                            }
                            ListView {
                                id: mList
                                objectName: "timeWheelMinutes"
                                anchors.fill: parent
                                anchors.margins: 1
                                clip: true
                                model: 12
                                header: Item { width: 1; height: 31 }
                                footer: Item { width: 1; height: 31 }
                                delegate: QQC2.Label {
                                    width: mList.width
                                    height: 32
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: page.pad2(modelData * 5)
                                    font.pixelSize: 14
                                    font.bold: Math.abs(index * 32 - mList.contentY - (mList.height - 32) / 2) < 8
                                    color: Math.abs(index * 32 - mList.contentY - (mList.height - 32) / 2) < 8
                                        ? (root.isDarkTheme ? Qt.rgba(0.5, 0.8, 1, 1) : Qt.rgba(0.15, 0.5, 0.85, 1))
                                        : (root.isDarkTheme ? Qt.rgba(0.9, 0.9, 0.9, 1) : Qt.rgba(0.25, 0.25, 0.25, 1))
                                    opacity: Math.abs(index * 32 - mList.contentY - (mList.height - 32) / 2) < 8 ? 1 : 0.5
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: mList.setIndex(index)
                                    }
                                }
                                onMovementEnded: {
                                    var off = (mList.height - 32) / 2;
                                    var n = Math.round((mList.contentY + off) / 32);
                                    if (n < 0) n = 0;
                                    if (n > mList.count - 1) n = mList.count - 1;
                                    mList.contentY = n * 32 - off;
                                }
                                function setIndex(i) {
                                    mList.contentY = i * 32 - (mList.height - 32) / 2;
                                }
                                function selectedIndex() {
                                    var n = Math.round((mList.contentY + (mList.height - 32) / 2) / 32);
                                    if (n < 0) n = 0;
                                    if (n > mList.count - 1) n = mList.count - 1;
                                    return n;
                                }
                                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                                    width: 5
                                    policy: QQC2.ScrollBar.AsNeeded
                                    z: 4
                                    contentItem: Rectangle {
                                        implicitWidth: 5
                                        radius: 2
                                        color: root.isDarkTheme ? Qt.rgba(0.5, 0.8, 1, 0.6) : Qt.rgba(0.15, 0.5, 0.85, 0.55)
                                    }
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Item { Layout.fillWidth: true }

                        PlasmaComponents3.ToolButton {
                            text: i18n("Cancel")
                            contentItem: Text {
                                text: i18n("Cancel")
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: timePicker.visible = false
                        }

                        PlasmaComponents3.ToolButton {
                            objectName: "timePickerOk"
                            text: i18n("OK")
                            contentItem: Text {
                                text: i18n("OK")
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
                            onClicked: page.pickTimeApply()
                        }
                    }
                }
            }

            // Popup de calendário para a data (mesmo padrão visual do seletor de horário)
            Rectangle {
                id: datePicker
                objectName: "datePicker"
                visible: false
                z: 60
                width: dateCol.implicitWidth + 20
                height: dateCol.implicitHeight + 18
                radius: 8
                color: root.isDarkTheme ? Qt.rgba(0.16, 0.16, 0.16, 1) : Qt.rgba(1, 1, 1, 1)
                border.width: 1
                border.color: root.isDarkTheme ? Qt.rgba(0.5, 0.5, 0.5, 1) : Qt.rgba(0.75, 0.75, 0.75, 1)

                // Bloqueia cliques em áreas vazias: só clique num dia, Hoje ou
                // Cancelar fecham o calendário.
                MouseArea {
                    anchors.fill: parent
                    z: 0
                }

                ColumnLayout {
                    id: dateCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Cabeçalho: mês e ano com navegação
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        PlasmaComponents3.ToolButton {
                            objectName: "datePickerPrev"
                            text: "‹"
                            contentItem: Text {
                                text: "‹"
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: page.calPickerPrev()
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: page.monthName(page.calPickerMonth) + " " + page.calPickerYear
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        PlasmaComponents3.ToolButton {
                            objectName: "datePickerNext"
                            text: "›"
                            contentItem: Text {
                                text: "›"
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: page.calPickerNext()
                        }
                    }

                    // Nomes curtos dos dias da semana (via locale)
                    Grid {
                        columns: 7
                        columnSpacing: 2
                        Layout.alignment: Qt.AlignHCenter
                        Repeater {
                            model: page.weekdayHeader()
                            delegate: QQC2.Label {
                                width: 28
                                height: 18
                                text: modelData
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.isDarkTheme ? Qt.rgba(0.6, 0.6, 0.6, 1) : Qt.rgba(0.5, 0.5, 0.5, 1)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    // Grade de dias do mês
                    Grid {
                        columns: 7
                        columnSpacing: 2
                        Layout.alignment: Qt.AlignHCenter
                        Repeater {
                            model: page.calPickerDays
                            delegate: Rectangle {
                                required property int modelData
                                property bool isCalToday: modelData > 0 && page.isToday(page.calPickerYear, page.calPickerMonth, modelData)
                                property bool isCalSelected: modelData > 0 && page.calIsSelected(modelData)
                                width: 28
                                height: 28
                                radius: 4
                                // Mantém a célula ocupando espaço no Grid mesmo vazia
                                // (visible:false faria o Grid pulá-la e desalinhar a semana).
                                opacity: modelData > 0 ? 1 : 0
                                color: isCalSelected
                                       ? (root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1))
                                       : (isCalToday ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)), 0.2) : "transparent")
                                border.width: isCalToday && !isCalSelected ? 1 : 0
                                border.color: root.isDarkTheme ? Qt.rgba(0.45, 0.7, 1.0, 1) : Qt.rgba(0.15, 0.5, 0.85, 1)

                                QQC2.Label {
                                    anchors.centerIn: parent
                                    text: modelData > 0 ? modelData : ""
                                    font.pixelSize: 10
                                    font.weight: isCalSelected || isCalToday ? Font.Bold : Font.Normal
                                    color: isCalSelected
                                           ? "#ffffff"
                                           : (root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1))
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData > 0) {
                                            page.calPickerSelect(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Rodapé: hoje e cancelar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        PlasmaComponents3.ToolButton {
                            objectName: "datePickerToday"
                            text: i18n("Today")
                            contentItem: Text {
                                text: i18n("Today")
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: page.calPickerToday()
                        }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents3.ToolButton {
                            objectName: "datePickerCancel"
                            text: i18n("Cancel")
                            contentItem: Text {
                                text: i18n("Cancel")
                                color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: datePicker.visible = false
                        }
                    }
                }
            }
        }
    }
}
}

