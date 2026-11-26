shader_type spatial;

// Ultrasonic sensing cone while the learner's program reads the sensor: a translucent cone,
// pulses travelling outward and a bright ring at the measured echo distance.
// WebGL2-safe: unshaded alpha blend, no depth writes, TIME-driven arithmetic only.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 beam_color : source_color = vec4(0.2, 0.78, 0.92, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
// 1 when the last reading saw an obstacle at the end of the cone.
uniform float echo = 0.0;
uniform float length_m = 0.5;
uniform float pulse_spacing = 0.06;
uniform float pulse_speed = 0.35;


void fragment() {
	// UV.y runs from the sensor (0) to the end of the cone (1); see SonarBeam.make_cone().
	float along = UV.y;
	float distance_m = along * length_m;
	float edge_on = 1.0 - abs(dot(NORMAL, VIEW));
	float body = mix(0.18, 0.55, edge_on * edge_on) * (1.0 - smoothstep(0.55, 1.0, along) * (1.0 - echo * 0.6));
	float phase = fract((distance_m - TIME * pulse_speed) / pulse_spacing);
	float pulse = smoothstep(0.78, 0.96, phase) * (1.0 - smoothstep(0.96, 1.0, phase));
	pulse *= 1.0 - smoothstep(0.7, 1.0, along) * (1.0 - echo);
	float hit = echo * smoothstep(0.93, 0.985, along);
	float start = smoothstep(0.0, 0.04, along);
	ALBEDO = mix(beam_color.rgb, vec3(1.0), hit * 0.5 + pulse * 0.25);
	ALPHA = clamp((body * 0.35 + pulse * 0.45 + hit * 0.8) * start * opacity, 0.0, 1.0);
}
