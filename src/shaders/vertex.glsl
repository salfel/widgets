#version 330 core
layout(location = 0) in vec2 aPos;

out vec2 Position;

uniform mat4 MVP;

void main()
{
    gl_Position = MVP * vec4(aPos, 0.0, 1.0);
    Position = aPos;
}
