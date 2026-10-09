import QtQuick

Rectangle {
    id: chip

    property string text
    property string icon
    property bool selected

    signal clicked

    implicitWidth: content.implicitWidth + 28
    implicitHeight: 34
    radius: 17
    color: selected ? Theme.colour("primary") : Theme.colour("surfaceContainerHighest")

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: chip.selected ? Theme.colour("onPrimary") : Theme.colour("onSurface")
        opacity: area.pressed ? 0.12 : area.containsMouse ? 0.08 : 0
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.icon !== ""
            text: chip.icon
            color: chip.selected ? Theme.colour("onPrimary") : Theme.colour("onSurface")
            font.pixelSize: 16
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            color: chip.selected ? Theme.colour("onPrimary") : Theme.colour("onSurface")
            font.pointSize: 10
            font.weight: chip.selected ? Font.Medium : Font.Normal
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
