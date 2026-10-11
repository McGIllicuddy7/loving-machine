#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;
in vec3 fragTangent;
uniform sampler2D texture0;

uniform vec4 colDiffuse;
uniform vec4 colEmmisive;

uniform int material;
uniform float specularity;

const int MATERIAL_PLASTIC = 0;
const int MATERIAL_METAL = 1;
const int MATERIAL_GLASS = 2;
const int MATERIAL_SCREEN = 3;

out vec4 finalColor;

uniform float render_width;
uniform float render_height;

uniform vec3 input_light_pos;
uniform vec4 input_light_color;
uniform int rendering_depth_mode;

uniform vec3 camera_position;

vec3 calculate_normal(vec3 base, vec2 frag_coord, vec3 frag_position);
vec4 calculate_color(vec3 base, vec2 frag_coord, vec3 frag_position);

float tile_height(vec2 coordinate, float scale_x, float scale_y, float height);
float cnoise(vec2 P);
vec3 rotated_normal(vec3 normal_base);
vec3 normal_from_bump(float epsilon,float height, float x_minus, float x_plus, float y_minus, float y_plus);

vec3 tile_normal(vec2 coordinate, float scale_x, float scale_y, float height);

vec3 calculate_normal(vec3 base, vec2 frag_coord, vec3 frag_position){
    return tile_normal(frag_coord, 5., 10.0, 10.);
}

vec4 calculate_color(vec4 base, vec2 frag_coord, vec3 frag_position){
    return base;
}

vec4 calculate_lighting(vec4 base_color, vec3 normal){
    vec4 outp;
    vec3 delta = (input_light_pos-fragPosition);
    float distance = length(delta);
    if(distance<0.01){
        distance = 0.01;
    }
    distance = sqrt(distance);
    vec3 dnormalized = delta/distance;
    float incoming_scaler = dot(dnormalized, normal)/(distance);
    incoming_scaler+= 0.05;
    vec4 light = input_light_color*incoming_scaler;
    outp.r = light.r*base_color.r;
    outp.g = light.g*base_color.g;
    outp.b = light.b*base_color.b;
    outp += colEmmisive;
    return outp;
}

void main() {
    float base_alpha = colDiffuse.a;
    vec3 normal = calculate_normal(fragNormal, fragTexCoord, fragPosition);
    vec4 col = calculate_color(colDiffuse, fragTexCoord, fragPosition);
    vec4 output_color = calculate_lighting(col, normal);
    output_color.a = base_alpha;
    finalColor = output_color;
}




float tile_height(vec2 coordinate, float scale_x, float scale_y, float height){
    float tmp;
    coordinate.x *= scale_x;
    coordinate.y *= scale_y;
    float fx = abs(fract(coordinate.x));
    float fy = abs(fract(coordinate.y));
    float ds = 0.025;
    if (fx<ds || fy < ds|| fx> 1.-ds || fy >1.- ds){
        return 0.;
    }else{
        return 1.*height;
    }
}

vec3 rotated_normal(vec3 normal_base){
    vec3 z_hat = fragNormal;
    vec3 x_hat = fragTangent;
    vec3 y_hat = cross(z_hat, x_hat);
    vec3 outv =x_hat*normal_base.x+y_hat*normal_base.y+z_hat*normal_base.z;
    return normalize(outv);
}

vec3 normal_from_bump(float epsilon,float height, float x_minus, float x_plus, float y_minus, float y_plus){
    float dx1 = height-x_minus;
    float dx2 = x_plus-height;
    float dy1 = height-y_minus;
    float dy2 = y_plus-height;
    float dx_avg = (dx1+dx2)/2. ;
    float dy_avg = (dy1+dy2)/2.;
    vec3 tan_x = normalize(vec3(epsilon, 0., dx_avg/(epsilon)));
    vec3 tan_y = normalize(vec3(0.,epsilon, dy_avg/epsilon));
    return normalize(cross(tan_x, tan_y));
}

vec3 tile_normal(vec2 coordinate, float scale_x, float scale_y, float height){
    float epsilon = 0.001;
    vec2 dx = vec2(epsilon, 0.);
    vec2 dy = vec2(0., epsilon);
    float height_0 =  tile_height(coordinate, scale_x, scale_y, height);
    float x_minus =  tile_height(coordinate-dx, scale_x, scale_y,height);
    float x_plus =  tile_height(coordinate+dx, scale_x, scale_y,height);
    float y_minus =  tile_height(coordinate-dy, scale_x, scale_y,height);
    float y_plus =  tile_height(coordinate+dy, scale_x, scale_y,height);
    return rotated_normal(normal_from_bump(epsilon, height_0, x_minus, x_plus, y_minus,y_plus));
}
//https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
vec4 permute(vec4 x);

vec2 fade(vec2 t) {return t*t*t*(t*(t*6.0-15.0)+10.0);}

vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}

float cnoise(vec2 P){
  vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
  vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
  Pi = mod(Pi, 289.0); // To avoid truncation effects in permutation
  vec4 ix = Pi.xzxz;
  vec4 iy = Pi.yyww;
  vec4 fx = Pf.xzxz;
  vec4 fy = Pf.yyww;
  vec4 i = permute(permute(ix) + iy);
  vec4 gx = 2.0 * fract(i * 0.0243902439) - 1.0; // 1/41 = 0.024...
  vec4 gy = abs(gx) - 0.5;
  vec4 tx = floor(gx + 0.5);
  gx = gx - tx;
  vec2 g00 = vec2(gx.x,gy.x);
  vec2 g10 = vec2(gx.y,gy.y);
  vec2 g01 = vec2(gx.z,gy.z);
  vec2 g11 = vec2(gx.w,gy.w);
  vec4 norm = 1.79284291400159 - 0.85373472095314 * 
    vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11));
  g00 *= norm.x;
  g01 *= norm.y;
  g10 *= norm.z;
  g11 *= norm.w;
  float n00 = dot(g00, vec2(fx.x, fy.x));
  float n10 = dot(g10, vec2(fx.y, fy.y));
  float n01 = dot(g01, vec2(fx.z, fy.z));
  float n11 = dot(g11, vec2(fx.w, fy.w));
  vec2 fade_xy = fade(Pf.xy);
  vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
  float n_xy = mix(n_x.x, n_x.y, fade_xy.y);
  return 2.3 * n_xy;
}
