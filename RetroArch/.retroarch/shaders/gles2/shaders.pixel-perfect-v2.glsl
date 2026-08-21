// Pixel Perfect V2 - GLES 2.0 Optimized
// Sharp integer scaling with edge anti-aliasing
// Tuned for Mali GPU on TrimUI devices

#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

varying vec2 texCoord;

// Soft step for anti-aliasing
float soft_step(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

void main() {
    vec2 uv = texCoord;
    
    // Scale factors
    vec2 scale = OutputSize / TextureSize;
    
    // Pixel coordinates
    vec2 pixel = uv * TextureSize;
    vec2 pixel_floor = floor(pixel);
    vec2 pixel_fract = fract(pixel);
    
    // Sample the four nearest texels
    vec2 texel_size = 1.0 / TextureSize;
    vec2 sample_pos = (pixel_floor + 0.5) * texel_size;
    
    vec3 c00 = texture2D(Texture, sample_pos).rgb;
    vec3 c10 = texture2D(Texture, sample_pos + vec2(texel_size.x, 0.0)).rgb;
    vec3 c01 = texture2D(Texture, sample_pos + vec2(0.0, texel_size.y)).rgb;
    vec3 c11 = texture2D(Texture, sample_pos + texel_size).rgb;
    
    // Check if we're at an edge (different colors)
    float edge_h = length(c00 - c10) + length(c01 - c11);
    float edge_v = length(c00 - c01) + length(c10 - c11);
    float edge = max(edge_h, edge_v);
    
    // Bilinear interpolation
    vec3 bilinear = mix(mix(c00, c10, pixel_fract.x), mix(c01, c11, pixel_fract.x), pixel_fract.y);
    
    // Nearest neighbor (sharp pixels)
    vec3 nearest = c00;
    
    // At edges, blend slightly for anti-aliasing
    float aa_amount = soft_step(0.0, 0.3, edge) * 0.15;
    vec3 color = mix(nearest, bilinear, aa_amount);
    
    // Slight edge darkening for crispness
    color *= 1.0 - edge * 0.02;
    
    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
