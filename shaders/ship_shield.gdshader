shader_type canvas_item;

// Colors matching the deep indigo field and bright cyan/white rim in image_8e0d9e.png
uniform vec4 shield_fill_color : source_color = vec4(0.15, 0.2, 0.45, 0.35);
uniform vec4 shield_rim_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);

uniform float radius : hint_range(0.0, 0.5) = 0.46;
uniform float rim_thickness : hint_range(0.0, 0.05) = 0.01;
uniform float glow_intensity : hint_range(1.0, 5.0) = 1.5;

// Controls the arc (0 to 360). Grows symmetrically from the starting point.
uniform float shield_angle : hint_range(0.0, 360.0) = 270.0;
// Recreates the soft fade-out at the ends of the shield arc seen in the image
uniform float edge_smoothness : hint_range(0.01, 0.5) = 0.15;

// If true, grows from the front tip. If false, grows from the rear engines.
uniform bool grow_from_right = true;

void fragment() {
    // Center UV coordinates to (0,0)
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);

    // 1. Calculate pixel angle based on orientation choice
    // If true, grows from the right (+X). If false, grows from the left (-X).
    float x_direction = grow_from_right ? uv.x : -uv.x;
    // Swap uv.x and uv.y so the angle math anchors to the horizontal axis
    float pixel_angle = abs(atan(uv.y, x_direction));

    // Convert current shield angle into radians for a symmetric half-arc
    float target_angle_rad = radians(shield_angle / 2.0);

    // 2. Arc Mask with feathered edges (prevents harsh pixelated cuts on the sides)
    float angle_mask = smoothstep(target_angle_rad, target_angle_rad - edge_smoothness, pixel_angle);

    // 3. Inner Fill Mask (Translucent disk)
    // We add a subtle radial falloff so it's slightly softer near the center of the ship
    float center_falloff = smoothstep(0.0, radius, dist);
    float fill_mask = smoothstep(radius, radius - 0.01, dist) * center_falloff;

    // 4. Outer Rim Mask (The sharp, bright boundary line)
    float rim_inside = smoothstep(radius - rim_thickness, radius - rim_thickness + 0.005, dist);
    float rim_outside = smoothstep(radius + 0.005, radius, dist);
    float rim_mask = rim_inside * rim_outside;

    // Combine layers and apply colors
    vec4 final_fill = shield_fill_color * fill_mask * angle_mask;
    vec4 final_rim = shield_rim_color * rim_mask * angle_mask * glow_intensity;

    // Mix the translucent bubble fill with the vibrant glowing edge
    vec4 final_output = final_fill + final_rim;

    COLOR = final_output;
}