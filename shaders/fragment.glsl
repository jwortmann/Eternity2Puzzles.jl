#version 410 core

layout (location = 0) out vec4 color;

in vec2 v_TexCoord;

uniform sampler2D u_TextureSampler;

void main() {
    color = texture(u_TextureSampler, v_TexCoord);
};
