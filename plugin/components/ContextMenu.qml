pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import qs.Common
import qs.DCommon.Common as DCommon
import qs.DCommon.Widgets

// a small menu styled like dux's own, drawn inside the popout's window rather than a menu window
// of its own, which could drop the click that opens it
Controls.Popup {
    id: menu

    // {icon, text, action, tone}; tone "error" or "success" colours it like dux's own
    property var entries: []
    readonly property real rowHeight: DCommon.Style.menuRowHeight
    readonly property real iconSize: DCommon.Style.menuItemIconSize

    // at x, y in item's coordinates
    function openAt(item, x, y, list) {
        entries = list;
        parent = item;
        menu.x = x;
        menu.y = y;
        open();
    }

    padding: DCommon.Style.menuPadding
    margins: Theme.spacingS
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside

    background: Rectangle {
        color: Theme.readableSurface
        radius: Theme.windowRadius

        ElevationShadow {
            anchors.fill: parent
            z: -1
            level: Theme.elevationLevel2
            targetRadius: parent.radius
            targetColor: "transparent"
            shadowEnabled: Theme.elevationEnabled
        }
    }

    contentItem: Column {
        spacing: Theme.groupedListGap

        Repeater {
            model: menu.entries

            Rectangle {
                id: row

                required property var modelData
                readonly property string tone: modelData.tone ?? ""
                readonly property color contentColor: tone === "error" ? Theme.error : tone === "success" ? Theme.success : Theme.onSurface

                width: Math.max(Theme.fieldDefaultWidth * 0.6, content.implicitWidth + Theme.spacingS * 2)
                height: menu.rowHeight
                radius: Theme.cornerRadiusS
                color: hit.pressed ? Theme.withAlpha(contentColor, Theme.stateLayerPressed) : hit.containsMouse ? Theme.withAlpha(contentColor, Theme.stateLayerHover) : "transparent"

                Row {
                    id: content

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon ?? ""
                        size: menu.iconSize
                        color: row.contentColor
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: row.contentColor
                    }
                }

                MouseArea {
                    id: hit

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menu.close();
                        row.modelData.action?.();
                    }
                }
            }
        }
    }
}
