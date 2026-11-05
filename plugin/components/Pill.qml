import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets

// the bar pill: speaker and mic icons with their volumes; the wheel over either half sets that one
Item {
    id: pill

    // the widget, for its settings, levels and actions
    required property var widget
    property bool vertical: false

    readonly property color speakerIconColor: widget.sinkMuted ? Theme.surfaceVariantText : widget.themeColorFromKey(widget.speakerIconColorKey, Theme.primary)
    readonly property color speakerTextColor: widget.sinkMuted ? Theme.surfaceVariantText : widget.themeColorFromKey(widget.speakerTextColorKey, Theme.surfaceText)
    readonly property color micIconColor: widget.sourceMuted ? Theme.surfaceVariantText : widget.themeColorFromKey(widget.micIconColorKey, Theme.primary)
    readonly property color micTextColor: widget.sourceMuted ? Theme.surfaceVariantText : widget.themeColorFromKey(widget.micTextColorKey, Theme.surfaceText)

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    Grid {
        id: grid

        columns: pill.vertical ? 1 : 5
        spacing: Theme.spacingXS
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        DIcon {
            name: AudioService.volumeIconName(pill.widget.sink)
            size: pill.widget.iconSize
            color: pill.speakerIconColor
            visible: pill.widget.showSpeaker
        }

        StyledText {
            text: pill.widget.sinkVolume
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: pill.speakerTextColor
            visible: pill.widget.showSpeaker && pill.widget.showSpeakerValue
        }

        DIcon {
            name: pill.widget.sourceMuted ? "mic_off" : "mic"
            size: pill.widget.iconSize
            color: pill.micIconColor
            visible: pill.widget.showMic
        }

        StyledText {
            text: pill.widget.sourceVolume
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: pill.micTextColor
            visible: pill.widget.showMic && pill.widget.showMicValue
        }

        // a little end spacing in a horizontal bar
        Item {
            width: 0.09
            height: 1
            visible: !pill.vertical
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const secondHalf = pill.vertical ? wheel.y > height / 2 : wheel.x > width / 2;
            pill.widget.wheelOver(pill.widget.showMic && (!pill.widget.showSpeaker || secondHalf), wheel.angleDelta.y > 0);
        }
    }
}
