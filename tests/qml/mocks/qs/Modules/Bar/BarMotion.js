.pragma library
.import "../../../../../../Modules/Bar/BarMotion.js" as Production

// The real LockTray is reached through a test symlink, so its sibling-relative
// import resolves inside this mock tree. Forward the one production contract.
var shadowBuffer = Production.shadowBuffer;
var hiddenClearance = Production.hiddenClearance;

function hiddenOffset(margin, height) {
    return Production.hiddenOffset(margin, height);
}
