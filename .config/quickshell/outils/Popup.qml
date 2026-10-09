import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Fenêtre centrée au-dessus de tout ; Échap ou un clic à côté la ferment.
PanelWindow {
    id: popup

    required property string layerName
    property int panelWidth: 560
    property alias panel: panel
    default property alias content: body.data

    // Touches autres qu'Échap reçues par le panneau.
    signal keyPressed(var event)

    function close(): void {
        Qt.quit();
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: layerName
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Qt.alpha(Theme.colour("scrim"), 0.4)
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: popup.close()
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        implicitWidth: popup.panelWidth
        implicitHeight: body.implicitHeight + 48
        radius: 28
        color: Theme.colour("surface")
        opacity: 0
        scale: 0.95
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                popup.close();
            } else {
                popup.keyPressed(event);
            }
        }

        // Avale les clics pour qu'ils n'atteignent pas le scrim.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: body

            anchors.fill: parent
            anchors.margins: 24
            spacing: 12
        }
    }

    ParallelAnimation {
        running: true

        NumberAnimation {
            target: scrim
            property: "opacity"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "opacity"
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
}
