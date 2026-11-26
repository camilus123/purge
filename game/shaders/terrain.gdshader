// Low-altitude ground: grassland, farm fields, forest, a river, roads and city blocks.
// Everything is procedural and keyed to ground coordinates, so it scrolls forever.
// The urban() function is mirrored in terrain_background.gd, which places the 3D buildings.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float scroll = 0.0;          // ground distance travelled
uniform vec2 map_offset = vec2(0.0); // where on the endless map this level flies
uniform float brightness = 0.62;     // kept low so bullets stay readable
uniform vec3 grass_a : source_color = vec3(0.16, 0.33, 0.1);
uniform vec3 grass_b : source_color = vec3(0.3, 0.42, 0.14);
uniform vec3 field_a : source_color = vec3(0.45, 0.42, 0.16);
uniform vec3 field_b : source_color = vec3(0.24, 0.4, 0.12);
uniform vec3 forest : source_color = vec3(0.05, 0.17, 0.06);
uniform vec3 water : source_color = vec3(0.06, 0.2, 0.36);
uniform vec3 road : source_color = vec3(0.2, 0.2, 0.22);
uniform vec3 pavement : source_color = vec3(0.4, 0.4, 0.41);
uniform vec3 corruption : source_color = vec3(0.35, 0.05, 0.4);
uniform float corruption_amount = 0.0;   // 0 = healthy; used by later level sets

varying vec2 v_ground;

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

float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.1 + 7.3) * 0.3 + vnoise(p * 4.3 + 1.9) * 0.2;
}

// > 0.75 means city. Must match TerrainBackground.urban().
float urban(vec2 p) {
	return sin(p.x * 0.021 + 1.7) * 0.6 + sin(p.y * 0.011 + 0.4) * 0.8 + sin((p.x + p.y) * 0.007) * 0.5;
}

float line_mask(float coord, float period, float half_width) {
	float d = abs(fract(coord / period + 0.5) - 0.5) * period;
	return 1.0 - smoothstep(half_width - 0.25, half_width + 0.25, d);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_ground = vec2(world.x, world.z - scroll) + map_offset;
}

void fragment() {
	vec2 p = v_ground;
	float u = urban(p);
	float city = smoothstep(0.7, 0.8, u);

	// Countryside: grass with large colour drift, a patchwork of fields, dark forest patches.
	float n = fbm(p * 0.03);
	vec3 col = mix(grass_a, grass_b, n);
	vec2 fcell = floor(p / vec2(26.0, 18.0));
	float farm = smoothstep(0.5, 0.56, vnoise(p * 0.009 + 40.0));
	vec2 fin = fract(p / vec2(26.0, 18.0));
	float border = step(0.04, fin.x) * step(0.05, fin.y);
	float furrow = 0.92 + 0.08 * sin((hash(fcell) > 0.5 ? p.x : p.y) * 3.0);
	vec3 fieldc = mix(field_a, field_b, hash(fcell + 3.7)) * furrow;
	col = mix(col, mix(col * 0.7, fieldc, border), farm);
	float trees = smoothstep(0.55, 0.62, fbm(p * 0.018 + 90.0)) * (1.0 - farm);
	col = mix(col, forest * (0.7 + 0.6 * vnoise(p * 0.9)), trees);

	// River wandering down the map.
	float river_x = sin(p.y * 0.008) * 28.0 + sin(p.y * 0.021 + 2.0) * 9.0 - 18.0;
	float rd = abs(p.x - river_x);
	col = mix(col, vec3(0.5, 0.47, 0.33), 1.0 - smoothstep(5.0, 7.0, rd));
	col = mix(col, water * (0.85 + 0.3 * vnoise(p * 0.4 + vec2(0.0, TIME * 0.6))), 1.0 - smoothstep(4.0, 5.0, rd));

	// City blocks: pavement with a street grid.
	vec3 block = pavement * (0.85 + 0.25 * hash(floor(p / 8.0)));
	col = mix(col, block, city);
	float streets = max(line_mask(p.x, 32.0, 1.3), line_mask(p.y, 32.0, 1.3));
	col = mix(col, road, streets * city);

	// Highways run everywhere, with a dashed centre line.
	float hx = line_mask(p.x + sin(p.y * 0.006) * 12.0, 192.0, 2.2);
	float hy = line_mask(p.y, 256.0, 2.2);
	float highway = max(hx, hy);
	col = mix(col, road * 0.9, highway);
	float dash_x = line_mask(p.x + sin(p.y * 0.006) * 12.0, 192.0, 0.15) * step(0.5, fract(p.y / 6.0));
	float dash_y = line_mask(p.y, 256.0, 0.15) * step(0.5, fract(p.x / 6.0));
	col = mix(col, vec3(0.8, 0.75, 0.5), max(dash_x, dash_y));

	// Spreading corruption for infested or burning worlds (later sets).
	float creep = smoothstep(1.0 - corruption_amount, 1.05 - corruption_amount, fbm(p * 0.02 + 300.0));
	col = mix(col, corruption * (0.6 + 0.8 * vnoise(p * 0.5)), creep * step(0.001, corruption_amount));

	// Soft cloud shadows drifting across the ground.
	float shade = smoothstep(0.45, 0.7, fbm(p * 0.006 + vec2(TIME * 0.01, 0.0)));
	col *= mix(1.0, 0.6, shade);
	ALBEDO = col * brightness;
}
