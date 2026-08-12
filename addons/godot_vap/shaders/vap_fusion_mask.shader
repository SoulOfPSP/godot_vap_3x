shader_type canvas_item;
render_mode unshaded;

uniform sampler2D mask_texture;
uniform vec4 mask_region;
uniform int mask_rotation = 0;
uniform bool use_fill = false;
uniform vec4 fill_color : hint_color = vec4(1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec2 mask_local_uv = UV;
	if (mask_rotation == 90) {
		mask_local_uv = vec2(UV.y, 1.0 - UV.x);
	}
	vec2 mask_uv = mask_region.xy + mask_local_uv * mask_region.zw;
	float mask_alpha = texture(mask_texture, mask_uv).r;
	vec3 output_rgb = use_fill ? fill_color.rgb : source.rgb;
	float output_alpha = source.a * (use_fill ? fill_color.a : 1.0) * clamp(mask_alpha, 0.0, 1.0);
	COLOR = vec4(output_rgb, output_alpha);
}
