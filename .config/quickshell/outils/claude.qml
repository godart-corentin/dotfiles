// Tableau de bord Claude Code : quotas, puis deux onglets, les sessions (en cours et récentes à reprendre)
// et les artifacts claude.ai à ouvrir.
// Les sessions viennent de ~/.claude (claude.sh). Les quotas et les artifacts, de fichiers écrits par
// des mods Claude Code : ~/.cache/claude-quotas.json (usage-band) et ~/.cache/claude-artifacts.json
// (artifacts-export, à l'ouverture de chaque session).
// Ouverture : qs-outil claude (Super+Maj+C).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")

    property var running: []
    property var recent: []
    property var quotas: null
    property var artifacts: null
    property bool scanned: false
    property string query: ""
    property string tab: "sessions"

    // Les sessions en cours d'abord, puis les récentes qui ne tournent plus.
    readonly property var entries: {
        const live = running.map(s => Object.assign({}, recent.find(r => r.sessionId === s.sessionId) ?? {}, s, { live: true }));
        const ids = live.map(s => s.sessionId);
        return live.concat(recent.filter(r => !ids.includes(r.sessionId)).map(r => Object.assign({ live: false }, r)));
    }
    readonly property var filtered: {
        const query = root.query.trim().toLowerCase();
        return entries.filter(s => !query || `${s.title ?? ""} ${s.prompt ?? ""} ${project(s)}`.toLowerCase().includes(query));
    }
    readonly property var selected: list.currentIndex >= 0 && list.currentIndex < filtered.length ? filtered[list.currentIndex] : null

    readonly property var filteredArtifacts: {
        const query = root.query.trim().toLowerCase();
        return (artifacts?.artifacts ?? []).filter(a => !query || a.title.toLowerCase().includes(query));
    }
    readonly property var selectedArtifact: artifactList.currentIndex >= 0 && artifactList.currentIndex < filteredArtifacts.length ? filteredArtifacts[artifactList.currentIndex] : null
    readonly property var currentList: tab === "sessions" ? list : artifactList

    // ~/workspace/piko/.worktrees/offline-prototype → « piko · offline-prototype ».
    function project(session: var): string {
        const cwd = session.cwd ?? "";
        if (cwd === home)
            return "~";
        const path = cwd.startsWith(`${home}/workspace/`) ? cwd.slice(home.length + 11) : cwd.replace(home, "~");
        const [name, , worktree] = path.split("/");
        return path.includes("/.worktrees/") ? `${name} · ${worktree}` : path;
    }

    // La branche, sauf HEAD détachée ou déjà dite par le nom du worktree.
    function branch(session: var): string {
        const name = session.branch ?? "";
        return name && name !== "HEAD" && !project(session).endsWith(` · ${name}`) ? name : "";
    }

    function ago(seconds: real): string {
        const minutes = Math.floor((Date.now() / 1000 - seconds) / 60);
        if (minutes < 1)
            return "à l'instant";
        if (minutes < 60)
            return `il y a ${minutes} min`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return `il y a ${hours} h`;
        return `il y a ${Math.floor(hours / 24)} j`;
    }

    function until(date: string): string {
        const minutes = Math.round((Date.parse(date) - Date.now()) / 60000);
        if (minutes < 60)
            return `${Math.max(1, minutes)} min`;
        const hours = Math.floor(minutes / 60);
        return hours < 24 ? `${hours} h ${String(minutes % 60).padStart(2, "0")}` : `${Math.floor(hours / 24)} j ${hours % 24} h`;
    }

    function status(session: var): string {
        if (!session.live)
            return session.exists ? "" : "dossier supprimé";
        return { busy: "travaille", waiting: "attend ta réponse", idle: "en pause" }[session.status] ?? session.status;
    }

    function open(session: var): void {
        if (!session)
            return;
        if (session.live)
            Quickshell.execDetached(["bash", Quickshell.shellPath("claude.sh"), "focus", String(session.pid)]);
        else if (session.exists)
            Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--directory", session.cwd, root.home + "/.local/bin/claude", "--resume", session.sessionId]);
        else
            return;
        popup.close();
    }

    function openArtifact(artifact: var): void {
        if (!artifact)
            return;
        Quickshell.execDetached(["xdg-open", artifact.url]);
        popup.close();
    }

    function copyArtifact(artifact: var): void {
        if (!artifact)
            return;
        Quickshell.execDetached(["wl-copy", "--", artifact.url]);
        popup.close();
    }

    // « 2026-10-08 » → « mis à jour le 8 oct. »
    function updated(date: string): string {
        return date ? `mis à jour le ${new Date(date).toLocaleDateString(Qt.locale("fr_FR"), "d MMM")}` : "";
    }

    function selectTab(id: string): void {
        tab = id;
        currentList.currentIndex = 0;
    }

    function copy(session: var): void {
        if (!session)
            return;
        Quickshell.execDetached(["wl-copy", "--", `cd ${session.cwd} && claude --resume ${session.sessionId}`]);
        popup.close();
    }

    Process {
        running: true
        command: ["bash", Quickshell.shellPath("claude.sh"), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const data = JSON.parse(text);
                root.running = data.running;
                root.recent = data.recent;
                root.scanned = true;
            }
        }
    }

    FileView {
        path: root.home + "/.cache/claude-quotas.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.quotas = JSON.parse(text());
            } catch (e) {}
        }
    }

    FileView {
        path: root.home + "/.cache/claude-artifacts.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.artifacts = JSON.parse(text());
            } catch (e) {}
        }
    }

    Popup {
        id: popup

        layerName: "claude"
        panelWidth: 760

        Header {
            icon: "smart_toy"
            title: "Claude Code"
            subtitle: `${root.running.length} session${root.running.length > 1 ? "s" : ""} en cours · ${root.recent.length} récentes`
        }

        Card {
            implicitHeight: quotaContent.implicitHeight + 32

            ColumnLayout {
                id: quotaContent

                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Repeater {
                    model: root.quotas?.limits ?? []

                    RowLayout {
                        id: quota

                        required property var modelData

                        readonly property real percent: Math.min(100, modelData.percentUsed)

                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            Layout.preferredWidth: 70
                            text: quota.modelData.name
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 10
                            radius: 5
                            color: Theme.colour("surfaceContainerHighest")

                            Rectangle {
                                width: parent.width * quota.percent / 100
                                height: parent.height
                                radius: 5
                                color: quota.percent > 90 ? Theme.colour("error") : quota.percent > 75 ? Theme.colour("tertiary") : Theme.colour("primary")
                            }
                        }

                        Label {
                            Layout.preferredWidth: 48
                            horizontalAlignment: Text.AlignRight
                            text: `${Math.round(quota.modelData.percentUsed)} %`
                            font.weight: Font.Medium
                        }

                        Label {
                            Layout.preferredWidth: 90
                            text: quota.modelData.resetsAt ? `↻ ${root.until(quota.modelData.resetsAt)}` : ""
                            color: Theme.colour("onSurfaceVariant")
                            font.pointSize: 9
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: root.quotas ? `Relevé ${root.ago(root.quotas.updatedAt / 1000)} par une session Claude Code` : "Les quotas s'afficheront après le prochain lancement de Claude Code (mod usage-band)."
                    color: Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                    wrapMode: Text.Wrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Chip {
                icon: "terminal"
                text: `Sessions · ${root.entries.length}`
                selected: root.tab === "sessions"
                onClicked: root.selectTab("sessions")
            }

            Chip {
                icon: "web"
                text: `Artifacts · ${root.artifacts?.artifacts.length ?? 0}`
                selected: root.tab === "artifacts"
                onClicked: root.selectTab("artifacts")
            }
        }

        SearchField {
            placeholder: root.tab === "sessions" ? "Chercher une session (titre, message, projet)" : "Chercher un artifact"
            onTextChanged: {
                root.query = text;
                root.currentList.currentIndex = 0;
            }
            onCloseRequested: popup.close()
            onKeyPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                const sessions = root.tab === "sessions";
                if (event.key === Qt.Key_Up)
                    root.currentList.decrementCurrentIndex();
                else if (event.key === Qt.Key_Down)
                    root.currentList.incrementCurrentIndex();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    sessions ? root.open(root.selected) : root.openArtifact(root.selectedArtifact);
                else if (event.key === Qt.Key_C && ctrl)
                    sessions ? root.copy(root.selected) : root.copyArtifact(root.selectedArtifact);
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                    root.selectTab(sessions ? "artifacts" : "sessions");
                else
                    return;
                event.accepted = true;
            }
        }

        ListView {
            id: list

            visible: root.tab === "sessions"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, popup.height * 0.85 - 360)
            spacing: 4
            clip: true
            model: root.filtered
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            highlight: Rectangle {
                radius: 18
                color: Theme.colour("secondaryContainer")
            }

            delegate: SessionRow {}
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.tab === "sessions" && root.scanned && list.count === 0
            text: root.entries.length === 0 ? "Aucune session" : "Aucune session ne correspond"
            color: Theme.colour("onSurfaceVariant")
        }

        ListView {
            id: artifactList

            visible: root.tab === "artifacts"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, popup.height * 0.85 - 360)
            spacing: 4
            clip: true
            model: root.filteredArtifacts
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            highlight: Rectangle {
                radius: 18
                color: Theme.colour("secondaryContainer")
            }

            delegate: ArtifactRow {}
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: root.tab === "artifacts" && artifactList.count === 0
            text: !root.artifacts ? "La liste apparaîtra au prochain lancement de Claude Code (mod artifacts-export)." : root.query ? "Aucun artifact ne correspond" : "Aucun artifact"
            color: Theme.colour("onSurfaceVariant")
            wrapMode: Text.Wrap
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.tab === "artifacts" && !!root.artifacts
            text: root.artifacts ? `Liste relevée ${root.ago(root.artifacts.updatedAt / 1000)} par une session Claude Code` : ""
            color: Theme.colour("onSurfaceVariant")
            font.pointSize: 9
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Hint {
                keys: ["Entrée"]
                text: root.tab === "sessions" ? "aller au terminal ou reprendre" : "ouvrir"
            }
            Hint {
                keys: ["Ctrl", "C"]
                text: root.tab === "sessions" ? "copier la commande" : "copier le lien"
            }
            Hint {
                keys: ["Tab"]
                text: "changer d'onglet"
            }
            Hint {
                keys: ["Échap"]
                text: "fermer"
            }
        }
    }

    component SessionRow: Item {
        id: row

        required property var modelData
        required property int index

        readonly property bool current: ListView.isCurrentItem
        readonly property bool usable: modelData.live || modelData.exists

        width: ListView.view.width
        implicitHeight: 64

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onEntered: list.currentIndex = row.index
            onClicked: root.open(row.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 14

            // En cours : pastille pleine qui pulse quand Claude travaille.
            Rectangle {
                implicitWidth: 12
                implicitHeight: 12
                radius: 6
                color: row.modelData.live ? (row.modelData.status === "busy" ? Theme.colour("primary") : Theme.colour("tertiary")) : "transparent"
                border.width: row.modelData.live ? 0 : 2
                border.color: Theme.colour("outlineVariant")

                SequentialAnimation on opacity {
                    running: row.modelData.live && row.modelData.status === "busy"
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0.35
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    text: row.modelData.title || row.modelData.prompt || "Session sans titre"
                    color: row.current ? Theme.colour("onSecondaryContainer") : row.usable ? Theme.colour("onSurface") : Theme.colour("onSurfaceVariant")
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    text: [root.project(row.modelData), root.branch(row.modelData), root.status(row.modelData), row.modelData.modified ? root.ago(row.modelData.modified) : ""].filter(x => x).join(" · ")
                    color: row.modelData.live ? Theme.colour("primary") : Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    visible: !!row.modelData.prompt && !!row.modelData.title
                    text: `« ${(row.modelData.prompt ?? "").replace(/\s+/g, " ")} »`
                    color: Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                    font.italic: true
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: row.current && row.usable
                icon: row.modelData.live ? "open_in_new" : "replay"
                onClicked: root.open(row.modelData)
            }

            IconButton {
                visible: row.current
                icon: "content_copy"
                onClicked: root.copy(row.modelData)
            }
        }
    }

    component ArtifactRow: Item {
        id: artifactRow

        required property var modelData
        required property int index

        readonly property bool current: ListView.isCurrentItem

        width: ListView.view.width
        implicitHeight: 56

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: artifactList.currentIndex = artifactRow.index
            onClicked: root.openArtifact(artifactRow.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 14

            Icon {
                text: artifactRow.modelData.isMine ? "web" : "group"
                color: artifactRow.modelData.isMine ? Theme.colour("primary") : Theme.colour("onSurfaceVariant")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    text: artifactRow.modelData.title
                    color: artifactRow.current ? Theme.colour("onSecondaryContainer") : Theme.colour("onSurface")
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    text: [artifactRow.modelData.isMine ? "à toi" : "partagé avec toi", root.updated(artifactRow.modelData.updated ?? "")].filter(x => x).join(" · ")
                    color: Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: artifactRow.current
                icon: "content_copy"
                onClicked: root.copyArtifact(artifactRow.modelData)
            }

            IconButton {
                visible: artifactRow.current
                icon: "open_in_new"
                onClicked: root.openArtifact(artifactRow.modelData)
            }
        }
    }
}
