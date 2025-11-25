#version 330 core
out vec4 FragColor;

in vec2 Position;

uniform vec2 size;
uniform vec4 background;
uniform sampler2D background_image;
uniform int has_background_image;
uniform vec4 border_color;
uniform float border_width;
uniform float border_radius;
uniform int is_stencil;

void main()
{
    vec2 pos = Position * size;

    vec2 cornerPos = pos;
    cornerPos.x = (pos.x > size.x * 0.5) ? size.x - pos.x : pos.x;
    cornerPos.y = (pos.y > size.y * 0.5) ? size.y - pos.y : pos.y;

    bool inside = true;

    if (border_radius > 0.0 && cornerPos.x < border_radius && cornerPos.y < border_radius) {
        float dist2 = (cornerPos.x - border_radius) * (cornerPos.x - border_radius) +
                (cornerPos.y - border_radius) * (cornerPos.y - border_radius);
        if (dist2 > border_radius * border_radius) {
            inside = false;
        }
    }

    if (!inside) {
        discard;
    }

    float distToEdgeY = min(pos.x, size.x - pos.x);
    float distToEdgeX = min(pos.y, size.y - pos.y);
    float distToEdge = min(distToEdgeX, distToEdgeY);

    bool isBorder = false;

    if (border_width > 0.0) {
        if (border_radius > 0.0 && cornerPos.x < border_radius && cornerPos.y < border_radius) {
            float distance2 = (cornerPos.x - border_radius) * (cornerPos.x - border_radius) +
                    (cornerPos.y - border_radius) * (cornerPos.y - border_radius);
            float radius2 = border_radius * border_radius;
            float innerRadius = max(border_radius - border_width, 0);
            if (distance2 <= radius2 && distance2 >= innerRadius * innerRadius) {
                isBorder = true;
            }
        } else if (distToEdge <= border_width) {
            isBorder = true;
        }
    }

    if (is_stencil == 1) {
        if (isBorder) {
            discard;
        }
    } else {
        if (isBorder) {
            FragColor = border_color;
        } else {
            if (has_background_image == 1) {
                FragColor = texture(background_image, Position * (size - 2 * border_width) / size - border_width / size);
            } else {
                FragColor = background;
            }
        }
    }
}
