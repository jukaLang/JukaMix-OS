// LCD Game Boy Effect - GLES 2.0 Compatible
// Green-tinted LCD screen simulation for Game Boy systems
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

// Game Boy palette (classic green)
const vec3 gb_darkest = vec3(0.06, 0.22, 0.06);
const vec3 gb_dark = vec3(0.19, 0.38, 0.19);
const vec3 gb_light = vec3(0.55, 0.67, 0.06);
const vec3 gb_lightest = vec3(0.61, 0.73, 0.06);

// Quantize to 4 colors
vec3 gameboy_color(vec3 color) {
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    
    if (luma < 0.25) return gb_darkest;
    if (luma < 0.50) return gb_dark;
    if (luma < 0.75) return gb_light;
    return gb_lightest;
}

// LCD pixel grid
vec3 lcd_grid(vec2 uv, vec3 color) {
    vec2 pixel = uv * TextureSize;
    vec2 grid = fract(pixel);
    
    // LCD cell effect
    float cell = 0.0;
    if (grid.x < 0.9 && grid.y < 0.9) {
        cell = 1.0;
    }
    
    // Apply LCD grid darkening
    return color * mix(0.85, 1.0, cell);
}

// Main shader
void main() {
    vec2 uv = texCoord;
    
    // Sample texture with nearest neighbor for crisp pixels
    vec3 color = texture2D(Texture, uv).rgb;
    
    // Apply Game Boy palette
    color = gameboy_color(color);
    
    // Apply LCD grid effect
    color = lcd_grid(uv, color);
    
    // Clamp output
    color = clamp(color, 0.0, 1.0);
    
    gl_FragColor = vec4(color, 1.0);
}
