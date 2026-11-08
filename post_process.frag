#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
flat in int instanceId;
// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
// Output fragment color
out vec4 finalColor;

// NOTE: Add your custom variables here

float dither(float base, float dither_amount){
    float pw = 2;
    float t0 = pow(base, 1./pw);
    float t1 =float(int(floor(t0*dither_amount)))/dither_amount;
    return pow(t1,pw );
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
    base.r = dither(base.r, 16);
    base.g = dither(base.g, 16);
    base.b = dither(base.b,16);
    finalColor = base;
    //finalColor = base;
}