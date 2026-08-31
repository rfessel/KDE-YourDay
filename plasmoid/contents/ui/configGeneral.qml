/*
    SPDX-FileCopyrightText: 2026 Rafael Fessel
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.kcmutils as KCM

import "js/feeds.js" as FeedParser

KCM.ScrollViewKCM {
    id: page

    // ---------------------------------------------------------- configuração

    function feeds() {
        var f = Plasmoid.configuration.feeds;
        if (typeof f === "undefined" || f === null) {
            return [];
        }
        return f;
    }

    function rawLimits() {
        var l = Plasmoid.configuration.feedLimits;
        if (typeof l === "undefined" || l === null) {
            return [];
        }
        return l;
    }

    // Configuração alinhada com feeds: mesmo comprimento, vazio = padrão.
    function limits() {
        var f = feeds();
        var l = rawLimits();
        var out = [];
        for (var i = 0; i < f.length; i++) {
            out.push(l[i] !== undefined && l[i] !== null ? String(l[i]) : "");
        }
        return out;
    }

    function limitAt(index) {
        var v = parseInt(limits()[index], 10);
        if (isNaN(v) || v <= 0) {
            return 50; // padrão
        }
        return v;
    }

    function saveFeeds(list) {
        Plasmoid.configuration.feeds = list;
        feedModel.clear();
        for (var i = 0; i < list.length; i++) {
            feedModel.append({ url: list[i] });
        }
    }

    function saveLimits(list) {
        Plasmoid.configuration.feedLimits = list;
    }

    // Retorna " " quando ok (feed adicionado) ou a mensagem de erro.
    function tryAddFeed(url) {
        var u = (url || "").trim();
        if (!u || (u.indexOf("http://") !== 0 && u.indexOf("https://") !== 0)) {
            return i18n("Informe uma URL válida (ex.: https://exemplo.com/feed.xml).");
        }
        var list = feeds().slice();
        if (list.indexOf(u) !== -1) {
            return i18n("Esse feed já foi adicionado.");
        }
        list.push(u);
        var l = limits().slice();
        l.push("");
        saveLimits(l);
        saveFeeds(list);
        return "";
    }

    function removeFeed(index) {
        var list = feeds().slice();
        list.splice(index, 1);
        var l = limits().slice();
        l.splice(index, 1);
        saveLimits(l);
        saveFeeds(list);
    }

    function setLimit(index, value) {
        var l = limits().slice();
        l[index] = String(value);
        saveLimits(l);
    }

    // ---------------------------------------- atualização automática

    function refreshDefault() {
        var v = Number(Plasmoid.configuration.refreshMinutes);
        if (typeof Plasmoid.configuration.refreshMinutes === "undefined"
                || v === null || isNaN(v)) {
            return 10;
        }
        return v;
    }

    function minutesLabel(m) {
        var label;
        if (m === 5) {
            label = "A cada 5 minutos";
        } else if (m === 10) {
            label = "A cada 10 minutos";
        } else if (m === 15) {
            label = "A cada 15 minutos";
        } else if (m === 30) {
            label = "A cada 30 minutos";
        } else if (m === 60) {
            label = "A cada 1 hora";
        } else {
            label = "Atualizar manualmente";
        }
        return (typeof i18n === "function") ? i18n(label) : label;
    }

    property var refreshOptions: [
        { v: 5,  t: page.minutesLabel(5) },
        { v: 10, t: page.minutesLabel(10) },
        { v: 15, t: page.minutesLabel(15) },
        { v: 30, t: page.minutesLabel(30) },
        { v: 60, t: page.minutesLabel(60) },
        { v: 0,  t: page.minutesLabel(0) }
    ]

    function refreshIndexFor(m) {
        for (var i = 0; i < page.refreshOptions.length; i++) {
            if (page.refreshOptions[i].v === m) {
                return i;
            }
        }
        return page.refreshOptions.length - 1; // manual
    }

    function applyRefresh(m) {
        Plasmoid.configuration.refreshMinutes = m;
    }

    ListModel {
        id: feedModel
    }
    // O id não fica acessível como propriedade de fora do componente
    // (delegates/Repeater): expomos via property.
    property var feedListModel: feedModel

    // ------------------------------------------------------ teste de endereço

    property bool testingUrl: false
    property string testResultText: ""
    property int testResultKind: Kirigami.MessageType.Information
    property int testToken: 0

    Timer {
        id: testTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (page.testingUrl) {
                page.finishTest(-2);
            }
        }
    }

    function msg(t) {
        return (typeof i18n === "function") ? i18n(t) : t;
    }

    function startTest(text) {
        if (page.testingUrl) {
            return;
        }
        var u = (text || "").trim();
        if (!u || (u.indexOf("http://") !== 0 && u.indexOf("https://") !== 0)) {
            page.testResultText = page.msg("Informe uma URL válida (ex.: https://exemplo.com/feed.xml).");
            page.testResultKind = Kirigami.MessageType.Warning;
            return;
        }
        page.testToken++;
        var token = page.testToken;
        page.testingUrl = true;
        page.testResultText = "";
        testTimer.start();
        try {
            FeedParser.loadFeed(u,
                function(items) {
                    if (token !== page.testToken) {
                        return;
                    }
                    page.finishTest(1, items.length);
                },
                function(code) {
                    if (token !== page.testToken) {
                        return;
                    }
                    page.finishTest(0, code);
                }
            );
        } catch (e) {
            if (token !== page.testToken) {
                return;
            }
            testTimer.stop();
            page.testingUrl = false;
            page.testResultText = page.msg("Falha ao testar: " + String(e));
            page.testResultKind = Kirigami.MessageType.Negative;
        }
    }

    function finishTest(ok, codeOrCount) {
        testTimer.stop();
        page.testingUrl = false;
        if (ok) {
            var n = codeOrCount;
            page.testResultText = page.msg("Endereço válido — " + n + " notícia(s) carregadas.");
            page.testResultKind = Kirigami.MessageType.Positive;
        } else {
            var why;
            switch (codeOrCount) {
            case -2:
                why = page.msg("Tempo esgotado ao consultar o endereço.");
                break;
            case -1:
                why = page.msg("Falha de conexão.");
                break;
            case 0:
                why = page.msg("Resposta inválida (não parece RSS/Atom) ou servidor inacessível.");
                break;
            default:
                why = page.msg("Erro HTTP " + codeOrCount + ".");
                break;
            }
            page.testResultText = page.msg("Endereço inválido: ") + why;
            page.testResultKind = Kirigami.MessageType.Negative;
        }
    }

    Component.onCompleted: {
        var list = feeds();
        for (var i = 0; i < list.length; i++) {
            feedModel.append({ url: list[i] });
        }
    }

    // ------------------------------------------------------------------- UI

    view: ListView {
        id: configList
        model: [0]
        interactive: false
        clip: true

        delegate: Item {
            width: configList.width
            height: configList.height

            ColumnLayout {
                id: configRoot
                anchors.fill: parent
                spacing: 0

        // ------------------- Bloco fixo: adicionar/ testar -------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            Layout.leftMargin: 2 * Kirigami.Units.largeSpacing
            Layout.rightMargin: 2 * Kirigami.Units.largeSpacing
            Layout.bottomMargin: 0
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    id: addHeading
                    level: 3
                    Layout.alignment: Qt.AlignVCenter
                    text: i18n("Adicionar feed RSS")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            QQC2.TextField {
                id: urlField
                Layout.fillWidth: true
                placeholderText: i18n("URL do feed (RSS ou Atom)…")
                onAccepted: clickAdd.clicked()
            }

            QQC2.Label {
                id: urlError
                Layout.fillWidth: true
                visible: text !== ""
                color: Kirigami.Theme.negativeTextColor
                font.italic: true
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Item {
                    Layout.fillWidth: true
                }

                QQC2.Button {
                    text: i18n("Limpar")
                    icon.name: "edit-clear"
                    onClicked: {
                        urlField.text = "";
                        urlError.text = "";
                    }
                }

                QQC2.Button {
                    id: clickAdd
                    text: i18n("Adicionar")
                    icon.name: "list-add-symbolic"
                    onClicked: {
                        var err = page.tryAddFeed(urlField.text);
                        urlError.text = err;
                        if (err === "") {
                            urlField.text = "";
                        }
                    }
                }

                QQC2.Button {
                    id: clickTest
                    objectName: "testFeedButton"
                    text: page.testingUrl ? i18n("Testando…") : i18n("Testar")
                    icon.name: "system-run"
                    onClicked: page.startTest(urlField.text)
                }
            }

            QQC2.Label {
                id: testMessage
                objectName: "testResultMessage"
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: page.testResultText !== ""
                text: page.testResultText
                color: page.testResultKind === Kirigami.MessageType.Negative
                       ? Kirigami.Theme.negativeTextColor
                       : (page.testResultKind === Kirigami.MessageType.Positive
                          ? Kirigami.Theme.positiveTextColor
                          : Kirigami.Theme.textColor)
                font.italic: true
                wrapMode: Text.Wrap
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
        }

        // ------------------- Bloco rolável: feeds adicionados -------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.largeSpacing
            Layout.leftMargin: 2 * Kirigami.Units.largeSpacing
            Layout.rightMargin: 2 * Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    level: 3
                    Layout.alignment: Qt.AlignVCenter
                    text: i18n("Seus feeds (%1)", page.feedListModel.count)
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }

                Item {
                    Layout.fillWidth: true
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignVCenter
                    text: i18n("Atualizar")
                    opacity: 0.7
                }

                QQC2.ComboBox {
                    id: refreshCombo
                    objectName: "refreshMenu"
                    Layout.alignment: Qt.AlignVCenter
                    model: page.refreshOptions
                    textRole: "t"
                    currentIndex: page.refreshIndexFor(page.refreshDefault())
                    onActivated: page.applyRefresh(page.refreshOptions[refreshCombo.currentIndex].v)
                    Accessible.name: i18n("Atualização automática dos feeds")
                }
            }

            Kirigami.InlineMessage {
                id: emptyFeedMessage
                Layout.fillWidth: true
                visible: page.feedListModel.count === 0
                type: Kirigami.MessageType.Information
                text: i18n("Nenhum feed adicionado. Cole a URL de um feed no campo acima e clique em “Adicionar”.")
            }

            ListView {
                id: feedList
                objectName: "feedListView"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Kirigami.Units.smallSpacing
                model: page.feedListModel
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                delegate: ColumnLayout {
                    required property int index
                    required property var model

                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: model.url
                            elide: Text.ElideMiddle
                        }

                        QQC2.ToolButton {
                            icon.name: "edit-delete-remove-symbolic"
                            Accessible.name: i18n("Remover feed")
                            onClicked: page.removeFeed(index)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            text: i18n("Limite de notícias deste feed:")
                        }

                        QQC2.SpinBox {
                            objectName: "limitSpinner" + index
                            from: 1
                            to: 200
                            editable: true
                            value: page.limitAt(index)
                            onValueModified: page.setLimit(index, value)
                        }

                        QQC2.Label {
                            text: i18n("notícias")
                            opacity: 0.6
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.margins: 2 * Kirigami.Units.largeSpacing
            text: i18n("O limite total de notícias da lista está na seção “Exibição”. As alterações são aplicadas imediatamente.")
            opacity: 0.6
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
        }
    }
}
}