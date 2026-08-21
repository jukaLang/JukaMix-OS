// CRT Curved V2 - GLES 2.0 Optimized
// Full CRT simulation with barrel distortion, scanlines, and phosphor glow
// Tuned for Mali GPU on TrimUI devices

#ifdef GL_ES
precision mediump float;
#endif

#define PI 3.141592654

uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

varying vec2 texCoord;

// CRT curvature parameters
const float CURVATURE = 0.15;
const float SCANLINE_INTENSITY = 0.25;
const float BRIGHTNESS = 1.1;
const float VIGNETTE = 0.35;

// Barrel distortion for CRT curvature
vec2 barrel_distort(vec2 uv) {
    vec2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    float distort = 1.0 + CURVATURE * r2;
    return centered * distort + 0.5;
}

// Scanline effect
float scanline(vec2 uv) {
    float y = uv.y * OutputSize.y;
    float scan = sin(y * PI) * 0.5 + 0.5;
    return mix(1.0 - SCANLINE_INTENSITY, 1.0, scan);
}

// Vignette effect
float vignette(vec2 uv) {
    vec2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    return mix(1.0, 1.0 - VIGNETTE, r2 * 1.5);
}

// Phosphor glow (simplified bloom)
vec3 phosphor_glow(vec2 uv, vec3 color) {
    vec3 glow = vec3(0.0);
    float total = 0.0;
    
    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 offset = vec2(x, y) / OutputSize;
            float weight = 1.0 / (1.0 + length(vec2(x, y)));
            glow += texture2D(Texture, uv + offset).rgb * weight;
            total += weight;
        }
    }
    
    return mix(color, glow / total, 0.12);
}

void main() {
    vec2 uv = barrel_distort(texCoord);
    
    // Check bounds
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    // Sample with slight chromatic aberration
    float aberration = 0.5 / TextureSize.x;
    float r = texture2D(Texture, uv + vec2(aberration, 0.0)).r;
    float g = texture2D(Texture, uv).g;
    float b = texture2D(Texture, uv - vec2(aberration, 0.0)).b;
    vec3 color = vec3(r, g, b);
    
    // Apply effects
    color *= scanline(uv);
    color = phosphor_glow(uv, color);
    color *= vignette(uv);
    color *= BRIGHTNESS;
    
    // Slight gamma correction
    color = pow(color, vec3(0.95));
    
    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
