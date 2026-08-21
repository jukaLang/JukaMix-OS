// Sharp Bilinear - GLES 2.0 Optimized
// Clean bilinear filtering with sharpness control
// Great for systems with mixed pixel art and smooth graphics

#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D Texture;
uniform vec2 InputSize;
uniform vec2 OutputSize;
uniform vec2 TextureSize;

varying vec2 texCoord;

// Sharpness factor (0.0 = smooth, 1.0 = sharp)
const float SHARPNESS = 0.5;

void main() {
    vec2 uv = texCoord;
    vec2 texel_size = 1.0 / TextureSize;
    
    // Get pixel position
    vec2 pixel = uv * TextureSize;
    vec2 pixel_fract = fract(pixel);
    
    // Sample 2x2 grid
    vec2 sample_pos = floor(pixel) * texel_size;
    
    vec3 c00 = texture2D(Texture, sample_pos).rgb;
    vec3 c10 = texture2D(Texture, sample_pos + vec2(texel_size.x, 0.0)).rgb;
    vec3 c01 = texture2D(Texture, sample_pos + vec2(0.0, texel_size.y)).rgb;
    vec3 c11 = texture2D(Texture, sample_pos + texel_size).rgb;
    
    // Sharp bilinear: weight samples based on distance and sharpness
    vec2 weight = pixel_fract;
    weight = mix(weight, smoothstep(0.0, 1.0, weight), SHARPNESS);
    
    vec3 color = mix(
        mix(c00, c10, weight.x),
        mix(c01, c11, weight.x),
        weight.y
    );
    
    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
