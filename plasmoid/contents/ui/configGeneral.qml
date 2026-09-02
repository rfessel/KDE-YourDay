/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property var tabNames: [i18n("Resumo"), i18n("Agenda"), i18n("Tarefas"), i18n("Clima"), i18n("Notas"), i18n("Notícias")]

    readonly property string currentIcon: {
        var c = Plasmoid.configuration.customIcon;
        return (c && c.trim() !== "") ? c : Plasmoid.icon;
    }

    FileDialog {
        id: iconFileDialog
        title: i18n("Escolher ícone")
        nameFilters: [ i18n("Imagens (*.png *.jpg *.jpeg *.svg *.webp *.bmp)"), i18n("Todos os arquivos (*)") ]
        onAccepted: {
            var u = iconFileDialog.fileUrl.toString();
            if (u) {
                Plasmoid.configuration.customIcon = u;
                Plasmoid.configuration.iconName = "";
                Plasmoid.icon = u;
            }
        }
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Configurações gerais do widget.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: i18n("Aba padrão ao abrir:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                model: page.tabNames
                currentIndex: Plasmoid.configuration.defaultTab || 0
                onActivated: {
                    Plasmoid.configuration.defaultTab = index;
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Define qual aba será exibida ao clicar no widget.")
            opacity: 0.5
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        // Tema
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: i18n("Tema:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                model: [i18n("Claro"), i18n("Escuro"), i18n("Automático")]
                currentIndex: Plasmoid.configuration.themeMode || 2
                onActivated: {
                    Plasmoid.configuration.themeMode = index;
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Define o tema visual do widget.")
            opacity: 0.5
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18n("Ícone do widget")
            textFormat: Text.PlainText
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: page.currentIcon
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        text: i18n("Ícone do sistema")
                        icon.name: "icon-preview"
                        onClicked: {
                            Plasmoid.configuration.customIcon = "";
                            Plasmoid.configuration.iconName = Plasmoid.icon || "view-calendar-day";
                            Plasmoid.icon = Plasmoid.configuration.iconName;
                        }
                    }

                    QQC2.Button {
                        text: i18n("Arquivo...")
                        icon.name: "document-open"
                        onClicked: iconFileDialog.open()
                    }
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    visible: Plasmoid.configuration.customIcon !== ""
                    text: Plasmoid.configuration.customIcon
                    opacity: 0.5
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                }
            }
        }
    }
}
