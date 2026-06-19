shader_type canvas_item;

uniform sampler2D sun_texture : source_color, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform float rotation_speed : hint_range(-1.0, 1.0) = 0.03;
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.03;
uniform float corona_size : hint_range(0.0, 0.25) = 0.12;
uniform vec4 sun_color : source_color = vec4(1.2, 0.9, 0.5, 1.0);
uniform vec4 corona_color : source_color = vec4(1.0, 0.45, 0.0, 1.0);

void fragment() {
	// Offset UV to be centered at (0.0, 0.0)
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	
	// Core radius of the sun inside the square UV coordinates (leaving room for corona)
	float r = 0.38;
	
	if (dist <= r) {
		// 3D Sphere mapping
		float nx = uv.x / r;
		float ny = uv.y / r;
		// Calculate z on the unit hemisphere facing the camera
		float nz = sqrt(1.0 - nx*nx - ny*ny);
		
		// Spherical coordinates (Latitude / Longitude)
		float lat = asin(ny);
		float lon = atan(nz, nx);
		
		// Map to 2D texture coordinates for the equirectangular 2k_sun map
		float u = (lon + 3.14159265) / (2.0 * 3.14159265);
		float v = (lat + 1.57079632) / 3.14159265;
		
		// Apply rotation over time
		u -= TIME * rotation_speed;
		
		// Bubbling plasma convection using dual-octave noise scrolling
		vec2 noise_uv1 = vec2(u * noise_scale, v * noise_scale + TIME * 0.02);
		vec2 noise_uv2 = vec2(u * noise_scale * 1.6 - TIME * 0.015, v * noise_scale * 1.6 + TIME * 0.01);
		
		float noise_val1 = texture(noise_texture, noise_uv1).r;
		float noise_val2 = texture(noise_texture, noise_uv2).g;
		
		u += (noise_val1 - 0.5) * noise_strength;
		v += (noise_val2 - 0.5) * noise_strength;
		
		// Sample the realistic 2K sun texture
		vec4 tex_color = texture(sun_texture, vec2(u, v));
		
		// Limb darkening (black body radiation is dimmer at grazing angles)
		float limb = nz;
		limb = clamp(pow(limb, 0.5), 0.1, 1.0);
		
		COLOR = tex_color * sun_color * limb;
	} else {
		// Corona / Solar flares / Coronal ejections
		float d_norm = (dist - r) / corona_size; // 0 at surface, 1 at edge
		
		if (d_norm < 1.0) {
			// Polar coordinates for circular noise lookup
			float angle = atan(uv.y, uv.x);
			
			// Dynamic plasma flowing outwards from the star
			vec2 noise_uv1 = vec2(angle / (2.0 * 3.14159265) + 0.5 + TIME * 0.02, d_norm - TIME * 0.2);
			vec2 noise_uv2 = vec2(angle / (2.0 * 3.14159265) + 0.1 - TIME * 0.03, d_norm * 1.4 - TIME * 0.35);
			
			float n1 = texture(noise_texture, noise_uv1).r;
			float n2 = texture(noise_texture, noise_uv2).g;
			float noise_factor = (n1 + n2) * 0.5;
			
			// Falloff alpha at the outer edge, modulated by noise to shape ejections
			float edge_fade = 1.0 - d_norm;
			float corona_alpha = edge_fade * noise_factor * 1.8;
			corona_alpha = clamp(pow(corona_alpha, 2.5), 0.0, 1.0);
			
			// Glowing orange flare color
			vec4 flare = corona_color;
			flare.a *= corona_alpha;
			
			COLOR = flare;
		} else {
			discard;
		}
	}
}
