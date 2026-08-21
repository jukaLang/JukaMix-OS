// Strong Scanlines - GLES 2.0 Compatible
// Pronounced scanline effect for authentic CRT look
// Optimized for Mali GPU on TrimUI devices

#ifdef GL_ES
precision mediump float;
#endif

#define PI 3.14159265

// Input textures
uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

// Vertex coordinates
varying vec2 texCoord;

// Scanline parameters
uniform float ScanlineIntensity;
uniform float ScanlineSpeed;

// Strong scanline effect
vec3 apply_scanlines(vec2 uv, vec3 color) {
    // Calculate scanline position
    float y = uv.y * OutputSize.y;
    
    // Create strong scanline pattern
    float scanline = sin(y * PI * 2.0) * 0.5 + 0.5;
    scanline = pow(scanline, 1.5); // Sharpen the scanlines
    
    // Apply scanline intensity
    float intensity = ScanlineIntensity > 0.0 ? ScanlineIntensity : 0.3;
    color *= mix(1.0 - intensity, 1.0, scanline);
    
    // Add slight RGB offset for authentic look
    float rgb_offset = 0.001;
    vec3 colorR = texture2D(Texture, uv + vec2(rgb_offset, 0.0)).rgb;
    vec3 colorB = texture2D(Texture, uv - vec2(rgb_offset, 0.0)).rgb;
    
    color.r = mix(color.r, colorR.r, 0.1);
    color.b = mix(color.b, colorB.b, 0.1);
    
    return color;
}

// Vignette effect
vec3 apply_vignette(vec2 uv, vec3 color) {
    vec2 center = uv - 0.5;
    float dist = length(center);
    float vignette = 1.0 - dot(dist, dist) * 0.5;
    return color * vignette;
}

// Main shader
void main() {
    vec2 uv = texCoord;
    
    // Sample original color
    vec3 color = texture2D(Texture, uv).rgb;
    
    // Apply scanlines
    color = apply_scanlines(uv, color);
    
    // Apply vignette
    color = apply_vignette(uv, color);
    
    // Clamp output
    color = clamp(color, 0.0, 1.0);
    
    gl_FragColor = vec4(color, 1.0);
}
