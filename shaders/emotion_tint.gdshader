shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float shake_power : hint_range(0.0, 10.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Screen shake UV offset jika aktif
    if (shake_power > 0.0) {
        float shake_x = sin(TIME * 45.0) * (shake_power * 0.002);
        float shake_y = cos(TIME * 40.0) * (shake_power * 0.002);
        uv += vec2(shake_x, shake_y);
    }
    
    vec4 scene_color = texture(screen_texture, uv);
    
    // Tint color
    vec4 result = mix(scene_color, vec4(tint_color.rgb, scene_color.a), tint_amount * tint_color.a);
    
    // Vignette effect
    if (vignette_intensity > 0.0) {
        vec2 center_dist = uv - vec2(0.5);
        float dist = length(center_dist);
        float vignette = smoothstep(0.75, 0.25, dist * vignette_intensity);
        result.rgb *= vignette;
    }
    
    COLOR = result;
}
