import QtQuick
import qs.Common
import qs.DCommon.Widgets

// a mixer group's chip: icon, name and current factor in its colours; greyed with a muted icon while
// muted, crossed out while excluded; right-click asks for its menu
Rectangle {
    id: badge

    property string icon: ""
    property string name: ""
    property real factor: 1
    property bool showFactor: true
    property bool muted: false
    property bool excluded: false
    property bool menuEnabled: false
    // {container, content}
    property var style: ({})

    signal menuRequested(real x, real y)

    readonly property bool dimmed: muted || excluded
    readonly property color contentColor: dimmed ? Theme.surfaceVariantText : style.content ?? Theme.onPrimaryContainer

    implicitWidth: content.implicitWidth + Theme.spacingS * 2
    implicitHeight: Theme.iconSizeSmall + Theme.spacingXS * 2
    radius: height / 2
    color: dimmed ? Theme.surfaceContainerHighest : style.container ?? Theme.primaryContainer
    // fades with its factor, like the group's marker on the mixer
    opacity: dimmed ? 1 : 0.45 + 0.55 * Math.max(0, Math.min(1, factor))

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shorterDuration
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: badge.muted ? "volume_off" : badge.excluded ? "do_not_disturb_on" : badge.icon
            size: Theme.iconSizeSmall
            color: badge.contentColor
            visible: name !== ""
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: badge.name
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            font.strikeout: badge.excluded
            color: badge.contentColor
            wrapMode: Text.NoWrap
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: badge.excluded ? "Excluded" : badge.muted ? "Muted" : Math.round(badge.factor * 100) + "%"
            font.pixelSize: Theme.fontSizeSmall
            color: badge.contentColor
            opacity: 0.8
            wrapMode: Text.NoWrap
            visible: badge.showFactor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: badge.menuEnabled
        acceptedButtons: Qt.RightButton
        onClicked: mouse => badge.menuRequested(mouse.x, mouse.y)
    }
}
