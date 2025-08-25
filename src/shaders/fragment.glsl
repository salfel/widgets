#version 330 core
out vec4 FragColor;

in vec2 Position;

uniform vec4 color;
uniform vec3 border_color;
uniform float border_width;
uniform vec2 size;

void main()
{
    vec2 pos = Position * size;

    float distToEdge = min(min(pos.x, size.x - pos.x),
            min(pos.y, size.y - pos.y));

    if (distToEdge <= border_width) {
        FragColor = vec4(border_color, 1.0);
    } else {
        FragColor = color;
    }
}
