#version 330 core
out vec4 FragColor;

in vec2 Position;

uniform vec2 size;
uniform vec4 color;
uniform vec3 border_color;
uniform float border_width;
uniform float border_radius;

void main()
{
    FragColor = color;

    vec2 pos = Position * size;

    if (border_radius > 0) {
        vec2 cornerPos = pos;
        cornerPos.x = (pos.x > size.x * 0.5) ? size.x - pos.x : pos.x;
        cornerPos.y = (pos.y > size.y * 0.5) ? size.y - pos.y : pos.y;

        vec2 centerPos = vec2(border_radius, border_radius);

        float distance2 = pow(cornerPos.y - centerPos.y, 2) + pow(cornerPos.x - centerPos.x, 2);
        float radius2 = pow(border_radius, 2);
        if (cornerPos.x < border_radius && cornerPos.y < border_radius) {
            if (distance2 > radius2) {
                FragColor = vec4(1.0, 0.0, 0.0, 0.0);
                return;
            } else if (border_width > 0 && distance2 < radius2 && distance2 >= pow(border_radius - border_width, 2)) {
                FragColor = vec4(border_color, 1.0);
                return;
            }
        }
    }

    if (border_width == 0) {
        return;
    }

    float distToEdgeY = min(pos.x, size.x - pos.x);
    float distToEdgeX = min(pos.y, size.y - pos.y);
    float distToEdge = min(distToEdgeX, distToEdgeY);

    if (distToEdge <= border_width) {
        FragColor = vec4(border_color, 1.0);
    }
}
