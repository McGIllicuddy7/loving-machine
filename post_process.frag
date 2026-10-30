#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
flat in int instanceId;
// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec4 palette[256];
// Output fragment color
out vec4 finalColor;

// NOTE: Add your custom variables here
float b_dist_square(vec4 a, vec4 b){
    return distance(a.rgb, b.rgb);
}

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);
     // NOTE: Implement here your fragment shader code

    // final color is the color from the texture
    //    times the tint color (colDiffuse)
    //    times the fragment color (interpolated vertex color)
    vec4 base = texelColor*colDiffuse*fragColor;
    float min_dist;
    vec4 outv = palette[0];
    min_dist =b_dist_square(base, palette[0]);
    for(int i  = 1; i<255; i++){
        float dist= b_dist_square(base, palette[i]);
        if (dist<=min_dist){
            min_dist = dist ;
            outv = palette[i];
        }
    }
    int d = int(base.r*255)%256;
    //finalColor = palette[int(abs(fragTexCoord.x)*16+abs(fragTexCoord.y)*256)%256];
    //finalColor.a = 1;
    finalColor = outv;
    finalColor.a = 1;
    //finalColor = base;
}