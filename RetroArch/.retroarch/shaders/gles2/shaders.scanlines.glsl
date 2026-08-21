// Scanlines Shader - GLES 2.0 Compatible
// Optimized for Mali GPU on TrimUI devices

#ifdef GL_ES
precision mediump float;
#endif

// Input textures
uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

// Scanline parameters
uniform float ScanlineIntensity;
uniform float ScanlineThickness;
uniform float ScanlineBrightness;

// Vertex coordinates
varying vec2 texCoord;

// Main shader
void main() {
    vec2 uv = texCoord;
    
    // Get original color
    vec3 color = texture2D(Texture, uv).rgb;
    
    // Calculate scanline position
    float scanline = mod(uv.y * OutputSize.y, 2.0);
    
    // Apply scanline effect
    float intensity = ScanlineIntensity;
    float thickness = ScanlineThickness;
    
    // Create scanline pattern
    float scanlineEffect = smoothstep(0.5 - thickness, 0.5 + thickness, scanline);
    
    // Apply scanlines
    color *= mix(1.0 - intensity, 1.0, scanlineEffect);
    
    // Adjust brightness
    color *= ScanlineBrightness;
    
    // Clamp output
    color = clamp(color, 0.0, 1.0);
    
    gl_FragColor = vec4(color, 1.0);
}
