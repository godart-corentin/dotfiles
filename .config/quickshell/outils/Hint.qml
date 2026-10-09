import QtQuick

// Raccourci clavier suivi de son effet, pour les barres d'aide en bas des fenêtres.
Row {
    id: hint

    property var keys
    property string text

    spacing: 4

    Repeater {
        model: hint.keys

        Keycap {
            required property string modelData

            text: modelData
        }
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 2
        text: hint.text
        color: Theme.colour("onSurfaceVariant")
        font.pointSize: 9
    }
}
