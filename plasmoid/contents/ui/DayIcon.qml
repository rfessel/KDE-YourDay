/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Ícone de calendário dinâmico que mostra o dia atual.
    Usado no cabeçalho do widget e na representação compacta (painel).
*/
import QtQuick
import QtQml

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: root

    // Tamanho do quadrado do calendário (célula do ícone).
    property int cellSize: Kirigami.Units.iconSizes.medium
    // Altura do cabeçalho (aba) do calendário, relativa à célula.
    property real headerRatio: 0.32
    // Relógio atualizado periodicamente para reavaliar dia/mês na virada de dia.
    property date now: new Date()

    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    readonly property int currentDay: root.now.getDate()
    readonly property string currentMonth: (function() {
        var names = ["jan", "fev", "mar", "abr", "mai", "jun",
                     "jul", "ago", "set", "out", "nov", "dez"];
        return names[root.now.getMonth()];
    })()

    implicitWidth: cellSize
    implicitHeight: cellSize

    // Célula do calendário (fundo).
    Rectangle {
        anchors.fill: parent
        radius: cellSize * 0.16
        color: Qt.alpha(PlasmaCore.Theme.textColor, 0.06)
        border.width: Math.max(1, cellSize * 0.04)
        border.color: Qt.alpha(PlasmaCore.Theme.textColor, 0.35)

        // Aba de cabeçalho com o mês atual.
        Rectangle {
            id: header
            width: parent.width
            height: parent.height * root.headerRatio
            radius: parent.radius
            color: PlasmaCore.Theme.highlightColor

            PlasmaComponents3.Label {
                text: root.currentMonth
                anchors.centerIn: parent
                font.pixelSize: parent.height * 0.52
                font.bold: true
                color: PlasmaCore.Theme.highlightedTextColor
            }
        }

        // Número do dia.
        PlasmaComponents3.Label {
            text: root.currentDay
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: parent.width * 0.46
            font.bold: true
            color: PlasmaCore.Theme.textColor
        }
    }
}
