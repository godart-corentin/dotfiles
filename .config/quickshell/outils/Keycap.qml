import QtQuick

// Une touche de clavier, pour afficher un raccourci.
Rectangle {
    id: keycap

    property string text

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 16)
    implicitHeight: 26
    radius: 8
    color: Theme.colour("surfaceContainerHighest")
    border.width: 1
    border.color: Theme.colour("outlineVariant")

    Label {
        id: label

        anchors.centerIn: parent
        text: keycap.text
        font.pointSize: 9
        font.weight: Font.Medium
    }
}
