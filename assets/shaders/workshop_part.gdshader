shader_type spatial;

// Part surfaces for the GL Compatibility (WebGL2) renderer. Direct lights and shadows come from
// Godot; the ambient term is replaced by a small studio hemisphere so that metal reflects a lit
// workshop instead of the background. Without it, metallic parts lose their diffuse light and
// fall almost black whenever the scene has little sky to reflect (dark theme, Web).
// Kept to plain arithmetic and three texture reads: no derivatives, loops or screen textures.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale = 0.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

// Studio hemisphere, set per theme by WorkshopMaterials.
uniform vec4 env_top : source_color = vec4(0.86, 0.89, 0.93, 1.0);
uniform vec4 env_horizon : source_color = vec4(0.70, 0.72, 0.74, 1.0);
uniform vec4 env_ground : source_color = vec4(0.30, 0.31, 0.30, 1.0);
uniform float env_diffuse = 0.5;
uniform float env_specular = 1.0;
// The kit's metal colours are authored dark; a miniature reads better with brighter aluminium.
uniform float metal_gain = 1.5;
// Near-black rubber and plastic still need a little albedo to show their form without GI.
uniform float albedo_floor = 0.03;
// Faint grazing sheen from the studio horizon, so dark parts keep a silhouette on dark ground.
uniform float sheen = 0.2;
// A soft lamp reflection keeps flat metal plates from reading as one grey value.
uniform vec3 lamp_direction = vec3(-0.45, 0.75, 0.48);
uniform vec4 lamp_color : source_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform float lamp_strength = 0.6;

varying vec3 triplanar_pos;
varying vec3 triplanar_weights;


void vertex() {
	// Object-space triplanar projection, identical to StandardMaterial3D's uv1_triplanar.
	vec3 axis = abs(NORMAL);
	TANGENT = normalize(vec3(0.0, 0.0, -1.0) * axis.x + vec3(1.0, 0.0, 0.0) * axis.y + vec3(1.0, 0.0, 0.0) * axis.z);
	BINORMAL = normalize(vec3(0.0, 1.0, 0.0) * axis.x + vec3(0.0, 0.0, -1.0) * axis.y + vec3(0.0, 1.0, 0.0) * axis.z);
	triplanar_weights = axis / max(dot(axis, vec3(1.0)), 0.0001);
	triplanar_pos = VERTEX * uv1_scale * vec3(1.0, -1.0, 1.0);
}


vec3 triplanar_normal(vec3 weights, vec3 position) {
	vec3 value = texture(texture_normal, position.xy).rgb * weights.z;
	value += texture(texture_normal, position.xz).rgb * weights.y;
	value += texture(texture_normal, position.zy * vec2(-1.0, 1.0)).rgb * weights.x;
	return value;
}


vec3 hemisphere(vec3 direction) {
	vec3 upper = mix(env_horizon.rgb, env_top.rgb, smoothstep(0.0, 0.8, direction.y));
	vec3 lower = mix(env_horizon.rgb, env_ground.rgb, smoothstep(0.0, 0.45, -direction.y));
	return direction.y >= 0.0 ? upper : lower;
}


// Karis' analytic fit of the split-sum environment BRDF (also used by Godot's mobile paths).
vec2 environment_brdf(float rough, float n_dot_v) {
	vec4 r = rough * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
	float a004 = min(r.x * r.x, exp2(-9.28 * n_dot_v)) * r.x + r.y;
	return vec2(-1.04, 1.04) * a004 + r.zw;
}


void fragment() {
	vec3 base = mix(max(albedo.rgb, vec3(albedo_floor)), min(albedo.rgb * metal_gain, vec3(0.92)), metallic);
	ALBEDO = base;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	NORMAL_MAP = triplanar_normal(triplanar_weights, triplanar_pos);
	NORMAL_MAP_DEPTH = normal_scale;

	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 reflected = reflect(-world_view, world_normal);
	float n_dot_v = clamp(dot(world_normal, world_view), 0.0001, 1.0);
	// Rougher surfaces see a wider, flatter slice of the hemisphere.
	vec3 lookup = normalize(mix(reflected, world_normal, roughness * roughness) + vec3(0.0, 0.0001, 0.0));
	vec3 average = (env_top.rgb + env_horizon.rgb * 2.0 + env_ground.rgb) * 0.25;
	vec3 environment = mix(hemisphere(lookup), average, roughness * 0.45);
	float lamp_width = mix(0.9, 0.35, roughness);
	float lamp = smoothstep(lamp_width, 1.0, dot(lookup, normalize(lamp_direction)));
	environment += lamp_color.rgb * lamp * lamp_strength * (1.0 - roughness * 0.7);

	vec3 f0 = mix(vec3(0.16 * specular * specular), base, metallic);
	vec2 brdf = environment_brdf(roughness, n_dot_v);
	vec3 reflection = environment * (f0 * brdf.x + brdf.y) * env_specular;
	vec3 diffuse = base * (1.0 - metallic) * hemisphere(world_normal) * env_diffuse;
	float grazing = 1.0 - n_dot_v;
	vec3 silhouette = env_horizon.rgb * sheen * grazing * grazing * grazing * grazing * (1.0 - metallic * 0.5);
	EMISSION = diffuse + reflection + silhouette + emission.rgb * emission_energy;
}
