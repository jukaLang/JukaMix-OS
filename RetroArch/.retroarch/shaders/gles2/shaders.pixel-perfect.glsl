// Pixel Perfect - GLES 2.0 Compatible
// Integer scaling for sharp, artifact-free pixels
// Optimized for Mali GPU on TrimUI devices

#ifdef GL_ES
precision mediump float;
#endif

// Input textures
uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

// Vertex coordinates
varying vec2 texCoord;

// Nearest-neighbor sampling with anti-aliasing
vec3 pixel_perfect(vec2 uv) {
    // Calculate the scale factor
    vec2 scale = OutputSize / TextureSize;
    
    // Find the nearest pixel center
    vec2 pixel = uv * TextureSize;
    vec2 rounded = floor(pixel) + 0.5;
    
    // Calculate distance from pixel center
    vec2 dist = abs(pixel - rounded);
    
    // Soft threshold for anti-aliasing at pixel edges
    vec2 aa = smoothstep(0.5, 0.5 - 0.01, dist);
    
    // Sample with offset
    vec2 sample_uv = rounded / TextureSize;
    vec3 color = texture2D(Texture, sample_uv).rgb;
    
    // Apply anti-aliasing at edges
    float edge = aa.x * aa.y;
    
    // Slight darkening at edges for sharpness
    color *= mix(0.95, 1.0, edge);
    
    return color;
}

// Main shader
void main() {
    vec2 uv = texCoord;
    
    // Apply pixel perfect scaling
    vec3 color = pixel_perfect(uv);
    
    // Clamp output
    color = clamp(color, 0.0, 1.0);
    
    gl_FragColor = vec4(color, 1.0);
}
