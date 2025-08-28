#version 330 core
out vec4 FragColor;

in vec2 TexCoords;

uniform sampler2D screenTexture;
uniform bool horizontal;

const float weight[3] = float[](0.5, 0.2, 0.05);

void main()
{
    int len = 3;
    vec2 tex_offset = 1.0 / textureSize(screenTexture, 0); // size of one texel
    vec3 result = texture(screenTexture, TexCoords).rgb * weight[0];

    if (horizontal) {
        for (int i = 1; i < len; ++i) {
            result += texture(screenTexture, TexCoords + vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
            result += texture(screenTexture, TexCoords - vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
        }
    } else {
        for (int i = 1; i < len; ++i) {
            result += texture(screenTexture, TexCoords + vec2(0.0, tex_offset.y * i)).rgb * weight[i];
            result += texture(screenTexture, TexCoords - vec2(0.0, tex_offset.y * i)).rgb * weight[i];
        }
    }

    FragColor = vec4(result, 1.0);
}
