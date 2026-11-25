shader_type spatial;

// Additive halo around a lit LED lens: a camera-facing quad, no post-processing glow needed.
// WebGL2-safe: unshaded, additive, no depth writes, no screen textures.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.32, 0.08, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 0.0;
// Pulls the quad toward the camera so the lens body never clips the halo.
uniform float lift = 0.006;


void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 toward_camera = normalize(CAMERA_POSITION_WORLD - center);
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz) * length(MODEL_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz) * length(MODEL_MATRIX[1].xyz);
	vec3 world = center + toward_camera * lift + right * VERTEX.x + up * VERTEX.y;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}


void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float halo = pow(clamp(1.0 - radius, 0.0, 1.0), 2.2);
	float core = smoothstep(0.32, 0.0, radius);
	vec3 color = glow_color.rgb * halo * 0.9 + mix(glow_color.rgb, vec3(1.0, 0.92, 0.82), 0.6) * core * 0.8;
	ALBEDO = color * intensity;
}
