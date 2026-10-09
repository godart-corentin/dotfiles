// Délais d'inactivité de Caelestia (verrouillage, écran, mise en veille), réglables à la volée.
// Réécrit general.idle.timeouts dans ~/.config/caelestia/shell.json, que Caelestia relit à chaud.
// Ouverture : qs-outil inactivite (Super+I).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/caelestia/shell.json"

    // Liste appliquée par Caelestia quand shell.json ne définit pas general.idle.timeouts.
    readonly property var defaultTimeouts: [
        { timeout: 180, idleAction: "lock" },
        { timeout: 300, idleAction: "dpms off", returnAction: "dpms on" },
        { timeout: 600, idleAction: ["systemctl", "suspend-then-hibernate"] }
    ]

    property var config: null
    property string error: ""
    property var delays: ({ lock: 0, dpms: 0, suspend: 0 })
    property bool keepAwake: false

    function kindOf(entry: var): string {
        const action = entry.idleAction;
        if (action === "lock")
            return "lock";
        if (action === "dpms off")
            return "dpms";
        if (Array.isArray(action) && action.join(" ").includes("suspend"))
            return "suspend";
        return "";
    }

    function format(seconds: int): string {
        if (seconds <= 0)
            return "Jamais";
        if (seconds < 60)
            return `${seconds} s`;
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round(seconds % 3600 / 60);
        if (hours && minutes)
            return `${hours} h ${String(minutes).padStart(2, "0")}`;
        return hours ? `${hours} h` : `${minutes} min`;
    }

    // « 45 » = 45 min ; accepte aussi « 90m », « 2h », « 1h30 », « 1 h 30 min ». Renvoie -1 si invalide.
    function parseDuration(input: string): int {
        const text = input.toLowerCase().replace(/\s+/g, "");
        const match = text.match(/^(?:(\d+)h)?(?:(\d+)(?:m|min)?)?$/);
        if (!text || !match)
            return -1;
        const seconds = parseInt(match[1] ?? "0") * 3600 + parseInt(match[2] ?? "0") * 60;
        return seconds > 0 && seconds <= 24 * 3600 ? seconds : -1;
    }

    function parseConfig(): void {
        try {
            config = JSON.parse(configFile.text());
        } catch (e) {
            config = null;
            error = `shell.json illisible : ${e.message}`;
            return;
        }
        error = "";

        const timeouts = config.general?.idle?.timeouts;
        const found = { lock: 0, dpms: 0, suspend: 0 };
        for (const entry of Array.isArray(timeouts) ? timeouts : defaultTimeouts) {
            const kind = kindOf(entry);
            if (kind && (entry.enabled ?? true))
                found[kind] = entry.timeout;
        }
        delays = found;
    }

    function setDelay(kind: string, seconds: int): void {
        if (!config)
            return;

        const general = config.general || (config.general = {});
        const idle = general.idle || (general.idle = {});
        const current = Array.isArray(idle.timeouts) ? idle.timeouts : defaultTimeouts;
        // Les entrées inconnues (actions perso) sont gardées telles quelles.
        const next = current.filter(e => kindOf(e) !== kind);

        if (seconds > 0) {
            const previous = current.find(e => kindOf(e) === kind) ?? defaultTimeouts.find(e => kindOf(e) === kind);
            const entry = Object.assign({}, previous, { timeout: seconds });
            delete entry.enabled;
            next.push(entry);
        }
        next.sort((a, b) => a.timeout - b.timeout);
        idle.timeouts = next;

        configFile.setText(JSON.stringify(config, null, 4) + "\n");
        delays = Object.assign({}, delays, { [kind]: seconds });
    }

    function setKeepAwake(enabled: bool): void {
        keepAwake = enabled;
        Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "idleInhibitor", enabled ? "enable" : "disable"]);
    }

    FileView {
        id: configFile

        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseConfig()
        onLoadFailed: root.error = "shell.json introuvable"
    }

    Process {
        running: true
        command: ["qs", "-c", "caelestia", "ipc", "call", "idleInhibitor", "isEnabled"]
        stdout: StdioCollector {
            onStreamFinished: root.keepAwake = text.trim() === "true"
        }
    }

    Popup {
        id: popup

        layerName: "inactivite"
        panelWidth: 640

        Header {
            icon: "bedtime"
            title: "Inactivité"
            subtitle: "Appliqué tout de suite · Échap pour fermer"
        }

        Label {
            visible: root.error !== ""
            text: root.error
            color: Theme.colour("error")
        }

        DelayRow {
            kind: "lock"
            icon: "lock"
            title: "Verrouillage"
            choices: [0, 180, 300, 600, 900, 1800]
        }

        DelayRow {
            kind: "dpms"
            icon: "desktop_access_disabled"
            title: "Écran éteint"
            choices: [0, 300, 600, 900, 1800, 3600]
        }

        DelayRow {
            kind: "suspend"
            icon: "bedtime"
            title: "Mise en veille"
            choices: [0, 600, 900, 1800, 3600, 7200]
        }

        Card {
            implicitHeight: awakeRow.implicitHeight + 32

            RowLayout {
                id: awakeRow

                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                IconBadge {
                    icon: "coffee"
                    fill: root.keepAwake ? Theme.colour("secondary") : Theme.colour("secondaryContainer")
                    ink: root.keepAwake ? Theme.colour("onSecondary") : Theme.colour("onSecondaryContainer")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        text: "Rester éveillé"
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.keepAwake ? "Aucun délai ne s'applique" : "Délais ci-dessus actifs"
                        color: Theme.colour("onSurfaceVariant")
                        font.pointSize: 10
                    }
                }

                Switch {
                    checked: root.keepAwake
                    onToggled: root.setKeepAwake(!root.keepAwake)
                }
            }
        }
    }

    component DelayRow: Card {
        id: row

        required property string kind
        required property string icon
        required property string title
        required property var choices

        readonly property int current: root.delays[kind] ?? 0
        // La valeur actuelle reste visible même si elle n'est pas dans les choix proposés.
        readonly property var options: choices.concat(choices.includes(current) ? [] : [current]).sort((a, b) => a - b)

        implicitHeight: rowContent.implicitHeight + 32

        ColumnLayout {
            id: rowContent

            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                spacing: 10

                Icon {
                    text: row.icon
                    color: Theme.colour("primary")
                }

                Label {
                    Layout.fillWidth: true
                    text: row.title
                }

                Label {
                    text: row.current > 0 ? `après ${root.format(row.current)}` : "désactivé"
                    color: Theme.colour("onSurfaceVariant")
                    font.pointSize: 10
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: row.options

                    Chip {
                        required property int modelData

                        text: root.format(modelData)
                        selected: modelData === row.current
                        onClicked: root.setDelay(row.kind, modelData)
                    }
                }

                CustomChip {
                    onSubmitted: seconds => root.setDelay(row.kind, seconds)
                }
            }
        }
    }

    // Puce « Autre » qui se transforme en champ de saisie (Entrée pour valider, Échap pour annuler).
    component CustomChip: Rectangle {
        id: custom

        property bool editing
        readonly property int parsed: root.parseDuration(input.text)
        readonly property bool invalid: input.text.trim() !== "" && parsed < 0

        signal submitted(int seconds)

        function close(): void {
            editing = false;
            input.text = "";
            popup.panel.forceActiveFocus();
        }

        implicitWidth: editing ? 168 : customRow.implicitWidth + 28
        implicitHeight: 34
        radius: 17
        color: Theme.colour("surfaceContainerHighest")
        border.width: editing ? 2 : 0
        border.color: invalid ? Theme.colour("error") : Theme.colour("primary")

        Behavior on implicitWidth {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.colour("onSurface")
            opacity: custom.editing ? 0 : customArea.pressed ? 0.12 : customArea.containsMouse ? 0.08 : 0
        }

        Row {
            id: customRow

            anchors.centerIn: parent
            spacing: 4
            visible: !custom.editing

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: "edit"
                font.pixelSize: 16
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Autre"
                font.pointSize: 10
            }
        }

        MouseArea {
            id: customArea

            anchors.fill: parent
            visible: !custom.editing
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                custom.editing = true;
                input.forceActiveFocus();
            }
        }

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            visible: custom.editing
            clip: true
            color: Theme.colour("onSurface")
            selectionColor: Theme.colour("primary")
            selectedTextColor: Theme.colour("onPrimary")
            font.family: Theme.font
            font.pointSize: 10

            onAccepted: {
                if (custom.parsed > 0) {
                    custom.submitted(custom.parsed);
                    custom.close();
                }
            }
            onActiveFocusChanged: {
                if (!activeFocus && custom.editing)
                    custom.close();
            }
            Keys.onEscapePressed: custom.close()

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: !input.text
                text: "min, ou 1h30"
                color: Theme.colour("onSurfaceVariant")
                font.pointSize: 10
            }
        }
    }
}
