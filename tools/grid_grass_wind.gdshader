shader_type canvas_item;
render_mode unshaded;

// 只变形透明草叶，网格、底土和每株根部不参与位移。
uniform float wind_clock = 0.0;
uniform float wind_strength = 1.0;
uniform vec3 grass_color = vec3(0.235, 0.345, 0.275);

void vertex() {
    vec2 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
    float phase = dot(root, vec2(0.015, 0.005));
    float gust = 0.7 + 0.3 * sin(wind_clock * 0.55 - dot(root, vec2(0.006, 0.002)));
    float bend = sin(phase - wind_clock * 1.9) * 0.7 + sin(phase * 1.7 - wind_clock * 2.7) * 0.15;
    float tip = pow(clamp((0.96 - UV.y) / 0.62, 0.0, 1.0), 1.4);
    VERTEX += vec2(0.94, 0.34) * bend * gust * tip * wind_strength;
}

void fragment() {
    vec4 leaf = texture(TEXTURE, UV);
    float value = dot(leaf.rgb, vec3(0.25, 0.55, 0.20));
    // 蓝色原稿映射到设计图的灰绿叶片，保留原生叶形和透明边缘。
    vec3 color = grass_color * 0.64 + vec3(0.29, 0.35, 0.20) * value;
    COLOR = vec4(color, leaf.a);
}
