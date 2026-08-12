// ===== lock_scallop.frag =====
// The lock screen's avatar: whatever is painted into `source` — a portrait, or
// the tonal plate that stands in for one — clipped by a twelve-lobe scallop
// that turns slowly, Material's turning-shape motif.
//
// THE MASK TURNS, NOT THE PICTURE. `turn` rotates the angle the edge is
// evaluated at and nothing else, so the scalloped rim travels while the face
// underneath never moves. The prototype counter-spins its <img> against a
// spinning clipped frame because a CSS clip-path is applied in the element's
// own coordinates; that counter-turn is a workaround for the CSS model and is
// deliberately not ported.
//
// One curve underneath everything: a sine ridden around a circle, normalized so
// the crests always land on the SAME radius whatever the amplitude — so `amp`
// can be morphed to 0 and the lobes breathe flat into a circle of the same
// size, rather than the shape growing. That is the success step.
//
// That radius is 0.46 of the box, not 0.5: the prototype's SCALLOP_R is 46 in
// a 100-unit box (src/lock/stage/shapes.js), so the shape is inset from the
// slot it is laid out in and the disc reads 92% of the avatar's box.
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float lobes;    // crest count (12)
    float amp;      // 0.10 scallop .. 0.0 circle
    float turn;     // radians; the mask's rotation
    float feather;  // antialiasing width, in normalized radius units
} ubuf;

const float HALF_PI = 1.5707963267948966;
// The prototype's SCALLOP_R (46) over its 100-unit box.
const float CREST = 0.46;

void main() {
    vec2 centred = qt_TexCoord0 - vec2(0.5);
    float radius = length(centred);
    float angle = atan(centred.y, centred.x) - ubuf.turn;

    // Crests on CREST, troughs on CREST*(1-amp)/(1+amp).
    float edge = CREST * (1.0 + ubuf.amp * sin(angle * ubuf.lobes + HALF_PI)) / (1.0 + ubuf.amp);
    float alpha = 1.0 - smoothstep(edge - ubuf.feather, edge + ubuf.feather, radius);

    // The source arrives premultiplied, so one multiply keeps it that way.
    fragColor = texture(source, qt_TexCoord0) * alpha * ubuf.qt_Opacity;
}
