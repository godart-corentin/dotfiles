// GitHub : tes PR ouvertes (CI, revue), les revues qu'on te demande et les issues qui te sont assignées.
// Une requête GraphQL via gh ; le dernier résultat est gardé en cache (~/.cache/github-outil.json)
// pour s'afficher tout de suite, puis remplacé une fois la requête terminée.
// Ouverture : qs-outil github (Super+G).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string workspace: Quickshell.env("HOME") + "/workspace"
    readonly property string query: `
        fragment pr on PullRequest {
            number title url isDraft updatedAt reviewDecision additions deletions
            repository { nameWithOwner name } author { login }
            commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
        }
        fragment issue on Issue {
            number title url updatedAt repository { nameWithOwner name } author { login }
            labels(first: 3) { nodes { name } }
        }
        query {
            mine: search(query: "is:pr is:open author:@me archived:false sort:updated-desc", type: ISSUE, first: 50) { nodes { ...pr } }
            reviews: search(query: "is:pr is:open review-requested:@me archived:false sort:updated-desc", type: ISSUE, first: 50) { nodes { ...pr } }
            issues: search(query: "is:issue is:open assignee:@me archived:false sort:updated-desc", type: ISSUE, first: 50) { nodes { ...issue } }
        }`

    readonly property var tabs: [
        { id: "reviews", icon: "rate_review", title: "Revues demandées" },
        { id: "mine", icon: "merge", title: "Mes PR" },
        { id: "issues", icon: "adjust", title: "Issues assignées" }
    ]

    property var results: ({ mine: [], reviews: [], issues: [] })
    property real fetchedAt: 0
    property bool loading: true
    property string error: ""
    property string tab: ""
    property string search: ""
    property var projects: []

    readonly property string currentTab: tab || (results.reviews.length > 0 ? "reviews" : "mine")
    readonly property var filtered: {
        const query = root.search.trim().toLowerCase();
        return (results[currentTab] ?? []).filter(item => !query || `${item.title} ${item.repository.nameWithOwner} #${item.number}`.toLowerCase().includes(query));
    }
    readonly property var selected: list.currentIndex >= 0 && list.currentIndex < filtered.length ? filtered[list.currentIndex] : null

    function ago(date: string): string {
        const minutes = Math.floor((Date.now() - Date.parse(date)) / 60000);
        if (minutes < 1)
            return "à l'instant";
        if (minutes < 60)
            return `il y a ${minutes} min`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return `il y a ${hours} h`;
        const days = Math.floor(hours / 24);
        return days < 30 ? `il y a ${days} j` : `il y a ${Math.floor(days / 30)} mois`;
    }

    function ci(item: var): string {
        return item.commits?.nodes[0]?.commit.statusCheckRollup?.state ?? "";
    }

    function ciIcon(state: string): string {
        if (state === "SUCCESS")
            return "check_circle";
        if (state === "FAILURE" || state === "ERROR")
            return "cancel";
        if (state === "PENDING" || state === "EXPECTED")
            return "schedule";
        return "radio_button_unchecked";
    }

    function details(item: var): string {
        const parts = [`${item.repository.nameWithOwner} #${item.number}`];
        if (currentTab !== "mine" && item.author)
            parts.push(`par ${item.author.login}`);
        parts.push(ago(item.updatedAt));
        if (item.isDraft)
            parts.push("brouillon");
        else if (item.reviewDecision === "APPROVED")
            parts.push("approuvée");
        else if (item.reviewDecision === "CHANGES_REQUESTED")
            parts.push("changements demandés");
        else if (item.reviewDecision === "REVIEW_REQUIRED")
            parts.push("en attente de revue");
        if (item.additions !== undefined)
            parts.push(`+${item.additions} −${item.deletions}`);
        if (item.labels?.nodes.length)
            parts.push(item.labels.nodes.map(l => l.name).join(", "));
        return parts.join(" · ");
    }

    function load(text: string, fetchedAt: real): void {
        const result = JSON.parse(text);
        results = {
            mine: result.mine.nodes,
            reviews: result.reviews.nodes,
            issues: result.issues.nodes
        };
        root.fetchedAt = fetchedAt;
    }

    function project(item: var): string {
        return item && projects.includes(item.repository.name) ? `${workspace}/${item.repository.name}` : "";
    }

    function open(item: var, how: string): void {
        if (!item)
            return;
        if (how === "web")
            Quickshell.execDetached(["xdg-open", item.url]);
        else if (how === "copy")
            Quickshell.execDetached(["wl-copy", "--", item.url]);
        else if (how === "zed" && project(item))
            Quickshell.execDetached(["uwsm", "app", "--", "zeditor", project(item)]);
        else
            return;
        popup.close();
    }

    function selectTab(id: string): void {
        tab = id;
        list.currentIndex = 0;
    }

    FileView {
        id: cache

        path: Quickshell.env("HOME") + "/.cache/github-outil.json"
        printErrors: false
        onLoaded: {
            // Le cache ne remplace pas un résultat plus récent déjà arrivé.
            try {
                const saved = JSON.parse(text());
                if (root.fetchedAt < saved.fetchedAt)
                    root.load(JSON.stringify(saved.data), saved.fetchedAt);
            } catch (e) {}
        }
    }

    Process {
        running: true
        command: ["gh", "api", "graphql", "-f", `query=${root.query}`, "--jq", ".data"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text)
                    return;
                const now = Date.now();
                root.load(text, now);
                cache.setText(JSON.stringify({ fetchedAt: now, data: JSON.parse(text) }) + "\n");
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim().split("\n")[0] ?? ""
        }
        onExited: root.loading = false
    }

    Process {
        running: true
        command: ["ls", root.workspace]
        stdout: StdioCollector {
            onStreamFinished: root.projects = text.split("\n").filter(name => name)
        }
    }

    Popup {
        id: popup

        layerName: "github"
        panelWidth: 760

        Header {
            icon: "hub"
            title: "GitHub"
            subtitle: root.loading ? (root.fetchedAt ? `Mise à jour… (affiché : ${root.ago(new Date(root.fetchedAt).toISOString())})` : "Chargement…") : root.error ? `Échec de la mise à jour : ${root.error}` : `À jour · ${root.results.mine.length} PR · ${root.results.reviews.length} revues · ${root.results.issues.length} issues`
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.tabs

                Chip {
                    required property var modelData

                    icon: modelData.icon
                    text: `${modelData.title} · ${root.results[modelData.id].length}`
                    selected: root.currentTab === modelData.id
                    onClicked: root.selectTab(modelData.id)
                }
            }
        }

        SearchField {
            placeholder: "Filtrer par titre, dépôt ou numéro"
            onTextChanged: {
                root.search = text;
                list.currentIndex = 0;
            }
            onCloseRequested: popup.close()
            onKeyPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                const ids = root.tabs.map(t => t.id);
                if (event.key === Qt.Key_Up)
                    list.decrementCurrentIndex();
                else if (event.key === Qt.Key_Down)
                    list.incrementCurrentIndex();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.open(root.selected, ctrl ? "zed" : "web");
                else if (event.key === Qt.Key_C && ctrl)
                    root.open(root.selected, "copy");
                else if (event.key === Qt.Key_Tab)
                    root.selectTab(ids[(ids.indexOf(root.currentTab) + 1) % ids.length]);
                else if (event.key === Qt.Key_Backtab)
                    root.selectTab(ids[(ids.indexOf(root.currentTab) + ids.length - 1) % ids.length]);
                else
                    return;
                event.accepted = true;
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(64, Math.min(contentHeight, popup.height * 0.85 - 260))
            spacing: 4
            clip: true
            model: root.filtered
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            highlight: Rectangle {
                radius: 18
                color: Theme.colour("secondaryContainer")
            }

            delegate: ItemRow {}

            Label {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.loading && !root.fetchedAt ? "Chargement…" : root.search ? "Rien ne correspond" : root.currentTab === "reviews" ? "Aucune revue demandée" : root.currentTab === "mine" ? "Aucune PR ouverte" : "Aucune issue assignée"
                color: Theme.colour("onSurfaceVariant")
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Hint {
                keys: ["Entrée"]
                text: "ouvrir"
            }
            Hint {
                keys: ["Ctrl", "Entrée"]
                text: "projet dans Zed"
            }
            Hint {
                keys: ["Ctrl", "C"]
                text: "copier le lien"
            }
            Hint {
                keys: ["Tab"]
                text: "onglet suivant"
            }
        }
    }

    component ItemRow: Item {
        id: row

        required property var modelData
        required property int index

        readonly property bool current: ListView.isCurrentItem
        readonly property string ciState: root.ci(modelData)

        width: ListView.view.width
        implicitHeight: 60

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: list.currentIndex = row.index
            onClicked: root.open(row.modelData, "web")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 14

            // État de la CI pour une PR, pastille d'issue sinon.
            Icon {
                text: root.currentTab === "issues" ? "adjust" : root.ciIcon(row.ciState)
                color: row.ciState === "FAILURE" || row.ciState === "ERROR" ? Theme.colour("error") : row.ciState === "SUCCESS" || root.currentTab === "issues" ? Theme.colour("primary") : Theme.colour("onSurfaceVariant")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    text: row.modelData.title
                    color: row.current ? Theme.colour("onSecondaryContainer") : Theme.colour("onSurface")
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    text: root.details(row.modelData)
                    color: Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: row.current && !!root.project(row.modelData)
                icon: "edit_note"
                onClicked: root.open(row.modelData, "zed")
            }

            IconButton {
                visible: row.current
                icon: "content_copy"
                onClicked: root.open(row.modelData, "copy")
            }

            IconButton {
                visible: row.current
                icon: "open_in_new"
                onClicked: root.open(row.modelData, "web")
            }
        }
    }
}
