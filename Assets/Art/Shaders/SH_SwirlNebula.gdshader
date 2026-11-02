shader_type canvas_item;

// ---------- Look ----------
uniform float speed = 0.1;                      // fbm drift speed
uniform float pixelation = 6.0;                 // pixel block size
uniform float zoom = 2.0;                       // fbm scale
uniform float paint_mix : hint_range(0.0, 1.0) = 0.5; // 0 = pure fbm, 1 = pure paint

// ---------- Swirl ----------
uniform float spin_speed = 0.065;
uniform float spin_amount : hint_range(0.0, 2.0) = 1.05;
uniform float swirl_strength = 10.0;            // 0 = no swirl
uniform vec2 swirl_center = vec2(-0.12, 0.0);

// ---------- Paint loop ----------
uniform float paint_scale = 30.0;
uniform float paint_speed = 2.0;
uniform float contrast = 1.0;

// ---------- Colours (low -> mid -> high, all three always visible) ----------
uniform vec4 color_1 : source_color = vec4(0.0, 0.4, 0.9, 1.0);
uniform vec4 color_2 : source_color = vec4(1.0, 0.0, 0.2, 1.0);
uniform vec4 color_3 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ---------- Fixed internals (not exposed) ----------
const float STEPS = 5.0;        // posterize steps per colour transition
const float SHADE_MIN = 0.12;   // raw values below this -> pure color_1
const float SHADE_MAX = 0.62;   // raw values above this -> pure color_3
const mat2 mtx = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));

float rand(vec2 n) {
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 ip = floor(p);
    vec2 u = fract(p);
    u = u * u * (3.0 - 2.0 * u);
    float res = mix(
        mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
        mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x), u.y);
    return res * res;
}

float fbm(vec2 p, float t) {
    float f = 0.0;
    f += 0.500000 * noise(p + t); p = mtx * p * 2.02;
    f += 0.031250 * noise(p);     p = mtx * p * 2.01;
    f += 0.250000 * noise(p);     p = mtx * p * 2.03;
    f += 0.125000 * noise(p);     p = mtx * p * 2.01;
    f += 0.062500 * noise(p);     p = mtx * p * 2.04;
    f += 0.015625 * noise(p + sin(t));
    return f / 0.96875;
}

float pattern(vec2 p, float t) {
    return fbm(p + fbm(p + fbm(p, t), t), t);
}

float paint(vec2 uv, float t) {
    uv *= paint_scale;
    float spd = t * paint_speed;
    vec2 uv2 = vec2(uv.x + uv.y);
    for (int i = 0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv += 0.5 * vec2(
            cos(5.1123314 + 0.353 * uv2.y + spd * 0.131121),
            sin(uv2.x - 0.113 * spd));
        uv -= cos(uv.x + uv.y) - sin(uv.x * 0.711 - uv.y);
    }
    float contrast_mod = 0.25 * contrast + 0.5 * spin_amount + 1.2;
    return length(uv) * 0.02 * contrast_mod * 0.5;
}

float posterize(float k) {
    return round(clamp(k, 0.0, 1.0) * STEPS) / STEPS;
}

// x in 0..1 -> opaque colour, first half color_1->color_2, second half color_2->color_3
vec4 colormap(float x) {
    if (x < 0.5) {
        return mix(color_1, color_2, posterize(x * 2.0));
    }
    return mix(color_2, color_3, posterize((x - 0.5) * 2.0));
}

void fragment() {
    vec2 res = 1.0 / SCREEN_PIXEL_SIZE;

    // Pixelated UV covering the whole node (0..1)
    vec2 uv = floor(UV / SCREEN_PIXEL_SIZE / pixelation) * SCREEN_PIXEL_SIZE * pixelation;

    // Centered, aspect-corrected coordinates
    vec2 p = uv - 0.5;
    p.x *= res.x / res.y;
    p -= swirl_center;
    float r = length(p);

    // Swirl
    float a = atan(p.y, p.x)
            + TIME * spin_speed
            - swirl_strength * (spin_amount * r + (1.0 - spin_amount));
    vec2 sw = vec2(cos(a), sin(a)) * r;

    // Both fields on the same swirled coordinates
    float f_fbm = pattern(sw * zoom + 5.0, TIME * speed);
    float f_paint = paint(sw, TIME);
    float shade = mix(f_fbm, f_paint, paint_mix);

    // Stretch to the full 0..1 range so every colour gets used
    shade = smoothstep(SHADE_MIN, SHADE_MAX, shade);

    COLOR = vec4(colormap(shade).rgb, 1.0);
}
