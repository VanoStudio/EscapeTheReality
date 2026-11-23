shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Latar halaman komik: kertas gelap bertekstur (GDD bagian 3, tata letak komik poin 1).
uniform vec3 base_color : source_color = vec3(0.075, 0.064, 0.085);
uniform vec3 warm_color : source_color = vec3(0.32, 0.2, 0.12);
uniform float warm_amount : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float grain = vnoise(uv * vec2(1400.0, 900.0));
	float blotch = vnoise(uv * vec2(90.0, 60.0)) * 0.6 + vnoise(uv * vec2(18.0, 12.0)) * 0.4;
	float fiber = vnoise(vec2(uv.x * 60.0, uv.y * 2200.0));
	vec3 col = base_color * (0.78 + grain * 0.22 + blotch * 0.3 + fiber * 0.06);
	float d = distance(uv, vec2(0.5, 0.48));
	col += warm_color * warm_amount * smoothstep(0.55, 0.0, d) * 0.35;
	col *= mix(0.35, 1.0, smoothstep(0.75, 0.12, d));
	ALBEDO = col * brightness;
}
