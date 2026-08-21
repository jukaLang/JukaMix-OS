// CRT NTSC Composite - GLES 2.0 Optimized
// Authentic NTSC TV look with proper signal processing
// Tuned for Mali GPU on TrimUI devices

#ifdef GL_ES
precision mediump float;
#endif

#define PI 3.141592654
#define TAU 6.283185307

uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

varying vec2 texCoord;

// NTSC signal weights (BT.601)
const vec3 YUV_WEIGHTS = vec3(0.299, 0.587, 0.114);
const vec3 R_Y = vec3(1.0, 0.0, 1.13983);
const vec3 G_Y = vec3(1.0, -0.39465, -0.58060);
const vec3 B_Y = vec3(1.0, 2.03211, 0.0);

// RGB to YUV
vec3 rgb2yuv(vec3 rgb) {
    float y = dot(rgb, YUV_WEIGHTS);
    float u = (rgb.b - y) * 0.492;
    float v = (rgb.r - y) * 0.877;
    return vec3(y, u, v);
}

// YUV to RGB
vec3 yuv2rgb(vec3 yuv) {
    return vec3(
        dot(yuv, R_Y),
        dot(yuv, G_Y),
        dot(yuv, B_Y)
    );
}

// Noise function
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// NTSC composite simulation
vec3 ntsc_composite(vec2 uv) {
    vec3 color = texture2D(Texture, uv).rgb;
    
    // Convert to YUV
    vec3 yuv = rgb2yuv(color);
    
    // Add subtle noise (NTSC artifact)
    float noise = rand(uv + fract(0.0)) * 0.02 - 0.01;
    yuv.x += noise;
    
    // Cross-color artifact (slight color bleed)
    float offset = 0.25 / TextureSize.x;
    vec3 colorR = texture2D(Texture, uv + vec2(offset, 0.0)).rgb;
    vec3 colorB = texture2D(Texture, uv - vec2(offset, 0.0)).rgb;
    
    yuv.y += (rgb2yuv(colorR).y - yuv.y) * 0.15;
    yuv.z += (rgb2yuv(colorB).z - yuv.z) * 0.15;
    
    // Scanlines
    float scanline = sin(uv.y * OutputSize.y * PI) * 0.5 + 0.5;
    scanline = pow(scanline, 1.8) * 0.15 + 0.85;
    yuv.x *= scanline;
    
    // Convert back to RGB
    color = yuv2rgb(yuv);
    
    // Slight saturation boost (NTSC characteristic)
    float luma = dot(color, YUV_WEIGHTS);
    color = mix(vec3(luma), color, 1.15);
    
    return clamp(color, 0.0, 1.0);
}

void main() {
    gl_FragColor = vec4(ntsc_composite(texCoord), 1.0);
}
