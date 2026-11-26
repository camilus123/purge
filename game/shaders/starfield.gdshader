// Scrolling procedural starfield and faint nebula on one large quad far below the playfield.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float scroll = 0.0;
uniform float nebula_strength = 1.0;
uniform vec3 nebula_a : source_color = vec3(0.05, 0.09, 0.22);
uniform vec3 nebula_b : source_color = vec3(0.16, 0.05, 0.2);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 star_layer(vec2 uv, float density, float speed, float size, float bright) {
	uv = uv * density;
	uv.y -= scroll * speed * density;
	vec2 id = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float h = hash(id);
	vec2 off = (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.7;
	float d = length(f - off);
	float s = smoothstep(size, 0.0, d) * step(0.9, h);
	float twinkle = 0.75 + 0.25 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.9, 0.75), hash(id + 1.7));
	return tint * s * bright * twinkle;
}

void fragment() {
	// UV 0..1 over the quad; one unit of uv is roughly 400 world units.
	vec2 uv = UV * vec2(4.0, 5.0);
	vec3 col = vec3(0.004, 0.005, 0.012);
	vec2 nuv = uv * 1.3 + vec2(0.0, -scroll * 0.0006);
	float n = vnoise(nuv) * 0.6 + vnoise(nuv * 2.3 + 4.0) * 0.3 + vnoise(nuv * 5.1) * 0.1;
	col += mix(nebula_a, nebula_b, vnoise(nuv * 0.7 + 9.0)) * smoothstep(0.35, 0.9, n) * 0.5 * nebula_strength;
	col += star_layer(uv, 60.0, 0.0008, 0.09, 0.6);
	col += star_layer(uv + 3.3, 34.0, 0.0016, 0.09, 1.0);
	col += star_layer(uv + 7.1, 18.0, 0.003, 0.09, 1.8);
	ALBEDO = col;
}
