shader_type canvas_item;

varying vec2 map_point;

void vertex() {
    map_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // 根尖间露出原位置的地表，树冠和枝干仍使用原画。
    float blades = pow(0.5 + 0.5 * sin(map_point.x * 0.63 + sin(map_point.x * 0.27)), 2.0);
    COLOR.a *= 1.0 - smoothstep(0.942, 0.992, UV.y) * mix(0.54, 0.95, blades);
}
