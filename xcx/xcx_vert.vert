#version 330
/*
this is raylib code not mine fyi
https://github.com/raysan5/raylib/blob/master/examples/shaders/resources/shaders/glsl330/lighting.vs 
 */
in vec3 vertexPosition;
in vec3 vertexTangent;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;
out vec3 fragTangent;

void main()
{
    fragPosition = vec3(matModel*vec4(vertexPosition, 1.0));
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    fragNormal = normalize(vec3(matNormal*vec4(vertexNormal, 1.0)));
    fragTangent = normalize(vec3(matNormal*vec4(vertexTangent, 1.0)));
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}