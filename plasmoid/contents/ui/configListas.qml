/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later

    Configuração de Listas: exportação para TXT/CSV.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    property var listsData: {
        var raw = Plasmoid.configuration.lists;
        var out = [];
        if (raw) {
            for (var i = 0; i < raw.length; i++) {
                var parts = raw[i].split("|");
                var name = parts[0];
                var items = [];
                if (parts[1]) {
                    var itemParts = parts[1].split(";");
                    for (var j = 0; j < itemParts.length; j++) {
                        var ip = itemParts[j].split("|");
                        items.push({ text: ip[1] || "", done: ip[0] === "1" });
                    }
                }
                out.push({ name: name, items: items });
            }
        }
        return out;
    }

    property string exportContent: ""
    property string exportFormat: ""

    spacing: Kirigami.Units.smallSpacing

    Kirigami.Heading {
        level: 2
        text: i18n("Listas")
        Layout.fillWidth: true
    }

    QQC2.Label {
        text: i18n("Exportar suas listas para arquivo.")
        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
        opacity: 0.7
        Layout.fillWidth: true
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    QQC2.Label {
        text: i18n("Listas disponíveis: %1", listsData.length)
        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
        Layout.fillWidth: true
    }

    // Exportar como TXT
    QQC2.Button {
        text: i18n("Exportar como TXT")
        icon.name: "document-export"
        Layout.fillWidth: true
        onClicked: {
            var content = generateTxt();
            exportContent = content;
            exportFormat = "txt";
            txtFileDialog.open();
        }
    }

    // Exportar como CSV
    QQC2.Button {
        text: i18n("Exportar como CSV (Planilha)")
        icon.name: "document-export"
        Layout.fillWidth: true
        onClicked: {
            var content = generateCsv();
            exportContent = content;
            exportFormat = "csv";
            csvFileDialog.open();
        }
    }

    function generateTxt() {
        var lines = [];
        for (var i = 0; i < listsData.length; i++) {
            var list = listsData[i];
            lines.push("=== " + list.name + " ===");
            lines.push("");
            for (var j = 0; j < list.items.length; j++) {
                var item = list.items[j];
                var check = item.done ? "[x]" : "[ ]";
                lines.push(check + " " + item.text);
            }
            lines.push("");
        }
        return lines.join("\n");
    }

    function generateCsv() {
        var lines = [];
        lines.push("Lista;Item;Concluído");
        for (var i = 0; i < listsData.length; i++) {
            var list = listsData[i];
            for (var j = 0; j < list.items.length; j++) {
                var item = list.items[j];
                var done = item.done ? "Sim" : "Não";
                lines.push(list.name + ";" + item.text + ";" + done);
            }
        }
        return lines.join("\n");
    }

    FileDialog {
        id: txtFileDialog
        title: i18n("Salvar como TXT")
        fileMode: FileDialog.SaveFile
        nameFilters: [i18n("Arquivo de texto (*.txt)")]
        onAccepted: {
            saveFile(selectedFile, exportContent);
        }
    }

    FileDialog {
        id: csvFileDialog
        title: i18n("Salvar como CSV")
        fileMode: FileDialog.SaveFile
        nameFilters: [i18n("Arquivo CSV (*.csv)")]
        onAccepted: {
            saveFile(selectedFile, exportContent);
        }
    }

    function saveFile(url, content) {
        var xhr = new XMLHttpRequest();
        xhr.open("PUT", url, false);
        xhr.send(content);
        if (xhr.status === 0) {
            console.log("[yourday] Lista exportada com sucesso para:", url);
        } else {
            console.log("[yourday] Erro ao exportar lista:", xhr.statusText);
        }
    }
}
