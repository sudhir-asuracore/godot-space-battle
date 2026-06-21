shader_type canvas_item;

// --- Uniforms ---
uniform vec4 shield_color : source_color = vec4(0.0, 0.6, 1.0, 1.0);
uniform float grid_scale : hint_range(1.0, 100.0) = 15.0;
uniform float line_thickness : hint_range(0.01, 0.5) = 0.08;
uniform float edge_glow_power : hint_range(0.5, 10.0) = 2.0;

// Impact Uniforms (Control via GDScript)
uniform vec2 impact_pos = vec2(0.5, 0.5);
uniform float impact_radius : hint_range(0.0, 2.0) = 0.0;

// --- Hexagon Math Helper ---
// Returns vec4(local_hex_uv, hex_center_uv)
vec4 hex_coords(vec2 uv) {
	vec2 r = vec2(1.0, 1.7320508); // 1.7320508 is sqrt(3)
	vec2 h = r * 0.5;
	
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv + h, r) - h;
	
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	return vec4(g, uv - g);
}

void fragment() {
	// 1. Center and scale UVs
	vec2 centered_uv = UV - 0.5;
	vec2 scaled_uv = centered_uv * grid_scale;
	
	// 2. Calculate Distance to Center for Circular Mask
	float dist_to_center = length(centered_uv) * 2.0;
	if (dist_to_center > 1.0) {
		discard; // Cuts the shader into a neat circle
	}
	
	// 3. Generate Hexagonal Grid
	vec4 hex = hex_coords(scaled_uv);
	float hex_center_dist = length(hex.xy);
	
	// Sharp hexagon edges using step functions
	float hex_grid = smoothstep(0.5 - line_thickness, 0.5, max(max(abs(hex.x) * 0.866025 + abs(hex.y) * 0.5, abs(hex.y)), 0.0));
	
	// 4. Ambient Energy & Waves
	float pulse = sin(TIME * 2.0 - hex_center_dist * 3.0) * 0.5 + 0.5;
	float base_energy = mix(0.1, 0.4, pulse);
	
	// 5. 2D Edge Glow (Fresnel equivalent)
	float edge_glow = pow(dist_to_center, edge_glow_power);
	
	// 6. Interactive Impact Ripple
	float dist_to_impact = distance(UV, impact_pos);
	float ripple = 0.0;
	if (impact_radius > 0.0) {
		// Creates a traveling shockwave ring
		float wave = smoothstep(0.15, 0.0, abs(dist_to_impact - impact_radius));
		// Fades out the wave as it expands past its radius
		float lifetime = smoothstep(impact_radius, 0.0, dist_to_impact);
		ripple = wave * lifetime * 2.5;
	}
	
	// 7. Composite Everything Together
	float final_intensity = (hex_grid * 0.6) + base_energy;
	final_intensity += edge_glow * 1.5;
	final_intensity += ripple;
	
	// Mask by overall opacity
	COLOR = vec4(shield_color.rgb * final_intensity, final_intensity * shield_color.a);
}