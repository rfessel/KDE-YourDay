/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Página de Notícias: extraída do main.qml (v2.5.5+). Headers agora usam o
    pageHeader padrão de 48 px — "Atualizado às %1" ficou no tooltip do botão
    de atualizar, não mais debaixo dele.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../js/feeds.js" as FeedParser

Item {
    id: page

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Cabeçalho padrão (48 px) com o botão de atualizar à direita.
        PageHeader {
            title: i18n("Here are the top news of interest to you")
            margins: 0

            PlasmaComponents3.ToolButton {
                id: newsRefreshBtn
                onClicked: root.loadAll()
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: root.lastUpdated === ""
                                    ? i18n("Refresh news")
                                    : i18n("Refresh news") + "\n" + i18n("Updated at %1", root.lastUpdated)

                contentItem: Item {
                    implicitWidth: 36
                    implicitHeight: 36

                    Kirigami.Icon {
                        id: newsRefreshIcon
                        source: "view-refresh"
                        anchors.centerIn: parent
                        width: 20
                        height: 20

                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: root.loading
                        }
                    }
                }

                background: Rectangle {
                    radius: Kirigami.Units.smallSpacing
                    color: newsRefreshBtn.hovered
                           ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.1)
                           : newsRefreshBtn.pressed
                             ? Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.15)
                             : "transparent"
                }
            }
        }

        // Corpo rolante: ListView de coluna única com delegação reciclada,
        // barra de rolagem e textura de fundo.
        Item {
            id: bodyArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: newsList
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Espaço reservado para a barra de rolagem, para que
                // ela não sobreponha os cards (ver newsCardDelegate).
                readonly property real scrollGutter: newsScrollBar.visible ? newsScrollBar.width : 0
                model: root.slicedAll
                delegate: newsCardDelegate
                cacheBuffer: 600
                spacing: Kirigami.Units.smallSpacing
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                    id: newsScrollBar
                    policy: QQC2.ScrollBar.AsNeeded
                }
            }

            // Carregando…
            QQC2.BusyIndicator {
                anchors.centerIn: parent
                visible: root.loading && root.slicedAll.length === 0
                running: visible
            }

            // Estado vazio
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                visible: !root.loading && root.slicedAll.length === 0

                icon.name: root.iconResolvedName
                icon.source: root.iconResolvedSource
                text: root.currentFeeds().length === 0
                      ? i18n("No feeds configured.\nAdd RSS feeds in Settings.")
                      : (root.errorText === ""
                         ? i18n("No news found")
                         : i18n("No news loaded. See details below."))

                helpfulAction: Kirigami.Action {
                    text: root.currentFeeds().length === 0 ? i18n("Open settings") : i18n("Try again")
                    icon.name: root.currentFeeds().length === 0 ? "configure" : "view-refresh"
                    onTriggered: root.currentFeeds().length === 0 ? root.openConfig() : root.loadAll()
                }
            }

            // Rodapé da aba Notícias (erros). Fica DENTRO do conteúdo para não
            // roubar altura da barra lateral (mantém a posição do botão
            // Configurações) quando a aba está aberta.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.InlineMessage {
                    id: errorMessage
                    Layout.fillWidth: true
                    visible: root.errorText !== ""
                    type: Kirigami.MessageType.Warning
                    text: i18n("Some feeds failed to load:") + "\n" + root.errorText
                    showCloseButton: true
                    onVisibleChanged: if (!visible) root.errorText = ""
                }
            }
        }
    }

    // Delegação reciclada dos cards de notícia (movida do main.qml).
    Component {
        id: newsCardDelegate

        Rectangle {
            id: card
            required property var model
            readonly property bool featured: index === 0

            readonly property bool hovered: cardMouse.containsMouse

            // Largura descontada da barra de rolagem vertical (que no QQC2
            // sobrepõe o conteúdo por padrão) e do respiro à direita, que
            // ficou a cargo do conteúdo com a barra encostada na borda.
            width: ListView.view.width - ListView.view.scrollGutter - Kirigami.Units.largeSpacing
            height: card.featured
                   ? Math.max(180, Math.min(300, contentText.implicitHeight + 24))
                   : Math.max(120, Math.min(212, contentText.implicitHeight + 16))
            radius: Kirigami.Units.roundIconSize / 4
            color: card.hovered
                   ? root.accentSoft
                   : root.cardBg
            border.width: 1
            border.color: card.featured ? root.accentBorder : root.cardBorder

            Behavior on color {
                enabled: false // Desabilitado para performance
            }

            // Destaque editorial para a notícia principal (índice 0).
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: card.featured ? 4 : 0
                radius: 2
                color: root.accentMain
                visible: card.featured
            }

            Rectangle {
                id: thumbBox
                visible: card.model.image !== ""
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                width: card.featured ? 128 : 84
                height: card.featured ? 150 : 96
                radius: 6
                color: root.isDarkTheme ? Qt.rgba(0.28, 0.28, 0.28, 1) : Qt.rgba(0.92, 0.92, 0.92, 1)
                clip: true

                Loader {
                    anchors.fill: parent
                    active: card.model.image !== ""
                    asynchronous: true
                    sourceComponent: Component {
                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: card.model.image
                            sourceSize: card.featured ? Qt.size(128, 150) : Qt.size(84, 96)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    thumbBox.visible = false;
                                }
                            }
                        }
                    }
                }
            }

            Column {
                id: contentText
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.right: thumbBox.visible ? thumbBox.left : parent.right
                anchors.rightMargin: 8
                spacing: 2

                PlasmaComponents3.Label {
                    width: contentText.width
                    text: card.model.title
                    wrapMode: Text.Wrap
                    maximumLineCount: card.featured ? 3 : 2
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    font.pixelSize: card.featured ? 16 : 13
                    color: root.textMain
                }

                PlasmaComponents3.Label {
                    width: contentText.width
                    anchors.topMargin: 2
                    visible: card.model.summary !== "" && root.headlineLines > 0
                    text: card.model.summary
                    wrapMode: Text.Wrap
                    maximumLineCount: root.headlineLines + (card.featured ? 1 : 0)
                    elide: Text.ElideRight
                    font.pixelSize: card.featured ? 13 : 12
                    color: Qt.alpha(root.textMain, 0.72)
                }

                Row {
                    width: contentText.width
                    anchors.topMargin: 2
                    spacing: 4

                    PlasmaComponents3.Label {
                        width: Math.min(contentText.width * 0.6, 220)
                        text: card.model.source
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.65)
                    }
                    PlasmaComponents3.Label {
                        visible: card.model.time > 0 && card.model.source !== ""
                        text: "•"
                        font.pixelSize: 11
                        color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.45)
                    }
                    PlasmaComponents3.Label {
                        text: FeedParser.relativeTime(card.model.time)
                        font.pixelSize: 11
                        color: Qt.alpha((root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)), 0.45)
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(card.model.link)
                onPressed: card.opacity = 0.8
                onReleased: card.opacity = 1
            }
        }
    }
}