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

import "js/i18n.js" as I18n

KCM.SimpleKCM {
    id: page

    property string _lang: cfg_language || ""

    function t(text) {
        if (!_lang) return text;
        return I18n.translate(text, _lang);
    }

    property var tabNames: {
        var _ = _lang;
        return [t("Resumo"), t("Agenda"), t("Tarefas"), t("Clima"), t("Notas"), t("Notícias")];
    }

    readonly property string currentIcon: {
        var c = cfg_customIcon;
        return (c && c.trim() !== "") ? c : Plasmoid.icon;
    }

    FileDialog {
        id: iconFileDialog
        title: t("Escolher ícone")
        nameFilters: [ t("Imagens (*.png *.jpg *.jpeg *.svg *.webp *.bmp)"), t("Todos os arquivos (*)") ]
        onAccepted: {
            var u = iconFileDialog.fileUrl.toString();
            if (u) {
                cfg_customIcon = u;
                cfg_iconName = "";
            }
        }
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: t("Configurações gerais do widget.")
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
                text: t("Aba padrão ao abrir:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                model: page.tabNames
                currentIndex: cfg_defaultTab
                onActivated: cfg_defaultTab = index
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: t("Define qual aba será exibida ao clicar no widget.")
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
                text: t("Tema:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                model: [t("Claro"), t("Escuro"), t("Automático")]
                currentIndex: cfg_themeMode
                onActivated: cfg_themeMode = index
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: t("Define o tema visual do widget.")
            opacity: 0.5
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        // Idioma
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: t("Idioma:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                id: languageCombo
                model: ListModel {
                    ListElement { text: "Seguir idioma do sistema"; value: "" }
                    ListElement { text: "Português (Brasil)"; value: "pt_BR" }
                    ListElement { text: "English"; value: "en" }
                    ListElement { text: "Español"; value: "es" }
                    ListElement { text: "Français"; value: "fr" }
                    ListElement { text: "Deutsch"; value: "de" }
                    ListElement { text: "Italiano"; value: "it" }
                    ListElement { text: "日本語"; value: "ja" }
                    ListElement { text: "Русский"; value: "ru" }
                    ListElement { text: "עברית"; value: "he" }
                    ListElement { text: "中文"; value: "zh_CN" }
                }
                textRole: "text"
                currentIndex: {
                    var lang = cfg_language || "";
                    if (lang === "") return 0;
                    for (var i = 1; i < languageCombo.count; i++) {
                        if (languageCombo.model.get(i).value === lang) return i;
                    }
                    return 0;
                }
                onActivated: {
                    cfg_language = index === 0 ? "" : languageCombo.model.get(index).value;
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: t("Força o idioma do widget. Se vazio, segue o idioma do sistema.")
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
            text: t("Ícone do widget")
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
                        text: t("Ícone do sistema")
                        icon.name: "icon-preview"
                        onClicked: {
                            cfg_customIcon = "";
                            cfg_iconName = Plasmoid.icon || "view-calendar-day";
                        }
                    }

                    QQC2.Button {
                        text: t("Arquivo...")
                        icon.name: "document-open"
                        onClicked: iconFileDialog.open()
                    }
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    visible: cfg_customIcon !== ""
                    text: cfg_customIcon
                    opacity: 0.5
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                }
            }
        }
    }
}
