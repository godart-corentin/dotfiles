import QtQuick

Rectangle {
    id: badge

    property string icon
    property color fill: Theme.colour("primaryContainer")
    property color ink: Theme.colour("onPrimaryContainer")

    implicitWidth: 44
    implicitHeight: 44
    radius: 22
    color: fill

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Icon {
        anchors.centerIn: parent
        text: badge.icon
        color: badge.ink
    }
}
