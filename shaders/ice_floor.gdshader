shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec2 floor_point;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void vertex() {
	floor_point = VERTEX.xz;
}

void fragment() {
	vec2 p = floor_point * 0.65;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y));
			float d = length(offset + hash2(cell + offset) - f);
			second = max(nearest, min(second, d));
			nearest = min(nearest, d);
		}
	}
	// Opaque frost veins: no extra surface, transparency or collision changes.
	float vein = 1.0 - smoothstep(0.0, 0.028, second - nearest);
	float frost = sin(p.x * 5.4 + sin(p.y * 3.7)) * sin(p.y * 4.1 + p.x);
	ALBEDO = mix(vec3(0.095, 0.30, 0.46), vec3(0.24, 0.52, 0.66), frost * 0.5 + 0.5);
	ALBEDO = mix(ALBEDO, vec3(0.67, 0.87, 0.95), vein * 0.32);
	ROUGHNESS = 0.2 + vein * 0.12;
	METALLIC = 0.12;
	SPECULAR = 0.7;
	CLEARCOAT = 0.65;
	// Godot 4.7 uses roughness; gloss 0.8 corresponds to roughness 0.2.
	CLEARCOAT_ROUGHNESS = 0.2;
}
