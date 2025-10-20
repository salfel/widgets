#version 330 core
out vec4 FragColor;

in vec2 Position;

uniform sampler2D tex;
uniform vec4 color;

void main()
{
    vec4 color = vec4(color.xyz, texture(tex, Position).r * color.w);

    FragColor = color;
}
