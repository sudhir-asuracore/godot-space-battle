shader_type canvas_item;

// Color Channels (Matching your reference image)
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);       // Pure Hot White (Top)
uniform vec4 body_color : source_color = vec4(0.0, 0.4, 0.9, 1.0);       // Plasma Blue (Middle)
uniform vec4 edge_color : source_color = vec4(0.4, 0.0, 0.8, 1.0);       // Neon Violet/Purple (Outer Edges)

uniform float emission_glow : hint_range(0.0, 10.0) = 3.5;

// Noise & Movement
uniform sampler2D noise_texture : repeat_enable, filter_nearest; // Nearest gives that crisp/digital look
uniform vec2 scroll_speed = vec2(0.0, -7.8);
uniform float dissolve_tightness : hint_range(0.1, 1.0) = 0.4;

void fragment() {
    // 1. Read the white mask's shape and transparency
    vec4 mask = texture(TEXTURE, UV);
    
    // 2. Animate the noise upwards
    vec2 moving_uv = UV + scroll_speed * TIME;
    float noise = texture(noise_texture, moving_uv).r;
    
    // 3. Create a vertical gradient (UV.y goes from 0.0 at top to 1.0 at bottom)
    // This forces the top to stay bright white and the bottom to fade out
    float vertical_factor = 1.0 - UV.y; 
    
    // 4. Isolate horizontal edges for the purple trim
    // UV.x goes from 0.0 (left) to 1.0 (right). 0.5 is the dead center.
    float horizontal_edge = smoothstep(0.0, 0.45, abs(UV.x - 0.5));
    
    // 5. Combine Noise and Gradients to calculate color zones
    float plasma_value = noise * vertical_factor;
    
    // Base mix: Start with blue body, layer hot white core over it using the noise value
    vec3 final_color = mix(body_color.rgb, core_color.rgb, smoothstep(1.0 - dissolve_tightness, 1.0, plasma_value + 0.3));
    
    // Edge mix: Blend in the distinct purple borders along the sides
    final_color = mix(final_color, edge_color.rgb, horizontal_edge * 0.75);
    
    // Apply emission boost for Godot's WorldEnvironment HDR bloom
    final_color *= (1.0 + (1.0 - horizontal_edge) * emission_glow * vertical_factor);
    
    // 6. Use the silhouette's alpha channel so it perfectly cuts out the flame shape
    COLOR = vec4(final_color, mask.a * smoothstep(0.0, 0.15, plasma_value));
}