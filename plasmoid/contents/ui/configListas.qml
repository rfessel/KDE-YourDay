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
import org.kde.plasma.plasmoid 2.0

ColumnLayout {
    id: page


    property var listsData: {
        var raw = Plasmoid.configuration.lists;
        var out = [];
        if (raw) {
            for (var i = 0; i < raw.length; i++) {
                var entry = String(raw[i] || "").trim();
                var name = "";
                var items = [];
                // Formato atual: cada lista é um JSON {"name","items","done"}.
                if (entry.charAt(0) === "{") {
                    try {
                        var obj = JSON.parse(entry);
                        name = obj.name || "";
                        var it = obj.items || [];
                        for (var k = 0; k < it.length; k++) {
                            items.push({ text: String(it[k].text || ""), done: !!it[k].done });
                        }
                        out.push({ name: name, items: items });
                        continue;
                    } catch (e) {
                        // cai no fallback legado abaixo
                    }
                }
                // Formato antigo: "nome|0/1|item1;item2".
                var parts = entry.split("|");
                name = parts[0];
                var itemsPart = "";
                if (parts.length >= 3) {
                    itemsPart = parts[2];
                } else if (parts.length >= 2) {
                    itemsPart = parts[1];
                }
                if (itemsPart) {
                    var itemParts = itemsPart.split(";");
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
        text: i18n("Lists")
        Layout.fillWidth: true
    }

    QQC2.Label {
        text: i18n("Export your lists to a file.")
        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
        opacity: 0.7
        Layout.fillWidth: true
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    QQC2.Label {
        text: i18n("Available lists: %1", listsData.length)
        color: root.isDarkTheme ? Qt.rgba(0.93, 0.93, 0.93, 1) : Qt.rgba(0.13, 0.13, 0.13, 1)
        Layout.fillWidth: true
    }

    // Exportar como TXT
    QQC2.Button {
        text: i18n("Export as TXT")
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
        text: i18n("Export as CSV (Spreadsheet)")
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
        title: i18n("Save as TXT")
        fileMode: FileDialog.SaveFile
        nameFilters: [i18n("Text file (*.txt)")]
        onAccepted: {
            saveFile(selectedFile, exportContent);
        }
    }

    FileDialog {
        id: csvFileDialog
        title: i18n("Save as CSV")
        fileMode: FileDialog.SaveFile
        nameFilters: [i18n("CSV file (*.csv)")]
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
