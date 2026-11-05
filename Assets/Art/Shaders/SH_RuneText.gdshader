shader_type canvas_item;

// Put this on BOTH description labels (readable text + rune text), with is_rune_layer
// set on the rune one. Tweening `reveal` from 0 to 1 dissolves the runes into the text.

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform bool is_rune_layer = false;

// ---------- Dissolve ----------
uniform float sweep_width = 86.0;                       // width of the text area, in card pixels
uniform float noise_amount : hint_range(0.0, 1.0) = 0.45; // 0 = clean left-to-right wipe, 1 = pure noise
uniform float block_size = 2.0;                         // dissolve block size, in card pixels

// ---------- Rune look (rune layer only) ----------
uniform vec4 shimmer_color : source_color = vec4(0.45, 0.85, 0.95, 1.0);
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.6;
uniform float shimmer_speed = 1.5;
uniform float shimmer_scale = 0.25;

varying vec2 local_pos;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    vec2 block = floor(local_pos / block_size);
    float sweep = clamp(local_pos.x / sweep_width, 0.0, 1.0);
    float threshold = mix(sweep, hash(block), noise_amount);
    // Scaled so reveal 0 hides every pixel and reveal 1 shows every pixel.
    bool revealed = threshold < reveal * 1.01 - 0.005;

    if (is_rune_layer) {
        COLOR.a *= revealed ? 0.0 : 1.0;
        float wave = 0.5 + 0.5 * sin(TIME * shimmer_speed + (local_pos.x + local_pos.y) * shimmer_scale);
        COLOR.rgb = mix(COLOR.rgb, shimmer_color.rgb, wave * shimmer_strength);
    } else {
        COLOR.a *= revealed ? 1.0 : 0.0;
    }
}
