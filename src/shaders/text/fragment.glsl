#version 330 core
out vec4 FragColor;

in vec2 Position;

uniform sampler2D tex;
uniform vec3 color;

void main()
{
    vec4 color = vec4(color, texture(tex, Position).r);

    FragColor = color;
}
