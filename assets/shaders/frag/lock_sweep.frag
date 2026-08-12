// ===== lock_sweep.frag =====
// The lock/unlock sweep: the lock scene with a circular hole punched in it,
// centred on the avatar.
//
// The prototype clips the DESKTOP to a circle and rides it above the lock
// scene. Under Wayland nothing can be composited beneath a session-lock
// surface, so the sweep runs on an ordinary layer-shell surface above the
// desktop instead, and the hole is what lets the real desktop through. The
// visible result is the same gesture: a circle of desktop, centred on the
// avatar, over a lock scene that never moves.
//
// A hole and not a mask on purpose — the alpha this writes is what the
// compositor blends against the desktop, so the circle is genuinely empty
// rather than painted with something desktop-coloured.
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D scene;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 centre;    // the avatar's resting centre, in normalized coordinates
    float radius;   // the hole's radius, in units of surface WIDTH
    float aspect;   // height / width, so the hole stays a circle
    float feather;  // antialiasing width, same units as radius
} ubuf;

void main() {
    vec2 offset = qt_TexCoord0 - ubuf.centre;
    // Measure in width units: y is scaled by the aspect ratio so a circle in
    // pixels stays a circle in this space whatever shape the output is.
    offset.y *= ubuf.aspect;
    float distance = length(offset);

    // 1 outside the hole, 0 inside it.
    float keep = smoothstep(ubuf.radius - ubuf.feather, ubuf.radius + ubuf.feather, distance);

    // The scene arrives premultiplied, so scaling the whole vec4 keeps it that
    // way and leaves a genuinely transparent hole.
    fragColor = texture(scene, qt_TexCoord0) * keep * ubuf.qt_Opacity;
}
