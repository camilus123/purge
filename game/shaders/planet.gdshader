// Procedural Earth-like planet: oceans, continents, moving clouds, night side and atmosphere rim.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 light_dir = vec3(-0.5, 0.6, -0.6);   // world space, toward the light
uniform vec3 ocean_deep : source_color = vec3(0.01, 0.07, 0.22);
uniform vec3 ocean_shallow : source_color = vec3(0.04, 0.3, 0.5);
uniform vec3 land_low : source_color = vec3(0.1, 0.33, 0.1);
uniform vec3 land_high : source_color = vec3(0.4, 0.33, 0.22);
uniform vec3 atmosphere : source_color = vec3(0.3, 0.6, 1.0);
uniform float spin = 0.0;
uniform float cloud_shift = 0.0;
uniform float sea_level = 0.52;

varying vec3 v_obj;
varying vec3 v_world_n;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise3(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return s;
}

vec3 rot_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

void vertex() {
	v_obj = normalize(VERTEX);
	v_world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = rot_y(normalize(v_obj), spin);
	float h = fbm(p * 2.4);
	float land = smoothstep(sea_level, sea_level + 0.03, h);
	vec3 ocean = mix(ocean_deep, ocean_shallow, smoothstep(sea_level - 0.2, sea_level, h));
	vec3 ground = mix(land_low, land_high, smoothstep(sea_level + 0.03, sea_level + 0.25, h));
	float polar = smoothstep(0.78, 0.92, abs(p.y) + (h - 0.5) * 0.2);
	vec3 surface = mix(mix(ocean, ground, land), vec3(0.55, 0.58, 0.62), polar);

	float clouds = smoothstep(0.58, 0.82, fbm(rot_y(p, cloud_shift) * 5.0 + 20.0));
	surface = mix(surface, vec3(0.8), clouds * 0.6);

	vec3 n = normalize(v_world_n);
	float ndl = dot(n, normalize(light_dir));
	float day = smoothstep(-0.15, 0.35, ndl);
	// City lights on the night side, only on land without cloud cover.
	float cities = step(0.8, vnoise3(p * 170.0)) * land * (1.0 - clouds) * (1.0 - day);
	vec3 col = surface * (day * 1.05 + 0.015) + vec3(1.0, 0.75, 0.4) * cities * 0.2;

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	col += atmosphere * fres * (day * 1.4 + 0.05);
	ALBEDO = col * 0.55;
}
