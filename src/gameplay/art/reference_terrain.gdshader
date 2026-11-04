shader_type canvas_item;
render_mode unshaded;
#include "res://src/gameplay/art/reference_ground.gdshaderinc"
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
    vec4 base=texture(TEXTURE,UV);
    vec3 color=ground_color(base.rgb);
    // 原水面已有波纹。停用会把蓝色岩壁误判为水面的二次覆盖。
    COLOR=vec4(color,base.a);
}
