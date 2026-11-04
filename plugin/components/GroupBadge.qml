import QtQuick
import qs.Common
import qs.DCommon.Widgets

// a mixer group's chip: icon, name and current factor, in its vertex's container tone
Rectangle {
    id: badge

    property int tone: 0
    property string icon: ""
    property string name: ""
    property real factor: 1
    property bool showFactor: true

    readonly property color contentColor: [Theme.onPrimaryContainer, Theme.onTertiaryContainer, Theme.onSecondaryContainer][tone % 3]

    implicitWidth: content.implicitWidth + Theme.spacingS * 2
    implicitHeight: Theme.iconSizeSmall + Theme.spacingXS * 2
    radius: height / 2
    color: [Theme.primaryContainer, Theme.tertiaryContainer, Theme.secondaryContainer][tone % 3]

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: badge.icon
            size: Theme.iconSizeSmall
            color: badge.contentColor
            visible: badge.icon !== ""
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
            text: Math.round(badge.factor * 100) + "%"
            font.pixelSize: Theme.fontSizeSmall
            color: badge.contentColor
            opacity: 0.8
            wrapMode: Text.NoWrap
            visible: badge.showFactor
        }
    }
}
