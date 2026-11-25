shader_type spatial;

// Placement ghost: a translucent tint that keeps the part's shape readable with simple facing
// shade and a bright Fresnel edge, so a valid snap (accent) or a blocked one (error) reads at a
// glance against both mat themes. WebGL2-safe: unshaded alpha blend, no textures.
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.09, 0.43, 0.35, 1.0);
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.3;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.85;


void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = pow(1.0 - facing, 2.5);
	float shade = 0.7 + 0.3 * clamp(dot(NORMAL, normalize(vec3(-0.35, 0.8, 0.5))), 0.0, 1.0);
	ALBEDO = mix(tint.rgb * shade, mix(tint.rgb, vec3(1.0), 0.55), edge);
	ALPHA = mix(fill_alpha, edge_alpha, edge);
}
