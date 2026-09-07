/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Relógio compacto com data completa, no estilo do relógio do KDE.
    Usado na representação compacta (painel) quando o modo é "Relógio".
*/
import QtQuick
import QtQml

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    id: root

    // Relógio atualizado a cada segundo pela virada de minuto/dia.
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    readonly property string timeText: root.now.toLocaleTimeString(Qt.locale(), "HH:mm")
    readonly property string dateText: Qt.formatDate(root.now, Qt.DefaultLocaleLongDate)

    implicitWidth: Math.max(48, timeLabel.implicitWidth, dateLabel.implicitWidth)
    implicitHeight: timeLabel.implicitHeight + dateLabel.implicitHeight + 2

    Column {
        id: col
        anchors.centerIn: parent
        spacing: -2

        PlasmaComponents3.Label {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: PlasmaCore.Theme.textColor
            text: root.timeText
            font.pixelSize: Math.max(12, Math.floor(root.height * 0.56))
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        PlasmaComponents3.Label {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: PlasmaCore.Theme.textColor
            opacity: 0.75
            text: root.dateText
            font.pixelSize: Math.max(9, Math.floor(root.height * 0.26))
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}