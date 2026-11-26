// Player shield bubble: a rim glow that brightens with charge and flashes when hit.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.25, 0.6, 1.0);
uniform float strength = 1.0;   // 0..1 shield charge
uniform float flash = 0.0;      // 0..1 recent hit

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	float pattern = 0.6 + 0.4 * sin(UV.x * 120.0) * sin(UV.y * 60.0 + TIME * 3.0);
	ALBEDO = tint * (f * pattern * strength * 0.9 + flash * (0.35 + f * 1.5));
}
