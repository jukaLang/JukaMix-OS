// CRT Guest NTSC Composite - GLES 2.0 Compatible
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

// NTSC parameters
uniform float NTSC_TBrightness;
uniform float NTSC_TContrast;
uniform float NTSC_TSaturation;

// Vertex coordinates
varying vec2 texCoord;

// NTSC signal processing
vec3 ntsc_signal(vec3 rgb) {
    float signal = dot(rgb, vec3(0.299, 0.587, 0.114));
    return vec3(signal);
}

// Composite video simulation
vec3 composite_video(vec2 uv, float time) {
    vec3 color = texture2D(Texture, uv).rgb;
    
    // Apply NTSC encoding
    float signal = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Add scanline effect
    float scanline = sin(uv.y * OutputSize.y * PI * 2.0) * 0.1;
    signal += scanline;
    
    // Apply brightness and contrast
    signal = (signal - 0.5) * NTSC_TContrast + 0.5 + NTSC_TBrightness;
    
    // Convert back to RGB
    vec3 result = vec3(signal);
    
    // Apply saturation
    float gray = dot(result, vec3(0.299, 0.587, 0.114));
    result = mix(vec3(gray), result, NTSC_TSaturation);
    
    return result;
}

// Main shader
void main() {
    vec2 uv = texCoord;
    
    // Apply NTSC composite effect
    vec3 color = composite_video(uv, 0.0);
    
    // Clamp output
    color = clamp(color, 0.0, 1.0);
    
    gl_FragColor = vec4(color, 1.0);
}
