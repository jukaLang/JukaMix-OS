// LCD GBA - GLES 2.0 Optimized
// Simulates GBA LCD characteristics with slight blur and color
// Good for GBA, GBC, and handheld games

#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

varying vec2 texCoord;

// GBA LCD colors (slightly washed out greens/blues)
const vec3 LCD_TINT = vec3(0.95, 1.0, 0.98);

void main() {
    vec2 uv = texCoord;
    vec2 texel = 1.0 / TextureSize;
    
    // 3x3 blur to simulate LCD response
    vec3 color = vec3(0.0);
    float total = 0.0;
    
    for (float x = -1.0; x <= 1.0; x += 1.0) {
        for (float y = -1.0; y <= 1.0; y += 1.0) {
            float weight = 1.0 / (1.0 + abs(x) + abs(y));
            color += texture2D(Texture, uv + vec2(x, y) * texel).rgb * weight;
            total += weight;
        }
    }
    color /= total;
    
    // Apply LCD tint
    color *= LCD_TINT;
    
    // Subtle pixel grid
    vec2 pixel = fract(uv * TextureSize);
    float grid = smoothstep(0.0, 0.05, pixel.x) * smoothstep(0.0, 0.05, pixel.y);
    grid *= smoothstep(0.0, 0.05, 1.0 - pixel.x) * smoothstep(0.0, 0.05, 1.0 - pixel.y);
    color *= mix(0.90, 1.0, grid);
    
    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
