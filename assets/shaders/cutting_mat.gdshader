shader_type spatial;

// Procedural cutting mat for the GL Compatibility (WebGL2) renderer: 1 cm and 5 cm lines, a ruler
// band with ticks along the edge and a soft fade where the grid meets the band. Lines are
// filtered against their own screen-space footprint, so distant cells fade to the mat tone
// instead of producing moire. Lit by the scene, so parts still cast contact shadows on it.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 mat_color : source_color = vec4(0.53, 0.60, 0.56, 1.0);
uniform vec4 band_color : source_color = vec4(0.47, 0.54, 0.50, 1.0);
uniform vec4 side_color : source_color = vec4(0.36, 0.41, 0.38, 1.0);
uniform vec4 minor_color : source_color = vec4(0.70, 0.76, 0.72, 1.0);
uniform vec4 major_color : source_color = vec4(0.84, 0.88, 0.85, 1.0);
uniform float minor_strength : hint_range(0.0, 1.0) = 0.45;
uniform float major_strength : hint_range(0.0, 1.0) = 0.75;
uniform float mottle : hint_range(0.0, 0.2) = 0.035;
uniform float mat_roughness : hint_range(0.0, 1.0) = 0.86;
uniform vec2 mat_center = vec2(0.25, 0.0);
uniform vec2 mat_half_size = vec2(0.9, 0.7);
uniform float band_width = 0.04;
uniform float fade_width = 0.06;

varying vec3 world_position;
varying vec3 world_normal;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


// Ben Golus' "pristine grid" idea, rewritten with spec-ordered smoothstep edges for WebGL2.
// coordinate is in cells; width is the full line width as a fraction of a cell.
vec2 filtered_lines(vec2 coordinate, float width) {
	vec2 derivative = vec2(length(vec2(dFdx(coordinate.x), dFdy(coordinate.x))), length(vec2(dFdx(coordinate.y), dFdy(coordinate.y))));
	vec2 draw_width = clamp(vec2(width), derivative, vec2(0.5));
	vec2 smoothing = derivative * 1.5;
	vec2 distance_to_line = 1.0 - abs(fract(coordinate) * 2.0 - 1.0);
	vec2 lines = 1.0 - smoothstep(draw_width - smoothing, draw_width + smoothing, distance_to_line);
	lines *= clamp(vec2(width) / draw_width, 0.0, 1.0);
	// Once a cell covers only a few pixels, settle on its average coverage instead of aliasing.
	return mix(lines, vec2(width), clamp(derivative * 2.0 - 1.0, 0.0, 1.0));
}


float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local = fract(position);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}


void fragment() {
	vec2 local = world_position.xz - mat_center;
	vec2 to_edge = mat_half_size - abs(local);
	float inset = min(to_edge.x, to_edge.y);

	// Grid inside the band; each line set fades out toward the band.
	vec2 minor_pair = filtered_lines(world_position.xz / 0.01, 0.045);
	vec2 major_pair = filtered_lines(world_position.xz / 0.05, 0.022);
	float minor = max(minor_pair.x, minor_pair.y);
	float major = max(major_pair.x, major_pair.y);
	float grid_mask = smoothstep(band_width, band_width + fade_width, inset);

	// Ruler ticks along each side of the band: 1 cm short, 5 cm medium, 10 cm long.
	vec2 tick_minor = filtered_lines(world_position.xz / 0.01, 0.06);
	vec2 tick_five = filtered_lines(world_position.xz / 0.05, 0.016);
	vec2 tick_ten = filtered_lines(world_position.xz / 0.10, 0.009);
	vec2 depth = band_width - to_edge.yx;
	vec2 inside_band = step(0.0, depth) * step(depth, vec2(band_width)) * step(vec2(band_width), to_edge.xy);
	vec2 ticks = tick_minor * step(depth, vec2(band_width * 0.22));
	ticks = max(ticks, tick_five * step(depth, vec2(band_width * 0.42)));
	ticks = max(ticks, tick_ten * step(depth, vec2(band_width * 0.62)));
	ticks *= inside_band;
	float tick = max(ticks.x, ticks.y);
	float band = 1.0 - step(band_width, inset);

	vec3 base = mix(mat_color.rgb, band_color.rgb, band);
	// Broad, low-contrast mottling so the vinyl does not read as a flat CG plane.
	base *= 1.0 + (value_noise(world_position.xz * 9.0) - 0.5) * 2.0 * mottle;
	vec3 surface = mix(base, minor_color.rgb, minor * minor_strength * grid_mask);
	surface = mix(surface, major_color.rgb, major * major_strength * grid_mask);
	surface = mix(surface, major_color.rgb, tick * major_strength);

	float top = smoothstep(0.5, 0.8, world_normal.y);
	ALBEDO = mix(side_color.rgb, surface, top);
	ROUGHNESS = mat_roughness;
	// Self-healing vinyl is matte; a low specular keeps grazing lamps from washing it out.
	SPECULAR = 0.15;
}
