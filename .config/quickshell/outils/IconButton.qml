import QtQuick

Rectangle {
    id: button

    property string icon
    property color ink: Theme.colour("onSurfaceVariant")
    property int size: 36

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: area.containsMouse ? Qt.alpha(Theme.colour("onSurface"), 0.1) : "transparent"

    Icon {
        anchors.centerIn: parent
        text: button.icon
        color: button.ink
        font.pixelSize: button.size * 0.55
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
