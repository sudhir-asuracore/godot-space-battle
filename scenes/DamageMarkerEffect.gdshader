shader_type canvas_item;
render_mode blend_mix;

// Flame and Smoke colors
uniform vec4 core_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);  // Cyan hot core
uniform vec4 outer_color : source_color = vec4(0.0, 0.3, 1.0, 1.0); // Blue flame edge
uniform vec4 smoke_color : source_color = vec4(0.2, 0.2, 0.3, 0.6); // Fading smoke

// Animation Controls
uniform sampler2D noise_texture : repeat_enable;
uniform float speed = 4.0;
uniform float flame_length : hint_range(0.1, 1.0) = 0.6;
uniform float distortion : hint_range(0.0, 0.5) = 0.15;

void fragment() {
    // 1. Establish Direction (Assuming Sprite points UP. UV.y 0.0=Top, 1.0=Bottom)
    // Flip UV.y if your engine points downward instead
    float vertical_axis = UV.y; 
    
    // 2. Animate and distort UVs using noise for a organic fluid look
    vec2 scrolling_uv = vec2(UV.x, vertical_axis - (TIME * speed));
    float noise_val = texture(noise_texture, scrolling_uv).r;
    
    // Distort the horizontal coordinate to make the fire wiggle
    float distorted_x = UV.x + (noise_val - 0.5) * distortion;
    
    // 3. Create a teardrop shape mask for the engine trail
    float cone_mask = smoothstep(0.0, 0.45, 0.5 - abs(distorted_x - 0.5));
    // Fade out as it moves away from the engine nozzle
    float length_fade = smoothstep(1.0, 0.0, vertical_axis);
    float base_shape = cone_mask * length_fade;
    
    // 4. Layer the Flame vs Smoke zones
    // Core fire is concentrated near the nozzle
    float core_mask = smoothstep(1.0 - flame_length, 1.0, base_shape * noise_val);
    // Smoke happens further down the trail
    float smoke_mask = smoothstep(0.1, 0.6, base_shape * (1.0 - noise_val * 0.5));
    
    // 5. Synthesize Colors
    vec3 final_color = mix(smoke_color.rgb, outer_color.rgb, core_mask);
    final_color = mix(final_color, core_color.rgb, core_mask * 1.5);
    
    // Compute total alpha transparency based on both shapes
    float final_alpha = max(core_mask, smoke_mask * smoke_color.a) * length_fade;
    
    COLOR = vec4(final_color, clamp(final_alpha, 0.0, 1.0));
}
