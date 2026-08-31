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
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    readonly property int maxItemsValue: Plasmoid.configuration.maxItems
    readonly property int headlineLinesValue: Plasmoid.configuration.headlineLines
    readonly property int columnsValue: Plasmoid.configuration.columns
    readonly property string currentIcon: {
        var c = Plasmoid.configuration.customIcon;
        return (c && c.trim() !== "") ? c : Plasmoid.icon;
    }
    readonly property string customIcon: Plasmoid.configuration.customIcon
    readonly property var curatedIcons: [
        "view-calendar-day", "view-pim-news", "rss", "application-rss+xml",
        "internet-mail", "internet-web-browser",
        "internet-services", "text-html", "globe"
    ]

    FileDialog {
        id: iconFileDialog
        title: i18n("Escolher ícone")
        nameFilters: [ i18n("Imagens (*.png *.jpg *.jpeg *.svg *.webp *.bmp)"), i18n("Todos os arquivos (*)") ]
        onAccepted: {
            var u = iconFileDialog.fileUrl.toString();
            if (u) {
                page.applyCustomIcon(u);
            }
        }
    }

    function setMaxItems(value) {
        Plasmoid.configuration.maxItems = value;
    }

    function setHeadlineLines(value) {
        Plasmoid.configuration.headlineLines = value;
    }

    function setColumns(value) {
        Plasmoid.configuration.columns = value;
    }

    function applyIcon(name) {
        var n = (name || "").trim();
        if (!n) {
            return;
        }
        Plasmoid.configuration.customIcon = "";
        Plasmoid.configuration.iconName = n;
        Plasmoid.icon = n;
    }

    function applyCustomIcon(url) {
        if (!url) {
            return;
        }
        Plasmoid.configuration.customIcon = url;
        Plasmoid.icon = url;
    }

    function removeCustomIcon() {
        Plasmoid.configuration.customIcon = "";
        Plasmoid.icon = Plasmoid.configuration.iconName || "view-pim-news";
    }

    function restoreDefaultIcon() {
        Plasmoid.configuration.customIcon = "";
        Plasmoid.configuration.iconName = "view-pim-news";
        Plasmoid.icon = "view-pim-news";
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            text: i18n("Exibição")
            textFormat: Text.PlainText
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Máximo total de notícias na lista:")
            }

            QQC2.SpinBox {
                objectName: "globalLimitSpinner"
                from: 1
                to: 200
                editable: true
                value: page.maxItemsValue
                onValueModified: page.setMaxItems(value)
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Linhas da chamada da matéria:")
            }

            QQC2.SpinBox {
                objectName: "headlineLinesSpinner"
                from: 1
                to: 5
                editable: true
                value: page.headlineLinesValue
                onValueModified: page.setHeadlineLines(value)
            }

            QQC2.Label {
                text: i18n("linhas por notícia")
                opacity: 0.6
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Colunas de notícias:")
            }

            QQC2.SpinBox {
                objectName: "columnsSpinner"
                from: 1
                to: 4
                editable: true
                value: page.columnsValue
                onValueModified: page.setColumns(value)
            }

            QQC2.Label {
                text: i18n("colunas no widget")
                opacity: 0.6
            }

            Item {
                Layout.fillWidth: true
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Com mais de 1 coluna, as notícias são distribuídas automaticamente entre as colunas.")
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Este limite vale para a lista inteira, somando todos os feeds. Para ajustar cada fonte individualmente, use a seção “Feeds de notícias”.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("As alterações são aplicadas imediatamente ao widget.")
            opacity: 0.6
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

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Este ícone aparece na barra de tarefas e no próprio widget.")
                opacity: 0.6
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.curatedIcons

                delegate: QQC2.ToolButton {
                    required property string modelData

                    icon.name: modelData
                    checkable: true
                    checked: page.currentIcon === modelData
                    Accessible.name: modelData
                    onClicked: page.applyIcon(modelData)

                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: modelData
                    QQC2.ToolTip.delay: 500
                }
            }

            QQC2.Button {
                text: i18n("Usar padrão")
                icon.name: "edit-clear"
                onClicked: page.restoreDefaultIcon()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: i18n("Carregar arquivo próprio…")
                icon.name: "document-open"
                onClicked: iconFileDialog.open()
            }

            QQC2.Label {
                text: i18n("Use uma imagem (PNG, SVG, JPG…) do seu computador como ícone.")
                opacity: 0.6
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: page.customIcon !== ""

            Kirigami.Icon {
                source: page.customIcon
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Ícone próprio em uso:\n%1", page.customIcon)
                elide: Text.ElideMiddle
                font.pixelSize: 11
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
            }

            QQC2.Button {
                text: i18n("Remover arquivo")
                icon.name: "edit-delete-remove-symbolic"
                onClicked: page.removeCustomIcon()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: iconField
                Layout.preferredWidth: 300
                text: page.currentIcon
                placeholderText: i18n("Digite o nome de um ícone…")
                onEditingFinished: {
                    var t = text.trim();
                    if (t) {
                        page.applyIcon(t);
                    }
                    iconField.text = page.currentIcon;
                }
            }

            QQC2.Label {
                text: i18n("Escolha um dos ícones acima, digite o nome de qualquer ícone do tema (ex.: rss, internet-mail, text-html) ou carregue um arquivo próprio.")
                opacity: 0.6
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}