#version 330 
// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec3 fragNormal;
in vec3 fragTangent;
in vec4 fragColor;
in vec3 fragPosition;
in vec4 realFragPosition;

// Input uniform values
uniform sampler2D texture0;//0 diffuse
uniform sampler2D texture1;//1  normal
uniform sampler2D texture2;//2 light_depth

//uniform float roughness; 
//uniform float metallic;
uniform vec4 colDiffuse;
uniform vec3 light_direction;
uniform int is_depth_pass;
uniform vec3 light_pos;
uniform mat4 light_matrix;
uniform vec3 view_pos;
// Output fragment color
out vec4 finalColor;

// NOTE: Add your custom variables here
const float depth_scale = 1;
void depth_pass(){
    finalColor = vec4(1.);
}
vec4 transform_to_light_space(vec3 pos){
    vec4 frag_pos_light_space = light_matrix*vec4(fragPosition, 1);
    frag_pos_light_space.xyz /= frag_pos_light_space.w; 
    frag_pos_light_space.xyz = (frag_pos_light_space.xyz + 1.0)/2.0; 
    //frag_pos_light_space.z = distance(pos, light_pos)/1000.;
    return frag_pos_light_space;
}

float point_can_see_light_mul(vec3 point){
    {
        bool behind_cam = false;
        vec3 d1 = normalize(fragPosition-view_pos);
        vec3 d2 = normalize(light_pos-fragPosition);
        if(dot(d1, d2)>0.){
            return 1.;
        }
    }
    vec4 frag_pos_light_space = transform_to_light_space(point);
    vec2 sample_coords = frag_pos_light_space.xy;
    float cur_depth = frag_pos_light_space.z;
    float bias = max(0.0002*(1.0 - dot(fragNormal, -light_direction)), 0.00002) + 0.00001;
    int shadow_counter = 0;
    const int dx = 4;
    const int num_samples = (dx*2+1)*(dx*2+1);
    vec2 texel_size = vec2(1.0/float(1024));
    for (int x = -dx; x <= dx; x++)
    {
        for (int y = -dx; y <= dx; y++)
        {
            float sample_depth = texture(texture2, sample_coords + texel_size*vec2(x, y)).r;
            if (cur_depth - bias > sample_depth) {
                shadow_counter++;
            };
        }
    } 
    float outv = 1-float(shadow_counter)/float(num_samples);
    return outv;
}

void ordinary_pass(){
    vec4 texelColor = texture(texture0,fragTexCoord);
    vec4 base_color = texelColor*colDiffuse*fragColor; 
    float alpha = base_color.a;
    float light_mul = clamp(dot(fragNormal,-normalize(light_direction)), 0,1);
    light_mul*= point_can_see_light_mul(fragPosition);
    float mul = light_mul*0.8+0.2;
    finalColor = base_color*mul;
    finalColor.a = alpha;
}

void main()
{
    if (is_depth_pass == 1){
        depth_pass();
    }else{
       ordinary_pass();
    }
}