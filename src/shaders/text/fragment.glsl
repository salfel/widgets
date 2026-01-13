#version 330 core
out vec4 FragColor;

in vec2 Position;

uniform sampler2D tex;
uniform vec4 color;
uniform vec4 background_color;

void main()
{
    vec4 color = vec4(color.rgb, texture(tex, Position).a * color.a);

    FragColor = mix(background_color, color, color.a);
}
