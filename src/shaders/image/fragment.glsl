#version 330 core
out vec4 FragColor;

in vec2 Position;

uniform sampler2D tex;
uniform float opacity;

void main()
{
    vec4 color = texture(tex, Position);
    FragColor = vec4(color.rgb, color.a * opacity);
}
