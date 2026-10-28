#version 330 core 

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec3 fragNormal;
in vec3 fragTangent;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;//0 diffuse
uniform sampler2D texture1;//1  normal
uniform sampler2D texture2;//2 light_depth

//uniform float roughness; 
//uniform float metallic;
uniform vec4 colDiffuse;
uniform vec3 light_direction;
// Output fragment color
out vec4 finalColor;

// NOTE: Add your custom variables here

void main()
{
    texture0;
    texture1;
    texture2;
   // roughness;
    //metallic;
    colDiffuse;
    light_direction;

    // Texel color fetching from texture sampler
    // 
    vec4 texelColor = texture(texture2,fragTexCoord);
    finalColor = texelColor;
    /*
    vec4 base_color = texelColor*colDiffuse*fragColor; 
    float alpha = base_color.a;
    float mul = clamp(dot(fragNormal, light_direction), 0,1)*0.75+0.25;
    finalColor = base_color*mul;
    finalColor.a = alpha;*/
}