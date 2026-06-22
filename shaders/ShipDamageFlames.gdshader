shader_type canvas_item;

// Disables light calculation just like the "unshaded" flag in the video
render_mode unshaded;

// --- TEXTURE PARAMETERS ---
// Replicates the "texture main" parameter with repeat enabled
uniform sampler2D texture_main : repeat_enable;
uniform sampler2D texture_add;
uniform sampler2D texture_multiply;
uniform sampler2D texture_subtract;

// 1D Gradient Texture for color mapping
uniform sampler2D texture_color_1d;

// --- UV PARAMETERS ---
uniform vec2 speed = vec2(0.0, 1.0);
uniform vec2 scale = vec2(1.0, 1.0);

void fragment() {
    // 1. UV Scaling and Panning Nodes
    vec2 panned_uv = (UV * scale) + (TIME * speed);

    // 2. Fetch the Black & White values using the Red channel
    float main_r = texture(texture_main, panned_uv).r;
    float add_r  = texture(texture_add, UV).r;
    float mult_r = texture(texture_multiply, UV).r;
    float sub_r  = texture(texture_subtract, UV).r;

    // 3. Node Math Chain (Add -> Multiply -> Subtract)
    float current_value = main_r + add_r;
    current_value = current_value * mult_r;
    current_value = current_value - sub_r;

    // 4. Clamp Node (Stabilizes values between 0.0 and 1.0)
    current_value = clamp(current_value, 0.0, 1.0);

    // 5. Color Mapping (Looks up color and alpha from the 1D Gradient)
    vec4 final_color = texture(texture_color_1d, vec2(current_value, 0.0));

    // Assign to final screen pixel output
    COLOR = final_color;
}
