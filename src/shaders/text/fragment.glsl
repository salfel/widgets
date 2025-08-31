#version 330 core
out vec4 FragColor;

in vec2 Position;

uniform sampler2D tex;

void main()
{
    vec4 color = vec4(0.0, 0.0, 0.0, texture(tex, Position).r);

    FragColor = color;
}
