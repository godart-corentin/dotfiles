// Aide-mémoire des raccourcis Hyprland, lu en direct depuis `hyprctl binds`.
// Chaque raccourci est décrit dans binds.lua sous la forme « Catégorie › Action » ;
// les raccourcis qui partagent une description sont regroupés sur une ligne.
// Ouverture : qs-outil raccourcis (Super+F1).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property var modifiers: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Maj"]]
    readonly property var keyNames: ({
            Return: "Entrée",
            Escape: "Échap",
            Space: "Espace",
            Tab: "Tab",
            Left: "←",
            Right: "→",
            Up: "↑",
            Down: "↓",
            semicolon: ";",
            Minus: "-",
            Plus: "+",
            "mouse:272": "Clic gauche",
            "mouse:273": "Clic droit",
            mouse_up: "Molette ↑",
            mouse_down: "Molette ↓",
            "code:82": "Pavé -",
            "code:86": "Pavé +",
            XF86AudioRaiseVolume: "Volume +",
            XF86AudioLowerVolume: "Volume -",
            XF86AudioMute: "Muet",
            XF86AudioMicMute: "Micro muet",
            XF86AudioPlay: "Lecture",
            XF86AudioPause: "Pause",
            XF86AudioNext: "Suivant",
            XF86AudioPrev: "Précédent",
            XF86MonBrightnessUp: "Luminosité +",
            XF86MonBrightnessDown: "Luminosité -",
            XF86Calculator: "Calculatrice"
        })

    // [{ name, rows: [{ text, combos: [[touches]], search }] }]
    property var groups: []
    property int total: 0
    property string query: ""

    readonly property var filtered: {
        const query = normalize(root.query.trim());
        return groups.map(group => ({
                    name: group.name,
                    rows: group.rows.filter(row => !query || row.search.includes(query))
                })).filter(group => group.rows.length > 0);
    }

    // Deux colonnes équilibrées : chaque catégorie va dans la colonne la plus courte.
    readonly property var columns: {
        const columns = [[], []];
        const heights = [0, 0];
        for (const group of filtered) {
            const target = heights[0] <= heights[1] ? 0 : 1;
            columns[target].push(group);
            heights[target] += group.rows.length + 2;
        }
        return columns;
    }

    function normalize(text: string): string {
        return text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    function keysOf(bind: var): var {
        const keys = modifiers.filter(([mask]) => bind.modmask & mask).map(([, name]) => name);
        // Touche liée par code (code:82…) : nom vide, et code nul si Hyprland ne l'a pas compris.
        const raw = bind.key || (bind.keycode ? `code:${bind.keycode}` : "?");
        const key = keyNames[raw] ?? (raw.length === 1 ? raw.toUpperCase() : raw);
        return keys.concat([key]);
    }

    // Plusieurs touches avec les mêmes modificateurs tiennent sur une seule combinaison (ex. Super Alt 1…0).
    function combosOf(binds: var): var {
        if (binds.length > 2 && binds.every(b => b.modmask === binds[0].modmask)) {
            const keys = binds.map(b => keysOf(b).slice(-1)[0]);
            const joined = keys.length > 4 ? `${keys[0]}…${keys[keys.length - 1]}` : keys.join(" ");
            return [keysOf(binds[0]).slice(0, -1).concat([joined])];
        }
        return binds.map(keysOf);
    }

    function load(binds: var): void {
        const groups = [];
        const groupsByName = {};
        const rowsById = {};

        for (const bind of binds) {
            const described = bind.has_description && bind.description.includes(" › ");
            // Touches seules sans description (Verr. Maj, Verr. Num…) : surveillées par Caelestia, pas des raccourcis.
            if (!described && !bind.description && bind.modmask === 0)
                continue;
            const [name, text] = described ? bind.description.split(" › ") : ["Autres", bind.description || "Sans description"];

            let group = groupsByName[name];
            if (!group) {
                group = groupsByName[name] = { name, rows: [] };
                groups.push(group);
            }
            let row = rowsById[`${name}|${text}`];
            if (!row) {
                row = rowsById[`${name}|${text}`] = { text, binds: [] };
                group.rows.push(row);
            }
            row.binds.push(bind);
        }

        for (const group of groups) {
            for (const row of group.rows) {
                row.combos = combosOf(row.binds);
                row.search = normalize(`${group.name} ${row.text} ${[].concat(...row.combos).join(" ")}`);
            }
        }
        total = groups.reduce((sum, group) => sum + group.rows.reduce((n, row) => n + row.binds.length, 0), 0);
        root.groups = groups;
    }

    Process {
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.load(JSON.parse(text))
        }
    }

    Popup {
        id: popup

        layerName: "raccourcis"
        panelWidth: Math.min(1040, width - 64)

        Header {
            icon: "keyboard"
            title: "Raccourcis"
            subtitle: `${root.total} raccourcis · tape pour chercher · Échap pour fermer`
        }

        SearchField {
            id: search

            placeholder: "Chercher une action ou une touche"
            onTextChanged: root.query = text
            onCloseRequested: popup.close()
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, popup.height * 0.85 - 180)
            contentHeight: columnsRow.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            RowLayout {
                id: columnsRow

                width: parent.width
                spacing: 12

                Repeater {
                    model: root.columns

                    ColumnLayout {
                        required property var modelData

                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: (columnsRow.width - columnsRow.spacing) / 2
                        spacing: 12

                        Repeater {
                            model: parent.modelData

                            GroupCard {}
                        }
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.groups.length > 0 && root.filtered.length === 0
            text: "Aucun raccourci ne correspond"
            color: Theme.colour("onSurfaceVariant")
        }
    }

    component GroupCard: Card {
        id: card

        required property var modelData

        implicitHeight: cardContent.implicitHeight + 32

        ColumnLayout {
            id: cardContent

            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Label {
                text: card.modelData.name
                color: Theme.colour("primary")
                font.weight: Font.Medium
            }

            Repeater {
                model: card.modelData.rows

                RowLayout {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        Layout.fillWidth: true
                        text: row.modelData.text
                        font.pointSize: 10
                        wrapMode: Text.Wrap
                    }

                    // Plusieurs combinaisons longues : une par ligne, pour laisser la place au libellé.
                    Grid {
                        columns: row.modelData.combos.length > 1 && [].concat(...row.modelData.combos).length > 4 ? 1 : row.modelData.combos.length
                        horizontalItemAlignment: Grid.AlignRight
                        columnSpacing: 6
                        rowSpacing: 4

                        Repeater {
                            model: row.modelData.combos

                            Row {
                                id: combo

                                required property var modelData
                                required property int index

                                spacing: 4

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: combo.index > 0
                                    text: "ou"
                                    color: Theme.colour("onSurfaceVariant")
                                    font.pointSize: 9
                                    rightPadding: 2
                                }

                                Repeater {
                                    model: combo.modelData

                                    Keycap {
                                        required property string modelData

                                        text: modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
