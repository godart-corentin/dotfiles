import QtQuick
import QtQuick.Layouts

// Champ de recherche qui prend le focus à l'ouverture. Échap le vide, puis demande la fermeture.
// Les autres touches remontent par keyPressed ; event.accepted les retient.
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder

    signal keyPressed(var event)
    signal closeRequested

    Layout.fillWidth: true
    implicitHeight: 44
    radius: 22
    color: Theme.colour("surfaceContainer")

    Icon {
        id: searchIcon

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "search"
        color: Theme.colour("onSurfaceVariant")
        font.pixelSize: 20
    }

    TextInput {
        id: input

        anchors.left: searchIcon.right
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.colour("onSurface")
        selectionColor: Theme.colour("primary")
        selectedTextColor: Theme.colour("onPrimary")
        font.family: Theme.font
        font.pointSize: 11
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape) {
                field.keyPressed(event);
                return;
            }
            event.accepted = true;
            if (text)
                text = "";
            else
                field.closeRequested();
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.text
            text: field.placeholder
            color: Theme.colour("onSurfaceVariant")
        }
    }
}
