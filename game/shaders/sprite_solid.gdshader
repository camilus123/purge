// Solid sprite for enemy bullets: bright fill, white core and a dark rim so the
// shape stays readable on any background. Same instance layout as sprite_add.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform vec4 colors[32];
uniform vec4 shapes[32];
uniform float lag = 0.0;

varying vec3 v_col;
varying float v_core;

void vertex() {
	int k = int(INSTANCE_CUSTOM.x + 0.5);
	vec4 sh = shapes[k];
	vec2 vel = INSTANCE_CUSTOM.zw;
	float sp = length(vel);
	vec2 d = sp > 0.001 ? vel / sp : vec2(0.0, -1.0);
	vec2 perp = vec2(d.y, -d.x);
	vec2 w = perp * (VERTEX.x * sh.x) + d * (VERTEX.z * sh.y) - vel * lag;
	VERTEX = vec3(w.x, 0.0, w.y);
	v_col = colors[k].rgb;
	v_core = sh.z;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float core = smoothstep(v_core, v_core * 0.4, d);
	float rim = smoothstep(0.66, 0.8, d);
	vec3 c = mix(v_col, vec3(1.8), core);
	c = mix(c, vec3(0.03, 0.0, 0.04), rim);
	ALBEDO = c;
	ALPHA = smoothstep(1.0, 0.9, d);
}
