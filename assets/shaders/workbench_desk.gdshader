shader_type spatial;

// Desk top under the cutting mat. It is lit and takes shadows, then dissolves into whatever
// background the theme draws, so the bench has no hard horizon line. WebGL2-safe: alpha blend
// only, drawn before other transparent effects through its material render priority.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 desk_color : source_color = vec4(0.78, 0.78, 0.76, 1.0);
uniform vec2 fade_center = vec2(0.25, 0.0);
uniform float fade_start = 1.2;
uniform float fade_end = 3.0;
uniform float desk_roughness : hint_range(0.0, 1.0) = 0.8;

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	float distance_from_mat = length(world_position.xz - fade_center);
	ALBEDO = desk_color.rgb;
	ROUGHNESS = desk_roughness;
	SPECULAR = 0.18;
	ALPHA = 1.0 - smoothstep(fade_start, fade_end, distance_from_mat);
}
