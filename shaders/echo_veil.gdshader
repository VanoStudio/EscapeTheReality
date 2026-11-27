shader_type canvas_item;

// Tirai kabut gerbang gema: asap ungu-hitam yang naik, tepi bercahaya, memudar di atas & bawah.
// open (0..1): tirai terbelah dari tengah saat dijawab jujur.
uniform vec4 smoke_color : source_color = vec4(0.16, 0.08, 0.28, 1.0);
uniform vec4 edge_color : source_color = vec4(0.75, 0.6, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.03, 0.01, 0.06, 1.0);
uniform float density = 0.85;
uniform float speed = 0.35;
uniform float open = 0.0;
uniform float glow = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	// asap naik + berliuk
	vec2 q = vec2(uv.x * 2.2 + sin(uv.y * 6.0 + t * 2.0) * 0.12, uv.y * 3.0 + t);
	float n = fbm(q * 2.0 + vec2(0.0, t));
	float n2 = fbm(q * 3.5 - vec2(t * 0.5, t));
	// bentuk tirai: tebal di tengah, tipis di sisi
	float cx = abs(uv.x - 0.5) * 2.0;
	float body = smoothstep(1.0, 0.25, cx + (n - 0.5) * 0.6);
	// celah saat terbuka
	float gap = smoothstep(open * 1.1 - 0.05, open * 1.1 + 0.05, cx + (n2 - 0.5) * 0.25);
	// pudar atas & bawah
	float vfade = smoothstep(0.0, 0.28, uv.y) * smoothstep(1.0, 0.8, uv.y);
	// tepi kiri-kanan selalu memudar halus (tidak terpotong kotak)
	float side = smoothstep(1.0, 0.55, cx);
	float a = body * side * vfade * density * mix(1.0, gap, step(0.001, open));
	vec3 col = mix(smoke_color.rgb, core_color.rgb, smoothstep(0.4, 0.8, n));
	// tepi bercahaya
	float edge = smoothstep(0.55, 0.85, n2) * (1.0 - smoothstep(0.0, 0.6, abs(body - 0.5) * 2.0));
	col += edge_color.rgb * edge * 0.6 * glow;
	col += edge_color.rgb * (1.0 - gap) * step(0.001, open) * 0.8;
	COLOR = vec4(col, clamp(a, 0.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, open)));
}
