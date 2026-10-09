// Menu de capture : zone, fenêtre, écran ou couleur, puis copier, enregistrer ou annoter.
// La capture elle-même est faite par ~/.local/bin/capture, une fois le menu fermé.
// Ouverture : qs-outil capture (Super+Maj+P).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property var modes: [
        { id: "zone", key: "z", icon: "crop_free", title: "Zone", hint: "Sélection libre" },
        { id: "fenetre", key: "f", icon: "select_window", title: "Fenêtre", hint: "Clic sur une fenêtre" },
        { id: "ecran", key: "e", icon: "desktop_windows", title: "Écran", hint: "Écran actif" },
        { id: "couleur", key: "c", icon: "colorize", title: "Couleur", hint: "Code hex copié" }
    ]
    readonly property var actions: [
        { id: "copier", icon: "content_copy", title: "Copier" },
        { id: "enregistrer", icon: "save", title: "Enregistrer" },
        { id: "annoter", icon: "edit", title: "Annoter" }
    ]
    readonly property var delays: [0, 3, 5, 10]

    // Derniers choix, retrouvés à la prochaine ouverture.
    property string action: "copier"
    property int delay: 0

    function run(mode: string): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/capture", mode, action, String(delay)]);
        popup.close();
    }

    function remember(): void {
        stateFile.setText(JSON.stringify({ action, delay }) + "\n");
    }

    FileView {
        id: stateFile

        path: Quickshell.env("HOME") + "/.local/state/capture-menu.json"
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.action = saved.action ?? root.action;
                root.delay = saved.delay ?? root.delay;
            } catch (e) {}
        }
    }

    Popup {
        id: popup

        layerName: "capture"
        panelWidth: 600
        onKeyPressed: event => {
            const mode = root.modes.find(m => m.key === event.text.toLowerCase());
            if (mode)
                root.run(mode.id);
        }

        Header {
            icon: "screenshot_region"
            title: "Capture"
            subtitle: "Z, F, E ou C · Échap pour fermer"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Repeater {
                model: root.modes

                ModeTile {}
            }
        }

        Card {
            implicitHeight: options.implicitHeight + 32

            GridLayout {
                id: options

                anchors.fill: parent
                anchors.margins: 16
                columns: 2
                columnSpacing: 16
                rowSpacing: 12

                Label {
                    text: "Ensuite"
                    color: Theme.colour("onSurfaceVariant")
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.actions

                        Chip {
                            required property var modelData

                            icon: modelData.icon
                            text: modelData.title
                            selected: root.action === modelData.id
                            onClicked: {
                                root.action = modelData.id;
                                root.remember();
                            }
                        }
                    }
                }

                Label {
                    text: "Délai"
                    color: Theme.colour("onSurfaceVariant")
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.delays

                        Chip {
                            required property int modelData

                            icon: modelData > 0 ? "timer" : ""
                            text: modelData > 0 ? `${modelData} s` : "Aucun"
                            selected: root.delay === modelData
                            onClicked: {
                                root.delay = modelData;
                                root.remember();
                            }
                        }
                    }
                }
            }
        }
    }

    component ModeTile: Rectangle {
        id: tile

        required property var modelData

        Layout.fillWidth: true
        implicitHeight: 128
        radius: 20
        color: Theme.colour("surfaceContainer")

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.colour("onSurface")
            opacity: tileArea.pressed ? 0.12 : tileArea.containsMouse ? 0.08 : 0
        }

        Keycap {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            text: tile.modelData.key.toUpperCase()
        }

        Column {
            anchors.centerIn: parent
            spacing: 4

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.modelData.icon
                color: Theme.colour("primary")
                font.pixelSize: 32
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.modelData.title
                font.weight: Font.Medium
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.modelData.hint
                color: Theme.colour("onSurfaceVariant")
                font.pointSize: 9
            }
        }

        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.run(tile.modelData.id)
        }
    }
}
