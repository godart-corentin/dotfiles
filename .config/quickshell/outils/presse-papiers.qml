// Historique du presse-papiers (cliphist) avec aperçu des images, recherche et épinglage.
// Les épinglés sont gardés hors de cliphist, qui ne conserve que les 750 dernières entrées :
// le texte dans ~/.local/state/presse-papiers-epingles.json, les images dans ~/.local/share/presse-papiers.
// Ouverture : qs-outil presse-papiers (Super+V).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pinsDir: home + "/.local/share/presse-papiers"
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/presse-papiers"

    readonly property var filters: [
        { id: "tout", title: "Tout" },
        { id: "epingles", title: "Épinglés", icon: "keep" },
        { id: "texte", title: "Texte", icon: "notes" },
        { id: "images", title: "Images", icon: "image" }
    ]

    property var history: []
    property var pins: []
    property string filter: "tout"
    property string query: ""
    property bool confirmWipe: false

    readonly property var entries: pins.concat(history)
    readonly property var filtered: {
        const query = normalize(root.query.trim());
        return entries.filter(entry => {
            if (filter === "epingles" && !entry.pinned)
                return false;
            if (filter === "texte" && entry.kind !== "text")
                return false;
            if (filter === "images" && entry.kind !== "image")
                return false;
            return !query || normalize(entry.kind === "text" ? entry.text : `image ${entry.format}`).includes(query);
        });
    }
    readonly property var selected: list.currentIndex >= 0 && list.currentIndex < filtered.length ? filtered[list.currentIndex] : null

    function normalize(text: string): string {
        return text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    // « [[ binary data 1 MiB png 1920x1080 ]] » → image ; le reste est du texte.
    function parseHistory(output: string): void {
        const entries = [];
        for (const line of output.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 0)
                continue;
            const id = line.slice(0, tab);
            const preview = line.slice(tab + 1);
            const image = preview.match(/^\[\[ binary data (.+) (\w+) (\d+)x(\d+) \]\]$/);
            if (image)
                entries.push({ key: `h${id}`, id, kind: "image", size: image[1], format: image[2], width: +image[3], height: +image[4] });
            else
                entries.push({ key: `h${id}`, id, kind: "text", text: preview });
        }
        history = entries;
    }

    function describe(entry: var): string {
        const size = entry.size ? ` · ${entry.size.replace("KiB", "Kio").replace("MiB", "Mio").replace(" B", " o")}` : "";
        return `${entry.format.toUpperCase()} · ${entry.width}×${entry.height}${size}`;
    }

    // Fichier d'une image : copie épinglée, ou cache décodé (la clé suit l'entrée cliphist).
    function imagePath(entry: var): string {
        return entry.pinned ? entry.file : `${cacheDir}/${entry.id}-${entry.width}x${entry.height}`;
    }

    function copy(entry: var): void {
        if (!entry)
            return;
        if (!entry.pinned)
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id]);
        else if (entry.kind === "text")
            Quickshell.execDetached(["wl-copy", "--", entry.text]);
        else
            Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "sh", entry.file]);
        popup.close();
    }

    function remove(entry: var): void {
        if (!entry)
            return;
        const index = list.currentIndex;
        if (entry.pinned) {
            if (entry.kind === "image")
                Quickshell.execDetached(["rm", "-f", "--", entry.file]);
            pins = pins.filter(pin => pin.key !== entry.key);
            savePins();
        } else {
            Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", entry.id]);
            history = history.filter(item => item.key !== entry.key);
        }
        Qt.callLater(() => list.currentIndex = Math.min(index, filtered.length - 1));
    }

    function togglePin(entry: var): void {
        if (!entry)
            return;
        if (entry.pinned) {
            remove(entry);
            return;
        }
        // Le texte complet (l'historique n'en donne qu'un aperçu) ou une copie durable de l'image.
        pinner.entry = entry;
        pinner.command = entry.kind === "text" ? ["cliphist", "decode", entry.id] : ["sh", "-c", 'mkdir -p "$1" && cliphist decode "$2" > "$1/$3" && printf "%s" "$1/$3"', "sh", pinsDir, entry.id, `${Date.now()}.${entry.format}`];
        pinner.running = true;
    }

    function savePins(): void {
        pinsFile.setText(JSON.stringify(pins.map(pin => {
            const saved = Object.assign({}, pin);
            delete saved.key;
            delete saved.pinned;
            return saved;
        }), null, 2) + "\n");
    }

    function wipe(): void {
        if (!confirmWipe) {
            confirmWipe = true;
            wipeTimer.restart();
            return;
        }
        Quickshell.execDetached(["cliphist", "wipe"]);
        history = [];
        confirmWipe = false;
    }

    Process {
        running: true
        command: ["cliphist", "list", "-preview-width", "300"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHistory(text)
        }
    }

    Process {
        id: pinner

        property var entry

        stdout: StdioCollector {
            onStreamFinished: {
                const entry = pinner.entry;
                const pin = entry.kind === "text" ? { kind: "text", text: text } : { kind: "image", file: text, format: entry.format, width: entry.width, height: entry.height, size: entry.size };
                if (!(pin.text || pin.file))
                    return;
                root.pins = [Object.assign(pin, { key: `p${Date.now()}`, pinned: true })].concat(root.pins);
                root.savePins();
            }
        }
    }

    FileView {
        id: pinsFile

        path: root.home + "/.local/state/presse-papiers-epingles.json"
        printErrors: false
        onLoaded: {
            try {
                root.pins = JSON.parse(text()).map((pin, i) => Object.assign(pin, { key: `p${i}`, pinned: true }));
            } catch (e) {}
        }
    }

    Timer {
        id: wipeTimer

        interval: 3000
        onTriggered: root.confirmWipe = false
    }

    // Aperçu du texte sélectionné, décodé en entier (dans la limite de 20 000 octets).
    Process {
        id: textPreview

        property string text

        stdout: StdioCollector {
            onStreamFinished: textPreview.text = text
        }
    }

    Timer {
        id: previewTimer

        interval: 60
        onTriggered: {
            const entry = root.selected;
            textPreview.running = false;
            textPreview.text = entry?.pinned && entry.kind === "text" ? entry.text : "";
            if (entry && !entry.pinned && entry.kind === "text") {
                textPreview.command = ["sh", "-c", 'cliphist decode "$1" | head -c 20000', "sh", entry.id];
                textPreview.running = true;
            }
        }
    }

    onSelectedChanged: previewTimer.restart()

    Popup {
        id: popup

        layerName: "presse-papiers"
        panelWidth: Math.min(1040, width - 64)

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Header {
                Layout.fillWidth: true
                icon: "content_paste"
                title: "Presse-papiers"
                subtitle: `${root.history.length} entrées · ${root.pins.length} épinglées · clic ou Entrée pour copier`
            }

            Chip {
                visible: root.history.length > 0
                icon: "delete_sweep"
                text: root.confirmWipe ? "Confirmer ?" : "Vider l'historique"
                selected: root.confirmWipe
                onClicked: root.wipe()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SearchField {
                id: search

                placeholder: "Chercher dans l'historique"
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
                        root.copy(root.selected);
                    else if (event.key === Qt.Key_Delete && shift)
                        root.remove(root.selected);
                    else if (event.key === Qt.Key_P && ctrl)
                        root.togglePin(root.selected);
                    else
                        return;
                    event.accepted = true;
                }
            }

            Repeater {
                model: root.filters

                Chip {
                    required property var modelData

                    icon: modelData.icon ?? ""
                    text: modelData.title
                    selected: root.filter === modelData.id
                    onClicked: {
                        root.filter = modelData.id;
                        list.currentIndex = 0;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(480, popup.height * 0.85 - 220)
            spacing: 12

            ListView {
                id: list

                // Largeurs 55/45 : les deux colonnes s'étirent au prorata de leur largeur préférée.
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 55
                clip: true
                spacing: 4
                model: root.filtered
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 120
                highlight: Rectangle {
                    radius: 16
                    color: Theme.colour("secondaryContainer")
                }

                delegate: EntryRow {}

                Label {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: root.entries.length === 0 ? "Historique vide" : "Rien ne correspond"
                    color: Theme.colour("onSurfaceVariant")
                }
            }

            Card {
                Layout.fillHeight: true
                Layout.preferredWidth: 45

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 16
                    visible: root.selected?.kind === "text"
                    contentHeight: previewText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Text {
                        id: previewText

                        width: parent.width
                        text: textPreview.text
                        wrapMode: Text.WrapAnywhere
                        color: Theme.colour("onSurface")
                        font.family: "CaskaydiaCove NF"
                        font.pointSize: 10
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    visible: root.selected?.kind === "image"
                    spacing: 10

                    CachedImage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        entry: root.selected?.kind === "image" ? root.selected : null
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.selected?.kind === "image" ? root.describe(root.selected) : ""
                        color: Theme.colour("onSurfaceVariant")
                        font.pointSize: 10
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Hint {
                keys: ["↑", "↓"]
                text: "naviguer"
            }
            Hint {
                keys: ["Entrée"]
                text: "copier"
            }
            Hint {
                keys: ["Ctrl", "P"]
                text: "épingler"
            }
            Hint {
                keys: ["Maj", "Suppr"]
                text: "supprimer"
            }
            Hint {
                keys: ["Échap"]
                text: "fermer"
            }
        }
    }

    // Image d'une entrée, décodée depuis cliphist dans le cache au premier affichage.
    component CachedImage: Image {
        id: image

        property var entry
        property string file

        asynchronous: true
        fillMode: Image.PreserveAspectFit
        source: file ? "file://" + file : ""

        onEntryChanged: {
            file = "";
            if (!entry)
                return;
            if (entry.pinned) {
                file = entry.file;
                return;
            }
            decoder.running = false;
            decoder.command = ["sh", "-c", '[ -s "$2" ] || { mkdir -p "$1" && cliphist decode "$3" > "$2.$$" && mv "$2.$$" "$2"; }; printf "%s" "$2"', "sh", root.cacheDir, root.imagePath(entry), entry.id];
            decoder.running = true;
        }

        Process {
            id: decoder

            stdout: StdioCollector {
                onStreamFinished: image.file = text
            }
        }
    }

    component EntryRow: Item {
        id: row

        required property var modelData
        required property int index

        readonly property bool current: ListView.isCurrentItem
        readonly property bool isLink: modelData.kind === "text" && /^https?:\/\/\S+$/.test(modelData.text.trim())

        width: ListView.view.width
        implicitHeight: modelData.kind === "image" ? 84 : 52

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: list.currentIndex = row.index
            onClicked: root.copy(row.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 12

            Icon {
                visible: row.modelData.kind === "text"
                text: row.modelData.pinned ? "keep" : row.isLink ? "link" : "notes"
                color: row.modelData.pinned ? Theme.colour("primary") : Theme.colour("onSurfaceVariant")
                font.pixelSize: 20
            }

            CachedImage {
                visible: row.modelData.kind === "image"
                Layout.preferredWidth: 96
                Layout.preferredHeight: 64
                sourceSize.width: 192
                entry: row.modelData.kind === "image" ? row.modelData : null
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    text: row.modelData.kind === "text" ? row.modelData.text.replace(/\s+/g, " ").trim() : "Image"
                    color: row.current ? Theme.colour("onSecondaryContainer") : Theme.colour("onSurface")
                    font.pointSize: 10
                    maximumLineCount: 2
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    visible: row.modelData.kind === "image" || !!row.modelData.pinned
                    text: (row.modelData.pinned ? "Épinglé" : "") + (row.modelData.pinned && row.modelData.kind === "image" ? " · " : "") + (row.modelData.kind === "image" ? root.describe(row.modelData) : "")
                    color: Theme.colour("onSurfaceVariant")
                    font.pointSize: 9
                }
            }

            IconButton {
                visible: row.current
                size: 32
                icon: row.modelData.pinned ? "keep_off" : "keep"
                ink: row.modelData.pinned ? Theme.colour("primary") : Theme.colour("onSurfaceVariant")
                onClicked: root.togglePin(row.modelData)
            }

            IconButton {
                visible: row.current
                size: 32
                icon: "delete"
                onClicked: root.remove(row.modelData)
            }
        }
    }
}
