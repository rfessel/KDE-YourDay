/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Cabeçalho padrão de TODAS as abas: título de 13 px à esquerda, ações à
    direita, altura fixa de 48 px e separador com as mesmas margins.
    Substitui os blocos copiados em cada página (58 px na Notícias, sem
    header no Clima, sistema próprio no Resumo).

    As cores vêm do `root` do ambiente (main.qml no widget; o root de teste
    no qmltestrunner), exatamente como nas páginas.
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: pageHeader

    // Cor do título/separtor no tema do widget (mesmo padrão das páginas).
    readonly property color headerTextColor: root.isDarkTheme
        ? Qt.rgba(0.93, 0.93, 0.93, 1)
        : Qt.rgba(0.13, 0.13, 0.13, 1)

    // Título da aba (13 px, à esquerda).
    property string title: ""

    // Margem horizontal aplicada no título E no separador. Cada página
    // preserva a do próprio conteúdo (título + início do conteúdo não mexem).
    property real margins: Kirigami.Units.smallSpacing

    // Altura FIXA da faixa do título em todas as abas.
    readonly property int titleHeight: 48

    // Ações à direita do título (botões injetados como filhos).
    default property alias actions: actionsRow.data

    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        id: actionsRow
        objectName: "pageHeaderRow"
        Layout.fillWidth: true
        Layout.preferredHeight: pageHeader.titleHeight
        Layout.leftMargin: pageHeader.margins
        Layout.rightMargin: pageHeader.margins
        spacing: Kirigami.Units.smallSpacing

        PlasmaExtras.Heading {
            level: 4
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: pageHeader.title
            elide: Text.ElideRight
            font.pixelSize: 13
            color: pageHeader.headerTextColor
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.leftMargin: pageHeader.margins
        Layout.rightMargin: pageHeader.margins
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        color: Qt.alpha(pageHeader.headerTextColor, 0.15)
    }
}