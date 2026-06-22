shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec4 nebula_color : source_color = vec4(0.5, 0.2, 0.8, 0.6);
uniform vec2 scroll_direction = vec2(0.5, 0.3);
uniform float scroll_speed : hint_range(0.0, 0.1) = 0.005;

// Cloud controls
uniform float cloud_density : hint_range(0.0, 1.0) = 0.4;  
uniform float cloud_softness : hint_range(0.01, 1.0) = 0.3; 

// New Star Cluster controls
uniform vec4 star_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float star_density : hint_range(0.01, 0.2) = 0.05; // Lower = sharper, fewer stars
uniform float star_amount : hint_range(0.0, 1.0) = 0.5;    // Overall star visibility

void fragment() {
    // Scroll coordinates for the base clouds
    vec2 uv1 = UV + scroll_direction * TIME * scroll_speed;
    vec2 uv2 = UV * 1.5 - scroll_direction * TIME * (scroll_speed * 0.7);
    
    float noise1 = texture(noise_texture, uv1).r;
    float noise2 = texture(noise_texture, uv2).r;
    float combined_noise = noise1 * noise2;
    
    // Calculate cloud alpha mask
    float cloud_alpha = smoothstep(1.0 - cloud_density, (1.0 - cloud_density) + cloud_softness, combined_noise);
    
    // Create high-frequency stars by multiplying UVs to tile the noise rapidly
    vec2 star_uv = UV * 40.0 + (scroll_direction * TIME * (scroll_speed * 0.3));
    float star_noise = texture(noise_texture, star_uv).r;
    
    // Isolate sharp, intense peaks in the noise to look like tiny pinprick stars
    float star_intensity = smoothstep(1.0 - star_density, 1.0, star_noise) * star_amount;
    
    // CRUCIAL: Multiply star intensity by cloud_alpha so they only spawn inside the gas
    float embedded_stars = star_intensity * cloud_alpha;
    
    // Mix the nebula gas color with the glowing star color
    vec3 final_rgb = mix(nebula_color.rgb, star_color.rgb, embedded_stars);
    // Combine gas alpha and star alpha so stars stick out sharply
    float final_alpha = max(cloud_alpha * nebula_color.a, embedded_stars);
    
    COLOR = vec4(final_rgb, final_alpha);
}
