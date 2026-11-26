// Additive glow sprite for player bullets and effects, drawn through a MultiMesh.
// INSTANCE_CUSTOM = (kind, fade, velocity.x, velocity.y). The quad is oriented and
// stretched along the velocity here, so the CPU only uploads position and velocity.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform vec4 colors[32];   // rgb premultiplied by intensity
uniform vec4 shapes[32];   // x = width, y = length, z = white core radius (0..1)
uniform float lag = 0.0;   // seconds to step back along the velocity (render interpolation)

varying vec3 v_col;
varying float v_core;
varying float v_fade;

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
	v_fade = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 2.0);
	float core = smoothstep(v_core, v_core * 0.3, d);
	ALBEDO = (v_col * glow + vec3(core)) * v_fade;
}
