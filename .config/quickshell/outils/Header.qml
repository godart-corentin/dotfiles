import QtQuick
import QtQuick.Layouts

RowLayout {
    id: header

    property string icon
    property string title
    property string subtitle

    Layout.bottomMargin: 4
    spacing: 14

    IconBadge {
        icon: header.icon
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Label {
            Layout.fillWidth: true
            text: header.title
            font.pointSize: 15
            font.weight: Font.Medium
        }

        Label {
            Layout.fillWidth: true
            text: header.subtitle
            color: Theme.colour("onSurfaceVariant")
            font.pointSize: 10
        }
    }
}
