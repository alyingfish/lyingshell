// ===== lock_desk.frag =====
// The entry sweep, drawn on the lock surface itself: the desktop still
// clipped to the shrinking circle, riding above a lock scene that never
// moves. The inverse of lock_sweep.frag, which cuts a hole instead.
//
// The inversion is the safety: everything this draws is ON TOP of the real
// scene, so every failure mode — a still that never decoded, a lost grab, a
// texture that samples empty — resolves to transparency and shows the scene,
// a plain cut. A hole-cutting composite would resolve the same failures to a
// black circle over the whole surface.
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D still;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 centre;    // the avatar's resting centre, in normalized coordinates
    float radius;   // the circle's radius, in units of surface WIDTH
    float aspect;   // height / width, so the circle stays a circle
    float feather;  // antialiasing width, same units as radius
} ubuf;

void main() {
    vec2 offset = qt_TexCoord0 - ubuf.centre;
    // Measure in width units: y is scaled by the aspect ratio so a circle in
    // pixels stays a circle in this space whatever shape the output is.
    offset.y *= ubuf.aspect;
    float distance = length(offset);

    // 1 inside the circle, 0 outside it.
    float keep = 1.0 - smoothstep(ubuf.radius - ubuf.feather, ubuf.radius + ubuf.feather, distance);

    // The still arrives premultiplied, so scaling the whole vec4 keeps it
    // that way and leaves everything outside the circle genuinely
    // transparent.
    fragColor = texture(still, qt_TexCoord0) * keep * ubuf.qt_Opacity;
}
