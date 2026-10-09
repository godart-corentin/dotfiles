// Lanceur des projets de ~/workspace : état git de chacun, ouverture dans Zed, un terminal ou sur GitHub.
// Les derniers projets ouverts passent en tête (~/.local/state/projets.json).
// Ouverture : qs-outil projets (Super+O).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string workspace: Quickshell.env("HOME") + "/workspace"

    property var projects: []
    property var opened: ({})
    property bool scanned: false
    property string query: ""

    readonly property var sorted: projects.slice().sort((a, b) => (opened[b.name] ?? 0) - (opened[a.name] ?? 0) || b.last - a.last)
    readonly property var filtered: {
        const query = root.query.trim().toLowerCase();
        return sorted.filter(p => !query || p.name.toLowerCase().includes(query));
    }
    readonly property var selected: list.currentIndex >= 0 && list.currentIndex < filtered.length ? filtered[list.currentIndex] : null

    function parse(output: string): void {
        projects = output.split("\n").filter(line => line).map(line => {
            const project = JSON.parse(line);
            project.name = project.dir.split("/").pop();
            if (project.counts) {
                const [behind, ahead] = project.counts.split(/\s+/).map(Number);
                Object.assign(project, { behind, ahead });
            }
            project.web = webUrl(project.remote ?? "");
            return project;
        });
        scanned = true;
    }

    // git@github.com:moi/projet.git ou https://github.com/moi/projet.git → https://github.com/moi/projet
    function webUrl(remote: string): string {
        const ssh = remote.match(/^git@([^:]+):(.+?)(\.git)?$/);
        if (ssh)
            return `https://${ssh[1]}/${ssh[2]}`;
        const https = remote.match(/^https?:\/\/(?:[^@/]+@)?(.+?)(\.git)?$/);
        return https ? `https://${https[1]}` : "";
    }

    function ago(seconds: int): string {
        const minutes = Math.floor((Date.now() / 1000 - seconds) / 60);
        if (minutes < 1)
            return "à l'instant";
        if (minutes < 60)
            return `il y a ${minutes} min`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return `il y a ${hours} h`;
        const days = Math.floor(hours / 24);
        if (days < 30)
            return `il y a ${days} j`;
        const months = Math.floor(days / 30);
        return months < 12 ? `il y a ${months} mois` : `il y a ${Math.floor(months / 12)} an${months >= 24 ? "s" : ""}`;
    }

    function details(project: var): string {
        if (!project.git)
            return `Pas de dépôt git · modifié ${ago(project.last)}`;
        const parts = [project.branch];
        if (project.changes > 0)
            parts.push(`${project.changes} modif${project.changes > 1 ? "s" : ""}`);
        if (project.ahead || project.behind)
            parts.push([project.ahead ? `↑${project.ahead}` : "", project.behind ? `↓${project.behind}` : ""].filter(x => x).join(" "));
        parts.push(project.last ? ago(project.last) : "aucun commit");
        return parts.join(" · ");
    }

    function open(project: var, how: string): void {
        if (!project)
            return;
        if (how === "zed")
            Quickshell.execDetached(["uwsm", "app", "--", "zeditor", project.dir]);
        else if (how === "terminal")
            Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--directory", project.dir]);
        else if (how === "web" && project.web)
            Quickshell.execDetached(["xdg-open", project.web]);
        else
            return;
        opened = Object.assign({}, opened, { [project.name]: Date.now() });
        stateFile.setText(JSON.stringify(opened) + "\n");
        popup.close();
    }

    Process {
        running: true
        command: ["bash", Quickshell.shellPath("projets.sh"), root.workspace]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    FileView {
        id: stateFile

        path: Quickshell.env("HOME") + "/.local/state/projets.json"
        printErrors: false
        // Écriture synchrone : l'état est enregistré juste avant de quitter.
        blockWrites: true
        onLoaded: {
            try {
                root.opened = JSON.parse(text());
            } catch (e) {}
        }
    }

    Popup {
        id: popup

        layerName: "projets"
        panelWidth: 720

        Header {
            icon: "code"
            title: "Projets"
            subtitle: `${root.projects.length} dossiers dans ~/workspace`
        }

        SearchField {
            id: search

            placeholder: "Chercher un projet"
            onTextChanged: {
                root.query = text;
                list.currentIndex = 0;
            }
            onCloseRequested: popup.close()
            onKeyPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Up)
                    list.decrementCurrentIndex();
                else if (event.key === Qt.Key_Down)
                    list.incrementCurrentIndex();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.open(root.selected, ctrl ? "terminal" : "zed");
                else if (event.key === Qt.Key_G && ctrl)
                    root.open(root.selected, "web");
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

            delegate: ProjectRow {}
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.scanned && list.count === 0
            text: root.projects.length === 0 ? "Aucun dossier dans ~/workspace" : "Aucun projet ne correspond"
            color: Theme.colour("onSurfaceVariant")
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Hint {
                keys: ["Entrée"]
                text: "Zed"
            }
            Hint {
                keys: ["Ctrl", "Entrée"]
                text: "terminal"
            }
            Hint {
                keys: ["Ctrl", "G"]
                text: "GitHub"
            }
            Hint {
                keys: ["Échap"]
                text: "fermer"
            }
        }
    }

    component ProjectRow: Item {
        id: row

        required property var modelData
        required property int index

        readonly property bool current: ListView.isCurrentItem

        width: ListView.view.width
        implicitHeight: 64

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: list.currentIndex = row.index
            onClicked: root.open(row.modelData, "zed")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 14

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: row.current ? Theme.colour("primary") : Theme.colour("primaryContainer")

                Label {
                    anchors.centerIn: parent
                    text: row.modelData.name.charAt(0).toUpperCase()
                    color: row.current ? Theme.colour("onPrimary") : Theme.colour("onPrimaryContainer")
                    font.pointSize: 13
                    font.weight: Font.Medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: 8

                    Label {
                        text: row.modelData.name
                        color: row.current ? Theme.colour("onSecondaryContainer") : Theme.colour("onSurface")
                        font.weight: Font.Medium
                    }

                    // Pastille des fichiers modifiés non commités.
                    Rectangle {
                        visible: (row.modelData.changes ?? 0) > 0
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: Theme.colour("tertiary")
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: root.details(row.modelData)
                    color: Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    visible: !!row.modelData.subject
                    text: row.modelData.subject ?? ""
                    color: Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                    font.italic: true
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: row.current
                icon: "edit_note"
                onClicked: root.open(row.modelData, "zed")
            }

            IconButton {
                visible: row.current
                icon: "terminal"
                onClicked: root.open(row.modelData, "terminal")
            }

            IconButton {
                visible: row.current && !!row.modelData.web
                icon: "public"
                onClicked: root.open(row.modelData, "web")
            }
        }
    }
}
