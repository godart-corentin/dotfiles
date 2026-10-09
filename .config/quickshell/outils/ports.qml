// Serveurs et ports TCP en écoute, avec le projet de ~/workspace d'où chacun a été lancé.
// Ouvrir dans le navigateur, copier l'adresse ou arrêter le processus ; la liste se rafraîchit toute seule.
// Ouverture : qs-outil ports (Super+Maj+O).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // Ports système courants, dont le processus n'est pas visible sans être root.
    readonly property var services: ({
            53: "Résolution DNS",
            631: "Impression (CUPS)",
            3306: "MySQL",
            5355: "Résolution de noms locale (LLMNR)",
            5432: "PostgreSQL",
            6379: "Redis",
            27017: "MongoDB"
        })
    readonly property var interpreters: ["node", "bun", "deno", "python", "python3", "ruby", "java", "php", "go", "cargo", "npm", "pnpm", "yarn", "npx"]

    property var ports: []
    property bool scanned: false
    // Dernier relevé, sans les durées qui changent à chaque fois : la liste n'est reconstruite que si les ports changent.
    property string lastScan
    property string query: ""
    // Port en attente de confirmation d'arrêt, et PID déjà prévenus par SIGTERM (le suivant sera SIGKILL).
    property int arming: -1
    property var terminated: ({})

    readonly property var filtered: {
        const query = root.query.trim().toLowerCase();
        return ports.filter(p => !query || `${p.port} ${p.label} ${p.command} ${p.project}`.toLowerCase().includes(query));
    }
    readonly property var selected: list.currentIndex >= 0 && list.currentIndex < filtered.length ? filtered[list.currentIndex] : null

    // Projet de ~/workspace, sinon « node server.mjs » plutôt que le nom de thread (MainThread…).
    function labelOf(port: var): string {
        if (port.project)
            return port.project;
        if (!port.command)
            return port.name || services[port.port] || "Processus du système";
        const words = port.command.split(" ").filter(w => w);
        const program = words[0].split("/").pop();
        if (interpreters.includes(program) && words[1])
            return `${program} ${words[1].split("/").pop()}`;
        return program;
    }

    function duration(seconds: int): string {
        if (seconds < 60)
            return "depuis moins d'une minute";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return `depuis ${minutes} min`;
        const hours = Math.floor(minutes / 60);
        return hours < 24 ? `depuis ${hours} h` : `depuis ${Math.floor(hours / 24)} j`;
    }

    function exposed(port: var): bool {
        return port.addresses.some(a => a === "0.0.0.0" || a === "[::]" || a === "*");
    }

    function load(output: string): void {
        const scan = output.replace(/"uptime":\d+/g, "");
        if (scan === lastScan)
            return;
        lastScan = scan;
        const current = selected?.port;
        // Les tiens d'abord (ceux d'un projet en tête), puis ceux du système ; par port dans chaque groupe.
        ports = JSON.parse(output).map(p => Object.assign(p, { label: labelOf(p) })).sort((a, b) => (!!b.pid - !!a.pid) || (!!b.project - !!a.project) || a.port - b.port);
        scanned = true;
        const index = filtered.findIndex(p => p.port === current);
        list.currentIndex = index >= 0 ? index : 0;
    }

    function url(port: var): string {
        return `http://localhost:${port.port}`;
    }

    function open(port: var): void {
        if (!port)
            return;
        Quickshell.execDetached(["xdg-open", url(port)]);
        popup.close();
    }

    function copy(port: var): void {
        if (!port)
            return;
        Quickshell.execDetached(["wl-copy", "--", url(port)]);
        popup.close();
    }

    // Premier appel : demande confirmation. Second : SIGTERM, ou SIGKILL si le processus a déjà résisté.
    function stop(port: var): void {
        if (!port?.pid)
            return;
        if (arming !== port.port) {
            arming = port.port;
            armTimer.restart();
            return;
        }
        const force = !!terminated[port.pid];
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(port.pid)]);
        terminated = Object.assign({}, terminated, { [port.pid]: true });
        arming = -1;
        refreshTimer.restart();
    }

    Process {
        id: scan

        running: true
        command: ["bash", Quickshell.shellPath("ports.sh"), Quickshell.env("HOME") + "/workspace"]
        stdout: StdioCollector {
            onStreamFinished: root.load(text)
        }
    }

    Timer {
        id: refreshTimer

        running: true
        repeat: true
        interval: 2000
        onTriggered: {
            if (!scan.running)
                scan.running = true;
        }
    }

    Timer {
        id: armTimer

        interval: 3000
        onTriggered: root.arming = -1
    }

    Popup {
        id: popup

        layerName: "ports"
        panelWidth: 720

        Header {
            icon: "lan"
            title: "Ports ouverts"
            subtitle: `${root.ports.filter(p => p.pid).length} à toi · ${root.ports.filter(p => !p.pid).length} au système · mis à jour en continu`
        }

        SearchField {
            id: search

            placeholder: "Chercher un port, un projet ou une commande"
            onTextChanged: {
                root.query = text;
                list.currentIndex = 0;
            }
            onCloseRequested: popup.close()
            onKeyPressed: event => {
                const shift = event.modifiers & Qt.ShiftModifier;
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Up)
                    list.decrementCurrentIndex();
                else if (event.key === Qt.Key_Down)
                    list.incrementCurrentIndex();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.open(root.selected);
                else if (event.key === Qt.Key_C && ctrl)
                    root.copy(root.selected);
                else if (event.key === Qt.Key_Delete && shift)
                    root.stop(root.selected);
                else
                    return;
                event.accepted = true;
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, popup.height * 0.85 - 220)
            spacing: 4
            clip: true
            model: root.filtered
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            highlight: Rectangle {
                radius: 18
                color: Theme.colour("secondaryContainer")
            }

            delegate: PortRow {}
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.scanned && list.count === 0
            text: root.ports.length === 0 ? "Aucun port en écoute" : "Aucun port ne correspond"
            color: Theme.colour("onSurfaceVariant")
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Hint {
                keys: ["Entrée"]
                text: "ouvrir"
            }
            Hint {
                keys: ["Ctrl", "C"]
                text: "copier l'adresse"
            }
            Hint {
                keys: ["Maj", "Suppr"]
                text: "arrêter"
            }
            Hint {
                keys: ["Échap"]
                text: "fermer"
            }
        }
    }

    component PortRow: Item {
        id: row

        required property var modelData
        required property int index

        readonly property bool current: ListView.isCurrentItem
        readonly property bool mine: !!modelData.pid
        readonly property bool armed: root.arming === modelData.port

        width: ListView.view.width
        implicitHeight: 60

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: list.currentIndex = row.index
            onClicked: root.open(row.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 14

            Rectangle {
                implicitWidth: 64
                implicitHeight: 36
                radius: 18
                color: row.mine ? (row.current ? Theme.colour("primary") : Theme.colour("primaryContainer")) : Theme.colour("surfaceContainerHighest")

                Label {
                    anchors.centerIn: parent
                    text: row.modelData.port
                    color: row.mine ? (row.current ? Theme.colour("onPrimary") : Theme.colour("onPrimaryContainer")) : Theme.colour("onSurfaceVariant")
                    font.weight: Font.Medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: 8

                    Label {
                        text: row.modelData.label
                        color: row.mine ? (row.current ? Theme.colour("onSecondaryContainer") : Theme.colour("onSurface")) : Theme.colour("onSurfaceVariant")
                        font.weight: row.mine ? Font.Medium : Font.Normal
                    }

                    // Écoute sur toutes les interfaces : joignable depuis le réseau, pas seulement en local.
                    Rectangle {
                        visible: root.exposed(row.modelData)
                        implicitWidth: networkLabel.implicitWidth + 14
                        implicitHeight: 20
                        radius: 10
                        color: Theme.colour("tertiaryContainer")

                        Label {
                            id: networkLabel

                            anchors.centerIn: parent
                            text: "réseau"
                            color: Theme.colour("onTertiaryContainer")
                            font.pointSize: 8
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: row.armed ? (root.terminated[row.modelData.pid] ? "Il résiste : Maj+Suppr encore pour le tuer (SIGKILL)" : "Maj+Suppr encore pour arrêter le processus") : row.mine ? [row.modelData.command, `PID ${row.modelData.pid}`, root.duration(row.modelData.uptime)].join(" · ") : `Système ou autre utilisateur · ${row.modelData.addresses.join(", ")}`
                    color: row.armed ? Theme.colour("error") : Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                    elide: Text.ElideMiddle
                }
            }

            IconButton {
                visible: row.current
                icon: "open_in_browser"
                onClicked: root.open(row.modelData)
            }

            IconButton {
                visible: row.current
                icon: "content_copy"
                onClicked: root.copy(row.modelData)
            }

            IconButton {
                visible: row.current && row.mine
                icon: "stop_circle"
                ink: row.armed ? Theme.colour("error") : Theme.colour("onSurfaceVariant")
                onClicked: root.stop(row.modelData)
            }
        }
    }
}
