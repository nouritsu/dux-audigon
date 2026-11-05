.pragma library

// the theme colours the pill's icons and text can take, by their Theme property names
function keys() {
    return ["primary", "primaryText", "primaryContainer", "secondary", "surface", "surfaceText", "surfaceVariant", "surfaceVariantText", "surfaceTint", "background", "backgroundText", "outline", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "error", "warning", "info"];
}

// "surfaceContainerHigh" -> "Surface Container High"
function label(key) {
    return key.replace(/[A-Z]/g, " $&").replace(/^./, c => c.toUpperCase());
}
