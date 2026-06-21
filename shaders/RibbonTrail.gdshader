shader_type canvas_item;

uniform vec4 base_color : source_color;
uniform float brightness : hint_range(1.0, 10.0) = 2.0;

void fragment() {
	float x = UV.x; // 0 at tail, 1 at head
	float y = abs(UV.y - 0.5) * 2.0; // 0 at center, 1 at edges
	
	// Smooth fade along the length
	float length_fade = pow(x, 1.2);
	
	// Smooth fade across the width
	float width_fade = smoothstep(1.0, 0.0, y);
	
	// Core glow
	float core = pow(1.0 - y, 4.0);
	
	vec3 color = base_color.rgb * brightness;
	// Add some white/hot core
	color = mix(color, vec3(1.0, 1.0, 1.0) * brightness, core * 0.5 * x);
	
	float alpha = base_color.a * length_fade * width_fade;
	
	COLOR = vec4(color, alpha);
}
