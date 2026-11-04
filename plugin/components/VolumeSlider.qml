import QtQuick
import qs.Common
import qs.DCommon.Widgets

// a volume in percent; follows level unless it's being dragged
DSlider {
    id: slider

    property int level: 0
    property bool muted: false

    size: "s"
    minimum: 0
    showValue: false
    fillColor: muted ? Theme.surfaceVariantText : Theme.primary

    Binding {
        target: slider
        property: "value"
        value: Math.min(slider.maximum, slider.level)
        when: !slider.isDragging
        restoreMode: Binding.RestoreNone
    }
}
