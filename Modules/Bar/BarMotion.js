.pragma library

// Geometry shared by the desktop bar and any surface that enters as its
// floating continuation. Hidden retains the visible shape and moves it far
// enough above the output to clear both the surface and its complete shadow.
var shadowBuffer = 24;
var hiddenClearance = 8;

function hiddenOffset(margin, height) {
    return -(margin + height + shadowBuffer + hiddenClearance);
}
