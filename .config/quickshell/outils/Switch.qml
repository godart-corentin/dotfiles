import QtQuick

Rectangle {
    id: toggle

    property bool checked

    signal toggled

    implicitWidth: 52
    implicitHeight: 32
    radius: 16
    color: checked ? Theme.colour("primary") : Theme.colour("surfaceContainerHighest")
    border.width: checked ? 0 : 2
    border.color: Theme.colour("outline")

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Rectangle {
        readonly property int size: toggle.checked ? 24 : 16

        x: toggle.checked ? toggle.width - width - 4 : 8
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: toggle.checked ? Theme.colour("onPrimary") : Theme.colour("outline")

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on implicitWidth {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
