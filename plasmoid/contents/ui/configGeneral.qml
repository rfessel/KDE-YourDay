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


    property var tabNames: {
        return [i18n("Summary"), i18n("Calendar"), i18n("Tasks"), i18n("Weather"), i18n("Notes"), i18n("Lists"), i18n("News")];
    }

    readonly property string currentIcon: {
        var c = Plasmoid.configuration.customIcon;
        return (c && c.trim() !== "") ? c : Plasmoid.icon;
    }

    readonly property var accentOptions: [i18n("Default (system)"), "#1e88e5", "#8e24aa", "#e53935", "#43a047", "#fb8c00", "#00acc1", "#d81b60"]

    FileDialog {
        id: iconFileDialog
        title: i18n("Choose icon")
        nameFilters: [ i18n("Images (*.png *.jpg *.jpeg *.svg *.webp *.bmp)"), i18n("All files (*)") ]
        onAccepted: {
            var u = iconFileDialog.fileUrl.toString();
            if (u) {
                Plasmoid.configuration.customIcon = u;
                Plasmoid.configuration.iconName = "";
            }
        }
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("General widget settings.")
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
                text: i18n("Default tab on open:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                model: page.tabNames
                currentIndex: Plasmoid.configuration.defaultTab
                onActivated: Plasmoid.configuration.defaultTab = index
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Defines which tab is shown when clicking the widget.")
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
                text: i18n("Theme:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                model: [i18n("Light"), i18n("Dark"), i18n("Automatic")]
                currentIndex: Plasmoid.configuration.themeMode
                onActivated: Plasmoid.configuration.themeMode = index
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Defines the visual theme of the widget.")
            opacity: 0.5
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        // Cor de destaque
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: i18n("Accent color:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                Layout.preferredWidth: 120
                model: page.accentOptions
                currentIndex: {
                    var c = String(Plasmoid.configuration.accentColor || "").trim();
                    var idx = 0;
                    for (var i = 1; i < page.accentOptions.length; i++) {
                        if (page.accentOptions[i] === c) {
                            idx = i;
                            break;
                        }
                    }
                    return idx;
                }
                onActivated: {
                    Plasmoid.configuration.accentColor = (index === 0) ? "" : page.accentOptions[index];
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Color used for widget highlights. Empty = system accent color.")
            opacity: 0.5
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        // Aparência compacta (painel)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: i18n("Panel appearance:")
                font.pixelSize: 13
            }

            Item { Layout.fillWidth: true }

            QQC2.ComboBox {
                model: [i18n("Icon"), i18n("Interactive icon"), i18n("Clock")]
                currentIndex: {
                    var m = Plasmoid.configuration.compactMode;
                    return (m === 0 || m === 2) ? m : 1;
                }
                onActivated: Plasmoid.configuration.compactMode = index
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Defines what is shown when the widget is in the system tray (panel).")
            opacity: 0.5
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        // Idioma segue o locale do sistema (catálogos .mo do Plasma).

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18n("Widget icon")
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
                        text: i18n("System icon")
                        icon.name: "icon-preview"
                        onClicked: {
                            Plasmoid.configuration.customIcon = "";
                            Plasmoid.configuration.iconName = Plasmoid.icon || "view-calendar-day";
                        }
                    }

                    QQC2.Button {
                        text: i18n("File...")
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
