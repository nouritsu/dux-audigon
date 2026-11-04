import QtQuick
import qs.Common
import qs.DCommon.Widgets

// a mixer group's chip: icon, name and current factor, in its vertex's container tone;
// greyed with a muted icon while its group is muted, and right-click toggles that
Rectangle {
    id: badge

    property int tone: 0
    property string icon: ""
    property string name: ""
    property real factor: 1
    property bool showFactor: true
    property bool muted: false
    property bool muteable: false

    signal muteToggled

    readonly property color contentColor: muted ? Theme.surfaceVariantText : [Theme.onPrimaryContainer, Theme.onTertiaryContainer, Theme.onSecondaryContainer][tone % 3]

    implicitWidth: content.implicitWidth + Theme.spacingS * 2
    implicitHeight: Theme.iconSizeSmall + Theme.spacingXS * 2
    radius: height / 2
    color: muted ? Theme.surfaceContainerHighest : [Theme.primaryContainer, Theme.tertiaryContainer, Theme.secondaryContainer][tone % 3]

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: badge.muted ? "volume_off" : badge.icon
            size: Theme.iconSizeSmall
            color: badge.contentColor
            visible: name !== ""
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: badge.name
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: badge.contentColor
            wrapMode: Text.NoWrap
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: badge.muted ? "Muted" : Math.round(badge.factor * 100) + "%"
            font.pixelSize: Theme.fontSizeSmall
            color: badge.contentColor
            opacity: 0.8
            wrapMode: Text.NoWrap
            visible: badge.showFactor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: badge.muteable
        acceptedButtons: Qt.RightButton
        onClicked: badge.muteToggled()
    }
}
