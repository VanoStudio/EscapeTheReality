shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// Titik cahaya lembut (debu, bokeh, cahaya panel). Warna diambil dari COLOR partikel/vertex.
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float softness : hint_range(0.01, 1.0) = 0.5;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform bool use_vertex_color = true;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	float a = 1.0 - smoothstep(1.0 - softness, 1.0, d);
	a *= a;
	vec4 c = tint;
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = c.rgb * a * c.a * intensity;
}
