shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.0, 0.4, 0.8, 0.5);
uniform float speed = 0.5;

void fragment() {
    float wave = sin(UV.y * 20.0 + TIME * speed) * 0.02;
    float wave2 = cos(UV.x * 10.0 - TIME * speed * 0.5) * 0.02;
    
    // Mix solid color with transparency
    vec4 c = color;
    c.a = 0.3 + (wave + wave2) * 2.0;
    
    COLOR = c;
}
