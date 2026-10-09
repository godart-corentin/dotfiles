// Sélecteur d'emojis en français : grille par catégorie, recherche (noms et mots-clés), récents et couleur de peau.
// Données : emojis.json, généré depuis emojibase-data 17.0.0 (fr/data.json), limité à Emoji 16 que gère Noto Color Emoji :
//   jq -c '[.[] | select(.group != null and .group != 2 and .version <= 16)] | sort_by(.order)
//     | map({e: .emoji, n: .label, t: ((.tags // []) | join(" ")), g: .group}
//       + (if .skins then {s: [.skins[] | select(.tone | type == "number") | .emoji]} else {} end))' data.json
// Ouverture : qs-outil emojis (Super+;).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property var categories: [
        { id: -1, icon: "history", title: "Récents" },
        { id: 0, icon: "mood", title: "Smileys et émotions" },
        { id: 1, icon: "front_hand", title: "Personnes" },
        { id: 3, icon: "pets", title: "Animaux et nature" },
        { id: 4, icon: "restaurant", title: "Nourriture et boissons" },
        { id: 5, icon: "flight", title: "Voyages et lieux" },
        { id: 6, icon: "sports_soccer", title: "Activités" },
        { id: 7, icon: "lightbulb", title: "Objets" },
        { id: 8, icon: "emoji_symbols", title: "Symboles" },
        { id: 9, icon: "flag", title: "Drapeaux" }
    ]
    readonly property var tones: ["✋", "✋🏻", "✋🏼", "✋🏽", "✋🏾", "✋🏿"]

    property var emojis: []
    property var byEmoji: ({})
    property var recents: []
    property int tone: 0
    property int category: 0
    property string query: ""

    readonly property var shown: {
        const query = normalize(root.query.trim());
        if (query) {
            // Les noms qui commencent par la recherche passent devant les simples mots-clés.
            const starts = [], others = [];
            for (const emoji of emojis) {
                if (emoji.name.startsWith(query))
                    starts.push(emoji);
                else if (emoji.search.includes(query))
                    others.push(emoji);
            }
            return starts.concat(others);
        }
        if (category === -1)
            return recents.map(e => byEmoji[e]).filter(e => e);
        return emojis.filter(e => e.g === category);
    }
    readonly property var current: grid.currentIndex >= 0 && grid.currentIndex < shown.length ? shown[grid.currentIndex] : null

    function normalize(text: string): string {
        // « coeur » trouve « cœur », « qu'il » trouve « qu’il ».
        return text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/œ/g, "oe").replace(/æ/g, "ae").replace(/’/g, "'");
    }

    function glyph(emoji: var): string {
        return tone > 0 && emoji.s ? emoji.s[tone - 1] : emoji.e;
    }

    function choose(emoji: var): void {
        if (!emoji)
            return;
        Quickshell.execDetached(["wl-copy", "--", glyph(emoji)]);
        recents = [emoji.e].concat(recents.filter(e => e !== emoji.e)).slice(0, 36);
        saveState();
        popup.close();
    }

    function saveState(): void {
        stateFile.setText(JSON.stringify({ recents, tone }) + "\n");
    }

    function selectCategory(id: int): void {
        search.text = "";
        category = id;
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
    }

    FileView {
        path: Quickshell.shellPath("emojis.json")
        onLoaded: {
            const emojis = JSON.parse(text());
            const byEmoji = {};
            for (const emoji of emojis) {
                emoji.name = root.normalize(emoji.n);
                emoji.search = root.normalize(`${emoji.n} ${emoji.t}`);
                byEmoji[emoji.e] = emoji;
            }
            root.byEmoji = byEmoji;
            root.emojis = emojis;
        }
    }

    FileView {
        id: stateFile

        path: Quickshell.env("HOME") + "/.local/state/emojis.json"
        printErrors: false
        // Écriture synchrone : l'état est enregistré juste avant de quitter.
        blockWrites: true
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.recents = saved.recents ?? [];
                root.tone = saved.tone ?? 0;
                if (root.recents.length > 0)
                    root.category = -1;
            } catch (e) {}
        }
    }

    Popup {
        id: popup

        layerName: "emojis"
        panelWidth: 760

        Header {
            icon: "add_reaction"
            title: "Emojis"
            subtitle: "Tape pour chercher · Entrée pour copier · Tab pour changer de catégorie"
        }

        SearchField {
            id: search

            placeholder: "Chercher un emoji (cœur, chat, fête…)"
            onTextChanged: {
                root.query = text;
                grid.currentIndex = 0;
                grid.positionViewAtBeginning();
            }
            onCloseRequested: popup.close()
            onKeyPressed: event => {
                const ids = root.categories.map(c => c.id);
                if (event.key === Qt.Key_Left)
                    grid.moveCurrentIndexLeft();
                else if (event.key === Qt.Key_Right)
                    grid.moveCurrentIndexRight();
                else if (event.key === Qt.Key_Up)
                    grid.moveCurrentIndexUp();
                else if (event.key === Qt.Key_Down)
                    grid.moveCurrentIndexDown();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.choose(root.current);
                else if (event.key === Qt.Key_Tab)
                    root.selectCategory(ids[(ids.indexOf(root.category) + 1) % ids.length]);
                else if (event.key === Qt.Key_Backtab)
                    root.selectCategory(ids[(ids.indexOf(root.category) + ids.length - 1) % ids.length]);
                else
                    return;
                event.accepted = true;
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.categories

                Rectangle {
                    id: tab

                    required property var modelData

                    readonly property bool active: !root.query && root.category === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 20
                    color: active ? Theme.colour("secondaryContainer") : tabArea.containsMouse ? Qt.alpha(Theme.colour("onSurface"), 0.08) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        text: tab.modelData.icon
                        color: tab.active ? Theme.colour("onSecondaryContainer") : Theme.colour("onSurfaceVariant")
                    }

                    MouseArea {
                        id: tabArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectCategory(tab.modelData.id)
                    }
                }
            }
        }

        Label {
            text: root.query ? `${root.shown.length} résultat${root.shown.length > 1 ? "s" : ""}` : root.categories.find(c => c.id === root.category).title
            color: Theme.colour("primary")
            font.weight: Font.Medium
        }

        GridView {
            id: grid

            readonly property int columns: Math.floor(width / 52)

            Layout.fillWidth: true
            Layout.preferredHeight: 52 * 6
            cellWidth: width / columns
            cellHeight: 52
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            highlight: Rectangle {
                radius: 14
                color: Theme.colour("secondaryContainer")
            }

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                Text {
                    anchors.centerIn: parent
                    text: root.glyph(cell.modelData)
                    font.family: "Noto Color Emoji"
                    font.pixelSize: 28
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: grid.currentIndex = cell.index
                    onClicked: root.choose(cell.modelData)
                }
            }

            Label {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: root.query ? "Aucun emoji ne correspond" : "Aucun emoji récent"
                color: Theme.colour("onSurfaceVariant")
            }
        }

        Card {
            implicitHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 14

                Text {
                    text: root.current ? root.glyph(root.current) : ""
                    font.family: "Noto Color Emoji"
                    font.pixelSize: 32
                }

                Label {
                    Layout.fillWidth: true
                    text: root.current?.n ?? ""
                    elide: Text.ElideRight
                }

                Repeater {
                    model: root.tones

                    Rectangle {
                        id: toneChip

                        required property string modelData
                        required property int index

                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        color: root.tone === index ? Theme.colour("secondaryContainer") : toneArea.containsMouse ? Qt.alpha(Theme.colour("onSurface"), 0.08) : "transparent"
                        border.width: root.tone === index ? 2 : 0
                        border.color: Theme.colour("primary")

                        Text {
                            anchors.centerIn: parent
                            text: toneChip.modelData
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: toneArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.tone = toneChip.index;
                                root.saveState();
                            }
                        }
                    }
                }
            }
        }
    }
}
