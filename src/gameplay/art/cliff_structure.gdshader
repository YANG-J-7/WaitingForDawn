shader_type canvas_item;
render_mode unshaded;
// 可见体积来自完整独立崖体，按上下轮廓配对；不把岩身重复成水平草台。
uniform sampler2D structure_art : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fine_art : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tall_body_art : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying float face_height;

void vertex() {
    face_height=COLOR.r*512.0;
    COLOR=vec4(1.0);
}

void fragment() {
    vec4 art=texture(structure_art,UV);
    // 原生岩面细节只轻混入连续结构内部，不能用平铺岩纹代替轮廓。
    vec3 fine=texture(fine_art,vec2(UV.x*540.0/156.0,UV.y*face_height/156.0)).rgb;
    float body=smoothstep(.25,.4,UV.y)*(1.0-smoothstep(.78,.92,UV.y));
    art.rgb*=1.0+(dot(fine,vec3(.333))-.3)*body*.18;
    vec4 native_body=texture(tall_body_art,vec2(UV.x*540.0/132.0,UV.y*face_height/172.0));
    art.rgb=mix(art.rgb,native_body.rgb*vec3(.86,.94,1.04),body*.88*native_body.a);
    COLOR=art;
}
