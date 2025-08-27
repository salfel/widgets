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

    vec2 topLeft = vec2(border_radius, border_radius);
    vec2 bottomLeft = vec2(border_radius, size.y - border_radius);
    vec2 topRight = vec2(size.x - border_radius, border_radius);
    vec2 bottomRight = vec2(size.x - border_radius, size.y - border_radius);

    if (border_radius > 0 &&
            (pos.x <= topLeft.x && pos.y <= topLeft.y && length(abs(pos - topLeft)) >= border_radius) ||
            (pos.x <= bottomLeft.x && pos.y >= bottomLeft.y && length(abs(pos - bottomLeft)) >= border_radius) ||
            (pos.x >= topRight.x && pos.y <= topRight.y && length(abs(pos - topRight)) >= border_radius) ||
            (pos.x >= bottomRight.x && pos.y >= bottomRight.y && length(abs(pos - bottomRight)) >= border_radius)
    ) {
        FragColor = vec4(1.0, 0.0, 0.0, 0.0);
        return;
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
