pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Couleurs du schéma Caelestia en cours (suit les changements de fond d'écran) et polices du shell.
Singleton {
    id: root

    readonly property string font: "Rubik"
    readonly property string iconFont: "Material Symbols Rounded"
    property var scheme: ({})

    function colour(name: string): color {
        const hex = scheme[name];
        return hex ? "#" + hex : "#808080";
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.scheme = JSON.parse(text()).colours;
            } catch (e) {}
        }
    }
}
