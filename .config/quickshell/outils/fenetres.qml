// Vue d'ensemble des fenêtres : les espaces de travail de chaque écran en miniature, avec les fenêtres en direct.
// Clic sur une fenêtre pour y aller, sur un espace pour l'afficher ; glisser une fenêtre la déplace sans la suivre.
// Ouverture : qs-outil fenetres (Super+Tab).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property real scale: 0.17

    // [{ name, x, y, width, height, scale, focused, workspaces: [{ id, active, windows: [client] }] }], de gauche à droite.
    property var monitors: []
    // Les fenêtres dans l'ordre d'affichage, pour la navigation au clavier.
    property var windows: []
    property int selected: -1

    // Les écrans et espaces du module Hyprland de Quickshell restent vides avec Hyprland 0.56 en config Lua :
    // l'état vient de hyprctl, et le module ne sert qu'à retrouver chaque fenêtre pour sa miniature.
    function load(state: var): void {
        const monitors = state.monitors.map(m => ({
                    name: m.name,
                    x: m.x,
                    y: m.y,
                    width: m.width / m.scale,
                    height: m.height / m.scale,
                    focused: m.focused,
                    workspaces: state.workspaces.filter(w => w.monitor === m.name && w.id > 0).sort((a, b) => a.id - b.id).map(w => ({
                                id: w.id,
                                active: m.activeWorkspace.id === w.id,
                                windows: state.clients.filter(c => c.workspace.id === w.id && c.mapped && !c.hidden)
                            }))
                })).sort((a, b) => a.x - b.x);
        const windows = monitors.reduce((all, m) => m.workspaces.reduce((list, w) => list.concat(w.windows), all), []);
        const current = root.windows[selected]?.address;

        root.monitors = monitors;
        root.windows = windows;
        // Garde la sélection ; à l'ouverture, part de la fenêtre active.
        const kept = windows.findIndex(c => c.address === current);
        selected = kept >= 0 ? kept : windows.findIndex(c => c.focusHistoryID === 0);
    }

    function toplevelOf(client: var): var {
        return Hyprland.toplevels.values.find(t => `0x${t.address}` === client.address) ?? null;
    }

    function dispatch(lua: string, legacy: string): void {
        Hyprland.dispatch(Hyprland.usingLua ? lua : legacy);
    }

    function focusWindow(client: var): void {
        if (!client)
            return;
        dispatch(`hl.dsp.focus({ window = "address:${client.address}" })`, `focuswindow address:${client.address}`);
        popup.close();
    }

    function focusWorkspace(workspace: var): void {
        dispatch(`hl.dsp.focus({ workspace = "${workspace.id}" })`, `workspace ${workspace.id}`);
        popup.close();
    }

    function moveWindow(client: var, workspace: var): void {
        if (!client || client.workspace.id === workspace.id)
            return;
        dispatch(`hl.dsp.window.move({ window = "address:${client.address}", workspace = "${workspace.id}", follow = false })`, `movetoworkspacesilent ${workspace.id},address:${client.address}`);
    }

    function select(step: int): void {
        if (windows.length === 0)
            return;
        selected = selected < 0 ? 0 : (selected + step + windows.length) % windows.length;
    }

    Process {
        id: query

        running: true
        command: ["sh", "-c", "jq -nc --argjson monitors \"$(hyprctl -j monitors)\" --argjson workspaces \"$(hyprctl -j workspaces)\" --argjson clients \"$(hyprctl -j clients)\" '{monitors: $monitors, workspaces: $workspaces, clients: $clients}'"]
        stdout: StdioCollector {
            onStreamFinished: root.load(JSON.parse(text))
        }
    }

    // Relit l'état après chaque événement Hyprland (fenêtre ouverte, déplacée, fermée…).
    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer

        interval: 100
        onTriggered: {
            query.running = false;
            query.running = true;
        }
    }

    Popup {
        id: popup

        // Rangée la plus large (cartes et espacements) plus les marges du panneau.
        readonly property real naturalWidth: Math.ceil(Math.max(...root.monitors.map(m => m.workspaces.length * (m.width * root.scale + 12) - 12), 0)) + 56

        layerName: "fenetres"
        panelWidth: Math.max(560, Math.min(naturalWidth, width - 64))

        onKeyPressed: event => {
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                root.select(1);
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                root.select(-1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.focusWindow(root.windows[root.selected]);
        }

        Header {
            icon: "dashboard"
            title: "Fenêtres"
            subtitle: `${root.windows.length} fenêtre${root.windows.length > 1 ? "s" : ""} · clic pour y aller · glisser pour déplacer · ← → et Entrée · Échap pour fermer`
        }

        Repeater {
            model: root.monitors

            ColumnLayout {
                id: monitorColumn

                required property var modelData

                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: `${monitorColumn.modelData.name} · ${monitorColumn.modelData.width}×${monitorColumn.modelData.height}`
                    color: monitorColumn.modelData.focused ? Theme.colour("primary") : Theme.colour("onSurfaceVariant")
                    font.pointSize: 10
                    font.weight: Font.Medium
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                        model: monitorColumn.modelData.workspaces

                        WorkspaceCard {
                            monitor: monitorColumn.modelData
                        }
                    }
                }
            }
        }

        // Copie de la fenêtre déplacée, au-dessus de tout pendant le glisser.
        Item {
            parent: popup.contentItem
            anchors.fill: parent
            z: 100

            Rectangle {
                id: ghost

                property var client: null

                visible: client !== null
                radius: 10
                color: Theme.colour("surfaceContainerHighest")
                border.width: 2
                border.color: Theme.colour("primary")
                opacity: 0.9
                clip: true
                layer.enabled: true

                Drag.active: client !== null
                Drag.keys: ["fenetre"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                ScreencopyView {
                    anchors.fill: parent
                    anchors.margins: 2
                    captureSource: ghost.client ? root.toplevelOf(ghost.client)?.wayland ?? null : null
                    live: true
                }
            }
        }
    }

    component WorkspaceCard: Rectangle {
        id: card

        required property var modelData
        required property var monitor

        readonly property var workspace: modelData

        implicitWidth: monitor.width * root.scale
        implicitHeight: monitor.height * root.scale
        radius: 14
        color: drop.containsDrag ? Theme.colour("secondaryContainer") : Theme.colour("surfaceContainer")
        border.width: workspace.active ? 2 : 0
        border.color: Theme.colour("primary")

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusWorkspace(card.workspace)
        }

        Label {
            anchors.centerIn: parent
            visible: card.workspace.windows.length === 0
            text: card.workspace.id
            color: Theme.colour("onSurfaceVariant")
            font.pointSize: 22
            font.weight: Font.Medium
            opacity: 0.5
        }

        Item {
            anchors.fill: parent
            clip: true

            Repeater {
                model: card.workspace.windows

                WindowThumb {
                    monitor: card.monitor
                    shown: card.workspace.active
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 8
            z: 2
            visible: card.workspace.windows.length > 0
            implicitWidth: Math.max(implicitHeight, idLabel.implicitWidth + 12)
            implicitHeight: 22
            radius: 11
            color: card.workspace.active ? Theme.colour("primary") : Theme.colour("surfaceContainerHighest")

            Label {
                id: idLabel

                anchors.centerIn: parent
                text: card.workspace.id
                color: card.workspace.active ? Theme.colour("onPrimary") : Theme.colour("onSurface")
                font.pointSize: 9
                font.weight: Font.Medium
            }
        }

        DropArea {
            id: drop

            anchors.fill: parent
            keys: ["fenetre"]
            onDropped: drop => root.moveWindow(drop.source.client, card.workspace)
        }
    }

    component WindowThumb: Rectangle {
        id: thumb

        required property var modelData
        required property var monitor
        // Hyprland ne dessine pas les espaces non affichés : leur capture serait périmée.
        required property bool shown

        readonly property var client: modelData
        readonly property bool current: root.windows[root.selected]?.address === client.address
        readonly property var entry: DesktopEntries.heuristicLookup(client.class)

        x: (client.at[0] - monitor.x) * root.scale
        y: (client.at[1] - monitor.y) * root.scale
        z: client.floating ? 1 : 0
        width: client.size[0] * root.scale
        height: client.size[1] * root.scale
        radius: 8
        color: Theme.colour("surfaceContainerHighest")
        opacity: ghost.client?.address === client.address ? 0.3 : 1
        // Composée à part : sinon les zones transparentes d'une fenêtre (kitty…) laissent voir le bureau à travers le panneau.
        layer.enabled: true

        Column {
            anchors.centerIn: parent
            visible: !screencopy.hasContent
            spacing: 4

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(thumb.width, thumb.height) * 0.4
                height: width
                source: thumb.entry?.icon ? Quickshell.iconPath(thumb.entry.icon, true) : ""
                sourceSize.width: 128
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: thumb.height > 60
                text: thumb.entry?.name ?? thumb.client.class
                color: Theme.colour("onSurfaceVariant")
                font.pointSize: 8
            }
        }

        ScreencopyView {
            id: screencopy

            anchors.fill: parent
            anchors.margins: 1
            visible: thumb.shown
            captureSource: thumb.shown ? root.toplevelOf(thumb.client)?.wayland ?? null : null
            live: true
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: thumb.current || area.containsMouse ? 2 : 1
            border.color: thumb.current || area.containsMouse ? Theme.colour("primary") : Theme.colour("outlineVariant")
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            visible: (thumb.current || area.containsMouse) && thumb.height > 40
            implicitHeight: 22
            radius: 11
            color: Qt.alpha(Theme.colour("surface"), 0.85)

            Label {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: Text.AlignVCenter
                text: thumb.client.title
                font.pointSize: 8
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: area

            property point pressPoint
            property bool dragging

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            onPressed: mouse => {
                pressPoint = Qt.point(mouse.x, mouse.y);
                dragging = false;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                if (!dragging && Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) > 8) {
                    dragging = true;
                    ghost.width = thumb.width;
                    ghost.height = thumb.height;
                    ghost.client = thumb.client;
                }
                if (dragging) {
                    const point = mapToItem(ghost.parent, mouse.x, mouse.y);
                    ghost.x = point.x - pressPoint.x;
                    ghost.y = point.y - pressPoint.y;
                }
            }
            onReleased: {
                if (dragging) {
                    ghost.Drag.drop();
                    ghost.client = null;
                    dragging = false;
                } else {
                    root.focusWindow(thumb.client);
                }
            }
        }
    }
}
