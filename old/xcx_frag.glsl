#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
out vec4 finalColor;

uniform float render_width;
uniform float render_height;

uniform vec3 input_light_pos;
uniform vec4 input_light_color;
uniform int display_raw;
uniform int display_normals;
const int MATERIAL_KIND_PLASTIC = 1;
const int MATERIAL_KIND_WOOD = 2;
const int MATERIAL_KIND_METAL= 3;
const int MATERIAL_KIND_PAINT= 4;
const int MATERIAL_KIND_LIGHT= 5;
const int MATERIAL_KIND_VOID = 6;
struct PixelData {
    float height;
    float glass_height;
    vec4 color;
    float specular;
    int kind;
};

struct ObjectData {
    float height;
    float glass_height;
    vec3 normal;
    vec4 color;
    float specular;
    int kind;
};

struct Material{
    vec4 color;
    float specular;
    int kind;
};

const float LIGHT_MUL = 3.;
Material BLACK_PLASTIC = Material(vec4(0.01, 0.01, 0.01, 1), 0.05,MATERIAL_KIND_PLASTIC);
Material WHITE_PLASTIC= Material(vec4(0.8, 0.8, 0.8, 1), 0.025, MATERIAL_KIND_PLASTIC);
Material GRAY_PLASTIC= Material(vec4(0.2, 0.2, 0.2, 1), 0.025, MATERIAL_KIND_PLASTIC);
Material  RED_PLASTIC =Material(vec4(0.8, 0.0, 0.0, 1), 0.025, MATERIAL_KIND_PLASTIC);
Material GREEN_PLASTIC=Material(vec4(0.0, 0.8, 0.0, 1), 0.025, MATERIAL_KIND_PLASTIC);
Material BLUE_PLASTIC=Material(vec4(0.0, 0.0, 0.8, 1), 0.025, MATERIAL_KIND_PLASTIC);
Material	BROWN_PLASTIC = Material(vec4(0.4, 0.4, 0.2, 1), 0.025,MATERIAL_KIND_PLASTIC);
Material	BEIGE_PLASTIC = Material(vec4(0.85, 0.85, 0.7, 1), 0.025,MATERIAL_KIND_PLASTIC);
Material	LIGHT_WOOD =  Material(vec4(0.773, 0.651, 0.337, 1.0), 0.05,MATERIAL_KIND_WOOD);
Material	DARK_WOOD =  Material(vec4(0.773*0.6, 0.651*0.6, 0.337*0.6, 1.0), 0.05,MATERIAL_KIND_WOOD);

Material	LIGHT_METAL =Material(vec4(0.6, 0.6, 0.601, 1.), 1.,MATERIAL_KIND_METAL);
Material	DARK_METAL = Material(vec4(0.3, 0.3, 0.305, 1), 1.,MATERIAL_KIND_METAL);
Material	BLACK_PAINT = Material(vec4(0.1, 0.1, 0.1, 1), 0, MATERIAL_KIND_PAINT);
Material	WHITE_PAINT = Material(vec4(1, 1., 1., 1), 0, MATERIAL_KIND_PAINT);
Material	GRAY_PAINT=Material(vec4(0.4, 0.4, 0.4, 1), 0, MATERIAL_KIND_PAINT);
Material	RED_PAINT=Material(vec4(0.8, 0.0, 0.0, 1), 0, MATERIAL_KIND_PAINT);
Material	GREEN_PAINT = Material(vec4(0.0, 0.8, 0.0, 1), 0, MATERIAL_KIND_PAINT);
Material	BLUE_PAINT = Material(vec4(0.0, 0.0, 0.8, 1), 0, MATERIAL_KIND_PAINT);
Material	BROWN_PAINT =  Material(vec4(0.4, 0.4, 0.2, 1), 0, MATERIAL_KIND_PAINT);
Material	BEIGE_PAINT =  Material(vec4(0.9, 0.9, 0.8, 1.0), 0, MATERIAL_KIND_PAINT);
Material	WHITE_LIGHT = Material(vec4(1.0, 1.0, 1.0, 1)*LIGHT_MUL, 0, MATERIAL_KIND_LIGHT);
Material	RED_LIGHT=Material(vec4(1.0, 0.4, 0.4, 1)*LIGHT_MUL, 0, MATERIAL_KIND_LIGHT);
Material	GREEN_LIGHT=Material(vec4(0.4, 1.0, 0.4, 1)*LIGHT_MUL, 0, MATERIAL_KIND_LIGHT);
Material	BLUE_LIGHT=Material(vec4(0.4, 0.4, 1.0, 1)*LIGHT_MUL, 0, MATERIAL_KIND_LIGHT);
Material	PINK_LIGHT=Material(vec4(1.0, 0.8, 0.8, 1)*LIGHT_MUL, 0, MATERIAL_KIND_LIGHT);
Material	ORANGE_LIGHT=Material(vec4(1.0, 0.8, 0.4, 1)*LIGHT_MUL, 0, MATERIAL_KIND_LIGHT);
Material	VOID=Material(vec4(0,0,0,1), 0, MATERIAL_KIND_LIGHT);
Material	VOID_LIGHT=Material(vec4(0.8,0.8,0.8,1), 0, MATERIAL_KIND_VOID);

Material MATERIALS[]  =Material[](
	BLACK_PLASTIC, //0
	WHITE_PLASTIC, //1
	GRAY_PLASTIC, //2
	RED_PLASTIC, //3
	GREEN_PLASTIC, //4
	BLUE_PLASTIC, //5
	BROWN_PLASTIC, //6
	BEIGE_PLASTIC, //7
	LIGHT_WOOD, //8
	DARK_WOOD, //9
	LIGHT_METAL, //10
	DARK_METAL, //11
	BLACK_PAINT, //12
	WHITE_PAINT, //13
	GRAY_PAINT, //14
	RED_PAINT, //15
	GREEN_PAINT, //16
	BLUE_PAINT, //17
	BROWN_PAINT, //18
	BEIGE_PAINT, //19
	WHITE_LIGHT, //20
	RED_LIGHT, //21
	GREEN_LIGHT, //22
	BLUE_LIGHT, //23
	PINK_LIGHT, //24
	ORANGE_LIGHT, //25
	VOID,
	VOID_LIGHT
);
Material v_parse_material(int idx){
    return MATERIALS[idx%MATERIALS.length()];
}

vec3 get_camera_position(){
    return vec3(float(render_width)/2, float(render_height)/2, 50);
}

float hash(vec2 uv)
{
    return fract(sin(7.289 * uv.x + 11.23 * uv.y) * 23758.5453);
}

float hash_point(int x, int y){
    return hash(vec2(float(x), float(y)));
}
vec4 process_object_color_at(vec4 base_color, int kind, int pos_x, int pos_y){
    vec4 cout=  base_color;
    if(kind == MATERIAL_KIND_PLASTIC){
        float scale = 1.;
        float noise_v = 0.01;
        float sign_v = 0.00;
        float base = (1-noise_v-sign_v);
        float v = hash_point(pos_x, pos_y);
        float s  =(sin((float(pos_x)*v)/scale)+1)/4+(sin((float(pos_y)*sin(v+1))/scale)+1)/4;
        cout *= (base+v*noise_v+s*sign_v);
    }else if(kind == MATERIAL_KIND_WOOD){
        float scale = 5.;
        float noise_v = 0.05;
        float sign_v = 0.4;
        float base = (1-noise_v-sign_v);
        float v = hash_point(pos_x/10, pos_y/10)*0.8+ hash_point(pos_x/2, pos_y/2)*0.2;
        float s  =(sin((float(pos_x)*v)/scale)+1)/4+(sin((float(pos_y)*sin(v+1))/scale)+1)/4;
        cout *= (base+v*noise_v+s*sign_v);
    }else if(kind == MATERIAL_KIND_METAL){
        float scale = 1.;
        float noise_v = 0.12;
        float sign_v = 0.01;
        float base = (1-noise_v-sign_v);
        float v = hash_point(pos_x, pos_y);
          float s  =(sin((float(pos_x)*v)/scale)+1)/4+(sin((float(pos_y)*sin(v+1))/scale)+1)/4;
        cout *= (base+v*noise_v+s*sign_v);
    }else if(kind == MATERIAL_KIND_PAINT){
        float scale = 1.;
        float noise_v = 0.01;
        float sign_v = 0.0;
        float base = (1-noise_v-sign_v);
        float v = hash_point(pos_x, pos_y);
        float s  =(sin((float(pos_x)*v)/scale)+1)/4+(sin((float(pos_y)*sin(v+1))/scale)+1)/4;
        cout *= (base+v*noise_v+s*sign_v);
    }else if(kind == MATERIAL_KIND_LIGHT){
        float scale = 20.;
        float noise_v = 0.0;
        float sign_v = 0.0;
        float base = (1-noise_v-sign_v);
        float v = hash_point(pos_x, pos_y);
          float s  =(sin((float(pos_x)*v)/scale)+1)/4+(sin((float(pos_y)*sin(v+1))/scale)+1)/4;
        cout *= (base+v*noise_v+s*sign_v);
    }else{

    }
    return cout;
}

vec3 process_object_normal_at(vec3 base_normal, int kind, int pos_x, int pos_y){
    vec3 cout =  base_normal;
    if(kind == MATERIAL_KIND_PLASTIC){
        int dv = 1;
        int x = pos_x /dv;
        int y = pos_y/dv;
        float mul = 0.01;
        float dx = hash_point(x/dv, y/dv)*2-1;
        float dy = hash_point(x+int(dx*10), y+int(dx*3))*2-1; 
        float dz = hash_point(x+int(dy*7), y+int(dy*5))*2-1;  
        vec3 pos = vec3(dx,dy,dz)*mul;
        cout+= pos;
    }else if(kind == MATERIAL_KIND_WOOD){
        int dv = 2;
        int x = pos_x /dv;
        int y = pos_y/dv;
        float mul = 0.05;
        float dx = hash_point(x/dv, y/dv)*2-1;
        float dy = hash_point(x+int(dx*10), y+int(dx*3))*2-1; 
        float dz = hash_point(x+int(dy*7), y+int(dy*5))*2-1;  
        vec3 pos = vec3(dx,dy,dz)*mul;
        cout+= pos;
    }else if(kind == MATERIAL_KIND_METAL){
        int dv = 1;
        int x = pos_x /dv;
        int y = pos_y/dv;
        float mul = 0.01;
        float dx = hash_point(x/dv, y/dv)*2-1;
        float dy = hash_point(x+int(dx*10), y+int(dx*3))*2-1; 
        float dz = -abs(hash_point(x+int(dy*7), y+int(dy*5))*2-1);  
        vec3 pos = vec3(dx,dy,dz)*mul;
        cout+= pos;
    }else if(kind == MATERIAL_KIND_PAINT){
        int dv = 1;
        int x = pos_x /dv;
        int y = pos_y/dv;
        float mul = 0.04;
        float dx = hash_point(x/dv, y/dv);
        float dy = hash_point(x+int(dx*10), y+int(dx*3))*2-1; 
        float dz = abs(hash_point(x+int(dy*7), y+int(dy*5))*2-1);  
        vec3 pos = vec3(dx,dy,dz)*mul;
        cout+= pos;
    }else if(kind == MATERIAL_KIND_LIGHT){
        int dv = 2;
        int x = pos_x /dv;
        int y = pos_y/dv;
        float mul = 0.1;
        float dx = hash_point(x/dv, y/dv)*2-1;
        float dy = hash_point(x+int(dx*10), y+int(dx*3))*2-1; 
        float dz = hash_point(x+int(dy*7), y+int(dy*5))*2-1;  
        vec3 pos = vec3(dx,dy,dz)*mul;
        cout+= pos; 
    }else{

    }
    return normalize(cout);
}

PixelData extract_pixel_data(vec4 col) {
    PixelData outp;
    outp.height = col.r / (10.);
    outp.glass_height = col.g;
    Material mat = v_parse_material(int(col.b*255));
    outp.color = mat.color;
    outp.specular = mat.specular;
    outp.kind = mat.kind;
    return outp;
}


PixelData get_pixel_data_at(int x, int y) {
    if (x >= render_width || x < 0 || y >= render_height || y < 0) {
        PixelData outp;
        outp.height = 0;
        outp.glass_height = 0;
        outp.color = vec4(0, 0, 0, 1);
        return outp;
    }
    float dx = float(x) / render_width;
    float dy = float(y) / render_height;
    vec4 t = texture(texture0, vec2(dx, dy));
    return extract_pixel_data(t);
}

ObjectData get_object_data_at(int x, int y) {
    ObjectData outp;
    PixelData base_data = get_pixel_data_at(x, y);
    PixelData dx0 = get_pixel_data_at(x - 1, y);
    PixelData dx1 = get_pixel_data_at(x + 1, y);
    PixelData dy0 = get_pixel_data_at(x, y - 1);
    PixelData dy1 = get_pixel_data_at(x, y + 1);
    float dx = 0.0;
    float dy = 0.0;
    {
        float tx0 = (base_data.height - dx0.height);
        float tx1 = (dx1.height - base_data.height);
        float count = 0.0;
        if (abs(tx0) < 1.) {
            dx += tx0;
            count += 1;
        }
        if (abs(tx1) < 1.) {
            dx += tx1;
            count += 1;
        }
        if (count > 0) {
            dx /= count;
        }
    }
    {
        float ty0 = (base_data.height - dy0.height);
        float ty1 = (dy1.height - base_data.height);
        float count = 0.0;
        if (abs(ty0) < 1.) {
            dy += ty0;
            count += 1;
        }
        if (abs(ty1) < 1.) {
            dy += ty1;
            count += 1;
        }
        if (count > 0) {
            dy /= count;
        }
    }
    vec3 xhat = normalize(vec3(1., 0., dx * 256.));
    vec3 yhat = normalize(vec3(0., 1., dy * 256.));
    vec3 norm = cross(xhat, yhat);
    outp.normal = norm;
    outp.height = base_data.height;
    outp.color = base_data.color;
    outp.glass_height = base_data.glass_height;
    outp.specular = base_data.specular;
    outp.kind = base_data.kind;
    outp.normal = process_object_normal_at(outp.normal, outp.kind, x,y);
    return outp;
}

float specular_light_contribution(vec3 position, vec3 normal){
    vec3 input_light_delta =input_light_pos-
        position ;
    vec3 input_light_direction = -normalize(input_light_delta);
    float spec_mul = 0.;
    vec3 rf = reflect(input_light_direction, normal);
    vec3 d0 = normalize(get_camera_position()-position);
    if (abs(dot(rf, d0))<0.2){
        spec_mul = 2.*(0.3-abs(dot(rf, d0)));
    }
    return spec_mul;
}

vec4 calculate_incident_light(vec3 position, vec3 normal, float directional_obscurance, float specular){
    vec4 outv =input_light_color;
    vec3 input_light_delta =
        position - input_light_pos;
    vec3 input_light_direction = normalize(input_light_delta);
    float dist = length(input_light_direction);
    dist *= dist*1.1;
    vec3 nhat = -normal;
    float mul = dot(nhat, input_light_direction) * directional_obscurance/dist;
    if (mul < 0.0) {
        mul = 0.0;
    }
    float spec_mul = specular_light_contribution(position, normal)*directional_obscurance;
    return outv*mul+(outv*spec_mul)*specular;
}



vec4 handle_materials(ObjectData obj, int pos_x, int pos_y,vec4 base_lighting, float directional_obscurance) {
    vec4 outv = base_lighting;         
    vec4 col = process_object_color_at(obj.color,obj.kind, pos_x, pos_y);
    outv.r *= col.r;
    outv.g *= col.g;
    outv.b *= col.b;   
    if(obj.specular>0.0){
         vec3 pos = vec3(float(pos_x), float(pos_y), obj.height);
        float vs = specular_light_contribution(pos, obj.normal);
        vec4 tmp = calculate_incident_light(pos, obj.normal, directional_obscurance, 1.);  
        outv = tmp*vs*obj.specular+outv*(1.-vs);
    }
    if (obj.glass_height>0.0){
        vec3 pos = vec3(float(pos_x), float(pos_y), obj.height+obj.glass_height);
        float vs = sqrt(specular_light_contribution(pos, obj.normal));
        vec4 tmp = calculate_incident_light(pos, obj.normal, directional_obscurance, 1.);  
        outv = tmp*vs+outv*(1.-vs)*0.8;
    }
    return outv;
}

vec4 calculate_lighting(int pos_x, int pos_y, int inner_radius,
                        int outer_radius) { 
    ObjectData obj = get_object_data_at(pos_x, pos_y);
    if (obj.kind == MATERIAL_KIND_VOID){
        return obj.color;
    }
    vec4 outp = vec4(0.);
    vec3 glare = vec3(0.);
    float directional_obscurance = 1.;
    vec3 input_light_delta =
        vec3(float(pos_x), float(pos_y), obj.height) - input_light_pos;
    vec3 input_light_direction = normalize(input_light_delta);
    vec3 dir = input_light_direction.xyz;
    for (int dy0 = -inner_radius / 2; dy0 <= inner_radius / 2; dy0++) {
        for (int dx0 = -inner_radius / 2; dx0 <= inner_radius / 2; dx0++) {
            int dx = dx0 * 2;
            int dy = dy0 * 2;
            if (dx == 0 && dy == 0) {
                continue;
            }
            float ds = sqrt(dy * dy + dx * dx);
            if (ds > float(inner_radius)) {
                continue;
            }
            PixelData pix = get_pixel_data_at(pos_x + dx, pos_y + dy);
            float dh = (pix.height - obj.height);
            if (dh < 0.) {
                continue;
            } else {
                if (dh > 1.) {
                    dh = 1;
                }
                directional_obscurance -= dh / ds;
                if (directional_obscurance < 0) {
                    break;
                }
            }
            float ds0 = ds;
            ds = ds * ds;
            float mul = 1;
            {
                float dh = (obj.height - pix.height);
                dh = sqrt(dh * dh);
                if (dh > 1.) {
                    dh = 1.;
                }
                mul -= dh;
            }
            if (!(pix.color.r > 1 || pix.color.g > 1 || pix.color.b > 1)) {
                continue;
            }
            if (pix.color.r > 1.) {
                float tmp = pix.color.r / (ds0)*mul;
                glare.r += tmp;
            }
            if (pix.color.g > 1.) {
                float tmp = pix.color.g / (ds0)*mul;
                glare.g += tmp;
            }
            if (pix.color.b > 1.) {
                float tmp = pix.color.b / (ds0)*mul;
                glare.b += tmp;
            }
        }
        if (directional_obscurance < 0) {
            break;
        }
    }
    int dv = 2;
    for (int dy0 = -outer_radius / dv; dy0 <= outer_radius / dv; dy0++) {
        for (int dx0 = -outer_radius / dv; dx0 <= outer_radius / dv; dx0++) {
            int dx = dx0 * dv;
            int dy = dy0 * dv;
            if (dx == 0 && dy == 0) {
                continue;
            }
            float ds = sqrt(dy * dy + dx * dx);
            if (ds > float(outer_radius) || ds < float(inner_radius)) {
                continue;
            }
            float ds0 = ds;
            ds = ds * ds;
            PixelData pix = get_pixel_data_at(pos_x + dx, pos_y + dy);
            float mul = 8;
            {
                float dh = (obj.height - pix.height);
                float dh0 = dh;
                if (dh < 0.) {
                    dh = abs(dh);
                    float dt = dot(normalize(vec2(float(dx), float(dy))),
                                   input_light_direction.xy);
                    if (dt > 0.7) {
                        directional_obscurance -= float(dv * dv) * dh * dt;
                    }
                }
                dh = sqrt(dh0 * dh0);
                if (dh > 4.) {
                    dh = 4.;
                }
                mul -= dh * float(dv);
            }
            if (!(pix.color.r > 1 || pix.color.g > 1 || pix.color.b > 1)) {
                continue;
            }
            if (pix.color.r > 1.) {
                float tmp = pix.color.r / (ds0)*mul;
                glare.r += tmp;
            }
            if (pix.color.g > 1.) {
                float tmp = pix.color.g / (ds0)*mul;
                glare.g += tmp;
            }
            if (pix.color.b > 1.) {
                float tmp = pix.color.b / (ds0)*mul;
                glare.b += tmp;
            }
        }
    }
    if (directional_obscurance < 0.05) {
        directional_obscurance = 0.05;
    }
    outp += calculate_incident_light(vec3(float(pos_x), float(pos_y), obj.height), obj.normal, directional_obscurance,0.);
    vec4 tout  = handle_materials(obj, pos_x, pos_y, outp, directional_obscurance);
    glare /= (float(outer_radius * outer_radius) * 3.14);
    glare *= 2.;
    tout.rgb += glare;
    if (obj.color.r > 1. || obj.color.g > 1. || obj.color.b > 1.) {
        tout.rgb = (vec3(1.5) + obj.color.rgb) / 2;
        if (tout.r > 1) {
            tout.r = 1;
        }
        if (tout.g > 1) {
            tout.g = 1;
        }
        if (tout.b > 1) {
            tout.b = 1;
        }
    } else if (tout.r > 1 || glare.r > 1) {
        tout.r = 1.;
    } else if (tout.g > 1 || glare.g > 1) {
        tout.g = 1.;
    } else if (tout.b > 1 || glare.b > 1) {
        tout.b = 1.;
    }
    return tout;
}


void main() {
    bool normals = display_normals != 0;
    vec2 coord = fragTexCoord;
    int pos_x = int(coord.x * render_width);
    int pos_y = int(coord.y * render_height);
    if (display_raw != 0) {
        vec3 tc = texture(texture0, coord).rgb;
        finalColor = vec4(tc, 1.0);
    } else if (normals) {
        ObjectData object = get_object_data_at(pos_x, pos_y);
        vec3 tc = object.normal;
        finalColor = vec4(tc, 1.0);
    } else {
        vec3 tc = calculate_lighting(pos_x, pos_y, 7, 15).rgb;
        finalColor = vec4(tc, 1.0);
    }
}