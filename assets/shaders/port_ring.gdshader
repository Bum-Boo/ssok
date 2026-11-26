shader_type spatial;

// Free-hole rings and the snap target. Each instance color carries the semantic tint; an opaque
// instance color marks the current snap target, which gets a crisp white core edge and a slow
// halo pulse. WebGL2-safe: unshaded alpha blend over MultiMesh instance colors.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Ring band radii in the mesh's radial UV (0 inner edge of halo, 1 outer edge of halo).
uniform float core_inner = 0.22;
uniform float core_outer = 0.62;


void fragment() {
	float radial = UV.x;
	float target = step(0.95, COLOR.a);
	float aa = max(fwidth(radial) * 1.2, 0.002);
	float core = smoothstep(core_inner - aa, core_inner + aa, radial) * (1.0 - smoothstep(core_outer - aa, core_outer + aa, radial));
	float outer = 1.0 - smoothstep(core_outer, 1.0, radial);
	float inner = smoothstep(0.0, core_inner, radial);
	float halo = min(outer, inner) * (1.0 - core);
	float pulse = 0.55 + 0.45 * sin(TIME * 5.5);
	float rim = target * smoothstep(core_outer - 0.12 - aa, core_outer - 0.12 + aa, radial) * (1.0 - smoothstep(core_outer - aa, core_outer + aa, radial));
	ALBEDO = mix(COLOR.rgb, vec3(1.0), rim * 0.65);
	ALPHA = clamp(core * mix(COLOR.a, 1.0, target) + halo * mix(0.12, 0.5 * pulse, target), 0.0, 1.0);
}
