shader_type canvas_item;
// 此固定素材的树冠为冷蓝色，带入的浅绿草地不属于前景层。
// 在显示层去掉草地的透明过渡，避免原多边形轮廓形成一圈浅色贴片。
uniform bool remove_ground = true;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float foreground = smoothstep(-0.004, 0.022, source.b - source.g);
	COLOR = vec4(source.rgb, source.a * (remove_ground ? foreground : 1.0));
}
