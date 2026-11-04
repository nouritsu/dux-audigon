import QtQuick
import qs.Common
import qs.DCommon.Widgets

// a group's heading, as in dux's settings and control center
StyledText {
    width: parent?.width ?? 0
    leftPadding: Theme.spacingS
    topPadding: Theme.spacingS
    bottomPadding: Theme.spacingXS
    font.pixelSize: Theme.fontSizeMedium
    font.weight: Theme.fontWeightMedium
    color: Theme.primary
    elide: Text.ElideRight
}
