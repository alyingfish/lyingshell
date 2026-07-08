// Pure tray-icon classification. No QML/Quickshell types so it stays testable.
.pragma library

// Should this icon be recolored to the theme foreground?
//
// Freedesktop "*-symbolic" icons are the ones apps ship *expecting* the panel
// to tint them; recoloring anything else destroys brand logos (fcitx Rime went
// from a red seal to an unreadable blob). Quickshell hands named icons back as
//   image://icon/<name>[?path=..][?fallback=..]
// and raw pixmap logos as image://qsimage/.. with no name, so the name — and
// its "-symbolic" suffix — is only present for the recolorable case.
function isSymbolicIcon(iconUrl) {
    const url = String(iconUrl || "");
    const prefix = "image://icon/";
    if (!url.startsWith(prefix))
        return false; // raw pixmap logo → keep colors
    const name = url.slice(prefix.length).split("?")[0];
    return name.toLowerCase().endsWith("-symbolic");
}
