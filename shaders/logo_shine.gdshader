shader_type canvas_item;

// Kilau yang menyapu logo secara berkala (hanya di area logo, mengikuti alpha tekstur).
uniform float period = 5.0;
uniform float width = 0.12;
uniform float strength = 0.55;
uniform vec4 shine_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = fract(TIME / period) * 2.2 - 0.6;
	float band = UV.x + UV.y * 0.35;
	float s = smoothstep(width, 0.0, abs(band - t)) * strength;
	c.rgb = mix(c.rgb, shine_color.rgb, s * c.a);
	COLOR = c;
}
