shader_type canvas_item;

uniform vec4 color : source_color = vec4(1.0, 0.4, 0.0, 0.5);
uniform float speed = 1.0;
uniform float distortion = 0.1;

void fragment() {
    float noise = sin(UV.y * 10.0 + TIME * speed) * distortion;
    vec2 distorted_uv = UV + vec2(noise, -TIME * 0.2);
    
    // Simple gradient fade up
    float alpha_fade = 1.0 - UV.y;
    
    // Color mixing
    vec4 c = color;
    c.a *= alpha_fade;
    
    COLOR = c;
}
