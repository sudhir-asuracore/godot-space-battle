shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D noise_texture : source_color, repeat_enable;
uniform vec4 flame_color : source_color = vec4(1.4, 0.45, 0.05, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.25, 0.25, 0.25, 1.0);

uniform float flame_speed = 4.5;
uniform float smoke_speed = 1.8;
uniform float noise_scale = 2.0;
uniform float flicker_amount = 0.2;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

float edge_glow(vec2 uv) {
	float centered = abs(uv.x - 0.5) * 2.0;
	return pow(clamp(1.0 - centered, 0.0, 1.0), 2.0);
}

void fragment() {
	vec4 mask = texture(TEXTURE, UV);

	float time_flicker = TIME * flame_speed + sin(TIME * 10.0) * flicker_amount;
	vec2 flame_uv = UV * vec2(1.0, noise_scale) + vec2(0.0, -time_flicker);
	vec2 smoke_uv = UV * vec2(0.5, noise_scale * 0.5) + vec2(0.0, -TIME * smoke_speed);

	float noise1 = texture(noise_texture, flame_uv).r;
	float noise2 = texture(noise_texture, smoke_uv).r;
	float flame_noise = smoothstep(0.12, 0.95, noise1);
	float smoke_noise = smoothstep(0.06, 0.9, noise2);

	float tail_mask = clamp(1.0 - UV.y, 0.0, 1.0);
	float side_mask = pow(clamp(1.0 - abs(UV.x - 0.5) * 2.0, 0.0, 1.0), 2.6);
	float plume_profile = side_mask * smoothstep(0.02, 0.95, tail_mask);
	float smoke_profile = pow(side_mask, 1.4) * smoothstep(0.0, 0.78, tail_mask);

	float flame_mix = clamp(plume_profile * (0.42 + flame_noise * 0.85), 0.0, 1.0);
	vec3 dynamic_color = mix(smoke_color.rgb, flame_color.rgb, flame_mix);

	float alpha_noise = max(flame_noise * 0.72, smoke_noise * 0.55);
	float alpha_shape = plume_profile * 0.92 + smoke_profile * 0.4;
	float alpha = alpha_shape * alpha_noise * mask.a;
	float glow = edge_glow(UV) * (0.35 + flame_mix * 0.85);

	vec3 final_color = dynamic_color + flame_color.rgb * glow * 0.9;
	COLOR = vec4(final_color * intensity, clamp(alpha * intensity * 1.35, 0.0, 1.0));
}