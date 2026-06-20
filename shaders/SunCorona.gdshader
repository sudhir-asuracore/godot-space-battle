shader_type canvas_item;
render_mode blend_add;

group_uniforms appearance;
uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 corona_color : source_color = vec4(1.0, 0.42, 0.06, 1.0);
uniform vec4 spot_color : source_color = vec4(0.45, 0.18, 0.02, 1.0);

group_uniforms shape;
uniform float sun_radius : hint_range(0.05, 0.45) = 0.30;
uniform float corona_size : hint_range(0.0, 0.35) = 0.18;
uniform float bloom_strength : hint_range(0.0, 3.0) = 1.1;

group_uniforms surface;
uniform float surface_detail : hint_range(1.0, 12.0) = 5.0;
uniform float granulation : hint_range(0.0, 1.0) = 0.55;
uniform float spot_amount : hint_range(0.0, 1.0) = 0.35;
uniform float rotation_speed : hint_range(-1.0, 1.0) = 0.03;

group_uniforms flares;
uniform float flare_detail : hint_range(1.0, 12.0) = 4.0;
uniform float flare_intensity : hint_range(0.0, 4.0) = 1.6;
uniform float flare_speed : hint_range(0.0, 2.0) = 0.45;

// Global constants for optimization
const mat2 ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
const int MAX_OCTAVES = 6; // 6 is visually indistinguishable from 12 but 2x faster

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float value_noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);

    float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));

    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    return mix(nxy0, nxy1, u.z);
}

float fbm3(vec3 p, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    for (int i = 0; i < MAX_OCTAVES; i++) {
        if (i >= octaves) {
            break;
        }
        value += amp * value_noise3(p);
        p.xy = ROT * p.xy;
        p.yz = ROT * p.yz;
        p *= 2.02;
        amp *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    float t = TIME;
    vec4 col = vec4(0.0);

    if (dist <= sun_radius) {
        // ---- Sun surface -------------------------------------------------
        vec2 nxy = uv / sun_radius;
        // Optimized to native dot product instruction
        float nz = sqrt(max(0.0, 1.0 - dot(nxy, nxy))); 

        float spin = t * rotation_speed * TAU;
        float cs = cos(spin);
        float sn = sin(spin);
        
        vec3 sp = vec3(cs * nxy.x + sn * nz, nxy.y, -sn * nxy.x + cs * nz);
        sp *= (3.0 + surface_detail);
        int oct = int(surface_detail);

        float cells = fbm3(sp + vec3(0.0, t * 0.05, t * 0.03), oct);
        // Optimization: Capping fine noise octaves at 3 since it's already high-frequency
        float fine = fbm3(sp * 2.7 - vec3(t * 0.08, 0.0, 0.0), min(oct, 3)); 
        float plasma = mix(cells, fine, 0.4);

        vec3 base = mix(hot_color.rgb, core_color.rgb, smoothstep(0.2, 0.9, plasma));
        base += core_color.rgb * granulation * pow(plasma, 3.0);

        float spots = fbm3(sp * 0.6 + vec3(t * 0.02, 0.0, -t * 0.015), 4);
        float spot_mask = smoothstep(0.62, 0.42, spots) * spot_amount;
        base = mix(base, spot_color.rgb, spot_mask);

        float limb = clamp(pow(nz, 0.55), 0.12, 1.0);
        base *= limb;

        float rim = smoothstep(sun_radius, sun_radius * 0.82, dist);
        base += hot_color.rgb * (1.0 - rim) * 0.6;

        col = vec4(base, 1.0);
    } else {
        // ---- Corona, flares and bloom -----------------------------------
        float d_out = dist - sun_radius;
        float d_norm = d_out / corona_size; 

        float ringscale = 4.0 + flare_detail;
        // Optimization: Removed atan, cos, and sin. Directly normalized the UV vector.
        vec3 rdir = vec3(uv / dist, 0.0) * ringscale; 

        vec3 acc = vec3(0.0);
        float alpha = 0.0;

        if (d_norm < 1.0) {
            vec3 fuv1 = rdir + vec3(0.0, 0.0, d_norm * 3.0 - t * flare_speed);
            vec3 fuv2 = rdir * 1.7 + vec3(0.0, 0.0, d_norm * 4.5 - t * flare_speed * 1.4);
            float f1 = fbm3(fuv1, int(flare_detail));
            float f2 = fbm3(fuv2, int(flare_detail));
            float flare = pow(f1 * f2, 1.5) * flare_intensity;

            float edge_fade = 1.0 - d_norm;
            float corona_a = clamp(pow(edge_fade * (0.4 + flare), 1.8), 0.0, 1.0);

            acc += mix(corona_color.rgb, hot_color.rgb, flare) * corona_a;
            alpha = corona_a;
        }

        float halo = exp(-d_out / (corona_size * (0.45 + bloom_strength)));
        halo = pow(halo, 1.5) * bloom_strength;
        acc += corona_color.rgb * halo;
        alpha = clamp(alpha + halo, 0.0, 1.0);

        // Optimization: Removed conditional discard to prevent pipeline stalls
        col = vec4(acc, alpha); 
    }

    // Fade the additive glow smoothly to zero before it reaches the quad's
    // edge (UV dist 0.5). Without this the corona/bloom is still bright at
    // the ColorRect border and gets hard-cut, showing a visible square box.
    float quad_fade = 1.0 - smoothstep(sun_radius, 0.5, dist);
    col *= quad_fade;

    COLOR = col;
}