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
import "js/i18n.js" as I18n

import "js/feeds.js" as FeedParser

KCM.SimpleKCM {
    id: page

    property string _lang: Plasmoid.configuration.language || ""

    function t(text) {
        if (!_lang) return text;
        return I18n.translate(text, _lang);
    }

    function feeds() {
        var f = Plasmoid.configuration.feeds;
        if (typeof f === "undefined" || f === null) return [];
        return f;
    }

    function rawLimits() {
        var l = Plasmoid.configuration.feedLimits;
        if (typeof l === "undefined" || l === null) return [];
        return l;
    }

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
        if (isNaN(v) || v <= 0) return 50;
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

    function tryAddFeed(url) {
        var u = (url || "").trim();
        if (!u || (u.indexOf("http://") !== 0 && u.indexOf("https://") !== 0)) {
            return t("Informe uma URL válida (ex.: https://exemplo.com/feed.xml).");
        }
        var list = feeds().slice();
        if (list.indexOf(u) !== -1) {
            return t("Esse feed já foi adicionado.");
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

    function applyRefresh(m) {
        Plasmoid.configuration.refreshMinutes = m;
    }

    ListModel {
        id: feedModel
    }
    property var feedListModel: feedModel

    property bool testingUrl: false
    property string testResultText: ""
    property int testResultKind: Kirigami.MessageType.Information
    property int testToken: 0

    Timer {
        id: testTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (page.testingUrl) page.finishTest(-2);
        }
    }

    function startTest(text) {
        if (page.testingUrl) return;
        var u = (text || "").trim();
        if (!u || (u.indexOf("http://") !== 0 && u.indexOf("https://") !== 0)) {
            page.testResultText = t("Informe uma URL válida.");
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
                    if (token !== page.testToken) return;
                    page.finishTest(1, items.length);
                },
                function(code) {
                    if (token !== page.testToken) return;
                    page.finishTest(0, code);
                }
            );
        } catch (e) {
            if (token !== page.testToken) return;
            testTimer.stop();
            page.testingUrl = false;
            page.testResultText = t("Falha ao testar: ") + String(e);
            page.testResultKind = Kirigami.MessageType.Negative;
        }
    }

    function finishTest(ok, codeOrCount) {
        testTimer.stop();
        page.testingUrl = false;
        if (ok) {
            page.testResultText = t("Endereço válido — %1 notícia(s) carregada(s).", codeOrCount);
            page.testResultKind = Kirigami.MessageType.Positive;
        } else {
            var why;
            switch (codeOrCount) {
            case -2: why = t("Tempo esgotado."); break;
            case -1: why = t("Falha de conexão."); break;
            case 0:  why = t("Resposta inválida."); break;
            default: why = t("Erro HTTP %1.", codeOrCount); break;
            }
            page.testResultText = t("Endereço inválido: ") + why;
            page.testResultKind = Kirigami.MessageType.Negative;
        }
    }

    property var refreshOptions: [
        { v: 5,  t: t("A cada 5 minutos") },
        { v: 10, t: t("A cada 10 minutos") },
        { v: 15, t: t("A cada 15 minutos") },
        { v: 30, t: t("A cada 30 minutos") },
        { v: 60, t: t("A cada 1 hora") },
        { v: 0,  t: t("Atualizar manualmente") }
    ]

    function refreshIndexFor(m) {
        for (var i = 0; i < page.refreshOptions.length; i++) {
            if (page.refreshOptions[i].v === m) return i;
        }
        return page.refreshOptions.length - 1;
    }

    Component.onCompleted: {
        var list = feeds();
        for (var i = 0; i < list.length; i++) {
            feedModel.append({ url: list[i] });
        }
    }

    ColumnLayout {
        width: page.width
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            text: t("Adicionar feed RSS")
            textFormat: Text.PlainText
        }

        QQC2.TextField {
            id: urlField
            Layout.fillWidth: true
            placeholderText: t("URL do feed (RSS ou Atom)...")
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

            Item { Layout.fillWidth: true }

            QQC2.Button {
                text: t("Limpar")
                icon.name: "edit-clear"
                onClicked: {
                    urlField.text = "";
                    urlError.text = "";
                }
            }

            QQC2.Button {
                id: clickAdd
                text: t("Adicionar")
                icon.name: "list-add"
                onClicked: {
                    var err = page.tryAddFeed(urlField.text);
                    urlError.text = err;
                    if (err === "") urlField.text = "";
                }
            }

            QQC2.Button {
                text: page.testingUrl ? t("Testando...") : t("Testar")
                icon.name: "system-run"
                onClicked: page.startTest(urlField.text)
            }
        }

        QQC2.Label {
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

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: t("Seus feeds (%1)", page.feedListModel.count)
            textFormat: Text.PlainText
        }

        Repeater {
            model: page.feedListModel
            delegate: ColumnLayout {
                required property int index
                required property var model
                Layout.fillWidth: true
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
                        icon.name: "list-remove"
                        Accessible.name: t("Remover feed")
                        onClicked: page.removeFeed(index)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: t("Limite:")
                        font.pixelSize: 11
                        opacity: 0.7
                    }

                    QQC2.SpinBox {
                        from: 1
                        to: 200
                        editable: true
                        value: page.limitAt(index)
                        onValueModified: page.setLimit(index, value)
                    }

                    QQC2.Label {
                        text: t("notícias")
                        font.pixelSize: 11
                        opacity: 0.6
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: t("Exibição")
            textFormat: Text.PlainText
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label { text: t("Máximo total de notícias:") }

            QQC2.SpinBox {
                from: 1
                to: 200
                editable: true
                value: Plasmoid.configuration.maxItems
                onValueModified: Plasmoid.configuration.maxItems = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label { text: t("Linhas da chamada:") }

            QQC2.SpinBox {
                from: 1
                to: 5
                editable: true
                value: Plasmoid.configuration.headlineLines
                onValueModified: Plasmoid.configuration.headlineLines = value
            }

            QQC2.Label { text: t("linhas por notícia"); opacity: 0.6 }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label { text: t("Atualizar:") }

            QQC2.ComboBox {
                model: page.refreshOptions
                textRole: "t"
                currentIndex: page.refreshIndexFor(Plasmoid.configuration.refreshMinutes)
                onActivated: page.applyRefresh(page.refreshOptions[currentIndex].v)
            }

            Item { Layout.fillWidth: true }
        }
    }
}
