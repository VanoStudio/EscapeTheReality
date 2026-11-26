shader_type canvas_item;

// Color grade layar penuh untuk motion comic: tint, saturasi, kontras, kecerahan,
// chromatic aberration (momen ledakan), blur horizontal (whip pan) dan grain film.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float chroma = 0.0;
uniform float blur_x = 0.0;
uniform float grain : hint_range(0.0, 0.2) = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 sample_col(vec2 uv, vec2 px) {
	if (chroma > 0.01) {
		vec2 off = (uv - 0.5) * 2.0 * chroma * px;
		return vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	}
	return texture(screen_tex, uv).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 col = vec3(0.0);
	if (blur_x > 0.5) {
		float total = 0.0;
		for (int i = -6; i <= 6; i++) {
			float w = 1.0 - abs(float(i)) / 7.0;
			col += sample_col(uv + vec2(float(i) * blur_x / 6.0 * px.x, 0.0), px) * w;
			total += w;
		}
		col /= total;
	} else {
		col = sample_col(uv, px);
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col *= mix(vec3(1.0), tint.rgb, tint_amount);
	col *= brightness;
	float g = hash(uv * vec2(1920.0, 1080.0) + fract(TIME * 7.13) * 91.7) - 0.5;
	col += g * grain;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
