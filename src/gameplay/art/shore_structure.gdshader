shader_type canvas_item;
render_mode unshaded;
uniform sampler2D shore_art : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D water_control : filter_linear, repeat_disable;
uniform vec2 control_origin=vec2(0);
uniform vec2 control_size=vec2(7056,2880);
varying vec4 vertex_tint;
varying vec2 world_position;
void vertex() {
    vertex_tint=COLOR;
    world_position=VERTEX;
}
void fragment() {
    vec4 art=texture(shore_art,UV)*vertex_tint;
    float wet=texture(water_control,(world_position-control_origin)/control_size).r;
    // 固定俯视石块保持光照朝向；蓝水只落在真实水面，顶草只落在陆地。
    art.a*=1.0-smoothstep(.62,.85,UV.y)*(1.0-wet);
    art.a*=1.0-(1.0-smoothstep(.12,.40,UV.y))*wet;
    COLOR=art;
}
