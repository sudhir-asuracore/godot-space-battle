shader_type canvas_item;

// Colors
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 0.6, 1.0, 1.0); // Neon Blue default

// Shape settings
uniform float core_width : hint_range(0.0, 0.5) = 0.03;
uniform float glow_width : hint_range(0.0, 0.5) = 0.2;
uniform float laser_length : hint_range(0.0, 1.0) = 0.5;

// Animation settings
uniform float pulse_speed : hint_range(0.0, 30.0) = 15.0;
uniform float pulse_intensity : hint_range(0.0, 0.1) = 0.02;

// Signed Distance Field function for a 2D Capsule/Pill shape
float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

void fragment() {
    // Center the UV coordinates to (-0.5, 0.5) so (0,0) is the middle
    vec2 uv = UV - vec2(0.5);
    
    // Define the top and bottom endpoints of the laser bolt
    //vec2 point_a = vec2(0.0, -laser_length * 0.5);
    //vec2 point_b = vec2(0.0, laser_length * 0.5);
	// Horizontal orientation
	vec2 point_a = vec2(-laser_length * 0.5, 0.0);
	vec2 point_b = vec2(laser_length * 0.5, 0.0);
    
    // Calculate distance from current pixel to the capsule centerline
    float dist = sdCapsule(uv, point_a, point_b, 0.0);
    
    // Create an energetic flickering/pulsing effect over time
    float pulse = sin(TIME * pulse_speed) * pulse_intensity;
    float dynamic_glow = max(core_width, glow_width + pulse);
    
    // Calculate the core mask (sharp center) and glow mask (faded edge)
    float core_mask = smoothstep(core_width, core_width - 0.01, dist);
    float glow_mask = smoothstep(dynamic_glow, core_width, dist);
    
    // Square the glow mask to give it a more natural exponential falloff
    glow_mask = pow(glow_mask, 2.0);
    
    // Mix core color and glow color based on the masks
    vec4 final_color = mix(glow_color * glow_mask, core_color, core_mask);
    
    // Define transparency based on the glow radius
    final_color.a = max(core_mask, glow_mask * glow_color.a);
    
    COLOR = final_color;
}