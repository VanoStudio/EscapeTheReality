shader_type canvas_item;

uniform vec4 shadow_tint : source_color = vec4(0.12, 0.08, 0.22, 1.0);
uniform float shadow_factor : hint_range(0.0, 1.0) = 0.85;
uniform vec4 glow_color : source_color = vec4(0.4, 0.2, 0.7, 0.6);

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    if (base.a <= 0.01) {
        discard;
    }
    
    // Gelapkan warna dasar menjadi nuansa bayangan ungu-hitam
    vec3 darkened = mix(base.rgb, shadow_tint.rgb, shadow_factor);
    
    // Efek aura halus di pinggir
    float edge_glow = (1.0 - base.a) * glow_color.a;
    vec3 final_rgb = mix(darkened, glow_color.rgb, edge_glow);
    
    COLOR = vec4(final_rgb, base.a);
}
