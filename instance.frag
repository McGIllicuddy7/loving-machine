#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
flat in int instanceId;
// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform vec3 light_direction;

uniform vec3 light_color;
uniform vec4 colors[1000];
// Output fragment color
out vec4 finalColor;

// NOTE: Add your custom variables here

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 col = colors[instanceId];
     // NOTE: Implement here your fragment shader code

    // final color is the color from the texture
    //    times the tint color (colDiffuse)
    //    times the fragment color (interpolated vertex color)
    finalColor = texelColor*col*fragColor;
}