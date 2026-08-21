// Retro TV - GLES 2.0 Optimized
// Combines scanlines, slight curvature, and warm color temperature
// Perfect for 8-bit and 16-bit era games

#ifdef GL_ES
precision mediump float;
#endif

#define PI 3.141592654

uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

varying vec2 texCoord;

// Warm color temperature (slight amber tint)
const vec3 WARM_TINT = vec3(1.05, 1.0, 0.92);

// Gentle barrel distortion
vec2 curve(vec2 uv) {
    vec2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    return centered * (1.0 + 0.08 * r2) + 0.5;
}

void main() {
    vec2 uv = curve(texCoord);
    
    // Bounds check
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    // Sample
    vec3 color = texture2D(Texture, uv).rgb;
    
    // Scanlines (subtle)
    float scanline = sin(uv.y * OutputSize.y * PI) * 0.5 + 0.5;
    scanline = mix(0.92, 1.0, scanline);
    color *= scanline;
    
    // Apply warm tint
    color *= WARM_TINT;
    
    // Slight vignette
    vec2 centered = uv - 0.5;
    float vig = 1.0 - dot(centered, centered) * 0.4;
    color *= vig;
    
    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
