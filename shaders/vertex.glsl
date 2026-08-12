#version 410 core

layout (location = 0) in vec4 vertex;

out vec2 v_TexCoord;

uniform mat4 proj;

void main() {
    gl_Position = proj * vec4(vertex.xy, 0.0, 1.0);
    v_TexCoord = vertex.zw;
};
