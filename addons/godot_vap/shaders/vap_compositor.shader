shader_type canvas_item;
render_mode unshaded;

uniform vec4 rgb_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 alpha_region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec2 rgb_uv = rgb_region.xy + UV * rgb_region.zw;
	vec2 alpha_uv = alpha_region.xy + UV * alpha_region.zw;
	vec3 rgb = texture(TEXTURE, rgb_uv).rgb;
	float alpha = texture(TEXTURE, alpha_uv).r;
	COLOR = vec4(rgb, alpha) * COLOR;
}
