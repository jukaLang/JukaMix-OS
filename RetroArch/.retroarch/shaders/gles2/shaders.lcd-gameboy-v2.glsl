// LCD Game Boy V2 - GLES 2.0 Optimized
// Authentic Game Boy LCD with pixel grid and green palette
// Tuned for Mali GPU on TrimUI devices

#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

varying vec2 texCoord;

// Classic Game Boy greens
const vec3 GB_DARK   = vec3(0.06, 0.22, 0.06);
const vec3 GB_MID    = vec3(0.19, 0.38, 0.19);
const vec3 GB_LIGHT  = vec3(0.55, 0.67, 0.06);
const vec3 GB_BRIGHT = vec3(0.61, 0.73, 0.06);

// 4-color palette quantization
vec3 gb_palette(float luma) {
    if (luma < 0.25) return GB_DARK;
    if (luma < 0.50) return GB_MID;
    if (luma < 0.75) return GB_LIGHT;
    return GB_BRIGHT;
}

// LCD pixel grid
vec3 lcd_grid(vec2 uv, vec3 color) {
    vec2 pixel = fract(uv * TextureSize);
    
    // Create 3x3 grid within each pixel
    float gx = smoothstep(0.0, 0.08, pixel.x) * smoothstep(0.0, 0.08, 1.0 - pixel.x);
    float gy = smoothstep(0.0, 0.08, pixel.y) * smoothstep(0.0, 0.08, 1.0 - pixel.y);
    float grid = gx * gy;
    
    return color * mix(0.82, 1.0, grid);
}

// Subtle pixel blur (simulates LCD response time)
vec3 lcd_blur(vec2 uv) {
    vec3 color = vec3(0.0);
    float total = 0.0;
    
    for (float x = -1.0; x <= 1.0; x += 1.0) {
        for (float y = -1.0; y <= 1.0; y += 1.0) {
            vec2 offset = vec2(x, y) / TextureSize;
            float weight = 1.0 / (1.0 + length(vec2(x, y)));
            color += texture2D(Texture, uv + offset).rgb * weight;
            total += weight;
        }
    }
    
    return color / total;
}

void main() {
    vec2 uv = texCoord;
    
    // Sample with slight blur
    vec3 color = lcd_blur(uv);
    
    // Convert to luma
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Apply Game Boy palette
    color = gb_palette(luma);
    
    // Apply LCD grid
    color = lcd_grid(uv, color);
    
    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
