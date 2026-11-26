shader_type canvas_item;

// Speed lines radial ala manga, berkedip tiap beberapa frame (momen ledakan emosi).
uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform float inner = 0.3;
uniform float density = 140.0;
uniform float fps = 12.0;
uniform float aspect = 1.7778;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= aspect;
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float r = length(p);
	float t = floor(TIME * fps);
	float idx = floor(a * density);
	float f = fract(a * density);
	float h = hash(idx * 13.7 + t * 1.31);
	float w = 0.12 + 0.4 * hash(idx * 3.1 + t * 0.7);
	float line = smoothstep(w * 0.5, w * 0.5 - 0.08, abs(f - 0.5)) * step(0.5, h);
	float start = inner + hash(idx * 7.7 + t * 5.3) * 0.22;
	float m = smoothstep(start, start + 0.18, r);
	COLOR = vec4(line_color.rgb, line * m * alpha * line_color.a);
}
