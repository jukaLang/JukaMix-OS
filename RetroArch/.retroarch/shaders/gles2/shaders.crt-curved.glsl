// CRT Curved - GLES 2.0 Compatible
// CRT simulation with barrel distortion and scanlines
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

// CRT parameters
uniform float CRTCurvature;
uniform float CRTScanline;

// Barrel distortion for CRT curvature
vec2 barrel_distortion(vec2 uv, float amount) {
    vec2 center = uv - 0.5;
    float dist = length(center);
    float distortion = 1.0 + amount * dist * dist;
    return center * distortion + 0.5;
}

// RGB chromatic aberration
vec3 chromatic_aberration(vec2 uv, float amount) {
    vec2 dir = uv - 0.5;
    float dist = length(dir);
    
    vec2 offset = dir * amount * dist;
    
    float r = texture2D(Texture, uv + offset * 0.01).r;
    float g = texture2D(Texture, uv).g;
    float b = texture2D(Texture, uv - offset * 0.01).b;
    
    return vec3(r, g, b);
}

// Scanline effect
float scanline(vec2 uv, float intensity) {
    float y = uv.y * OutputSize.y;
    float scan = sin(y * PI * 2.0) * 0.5 + 0.5;
    return mix(1.0 - intensity, 1.0, scan);
}

// Phosphor glow
vec3 phosphor_glow(vec3 color, vec2 uv) {
    // Simple bloom effect
    vec3 bloom = vec3(0.0);
    float samples = 4.0;
    
    for (float i = -samples; i <= samples; i += 1.0) {
        for (float j = -samples; j <= samples; j += 1.0) {
            vec2 offset = vec2(i, j) / OutputSize * 2.0;
            bloom += texture2D(Texture, uv + offset).rgb;
        }
    }
    
    bloom /= (samples * 2.0 + 1.0) * (samples * 2.0 + 1.0);
    return color + bloom * 0.15;
}

// Vignette
vec3 vignette(vec2 uv, vec3 color) {
    vec2 center = uv - 0.5;
    float dist = length(center);
    float vig = 1.0 - dot(dist, dist) * 0.7;
    return color * vig;
}

// Main shader
void main() {
    vec2 uv = texCoord;
    
    // Apply barrel distortion for CRT curvature
    float curvature = CRTCurvature > 0.0 ? CRTCurvature : 0.15;
    uv = barrel_distortion(uv, curvature);
    
    // Check if outside CRT bounds
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    // Apply chromatic aberration
    vec3 color = chromatic_aberration(uv, 0.5);
    
    // Apply scanlines
    float scan_intensity = CRTScanline > 0.0 ? CRTScanline : 0.25;
    color *= scanline(uv, scan_intensity);
    
    // Apply phosphor glow
    color = phosphor_glow(color, uv);
    
    // Apply vignette
    color = vignette(uv, color);
    
    // Gamma correction
    color = pow(color, vec3(0.95));
    
    // Clamp output
    color = clamp(color, 0.0, 1.0);
    
    gl_FragColor = vec4(color, 1.0);
}
