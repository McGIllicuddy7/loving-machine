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

struct PixelData {
    float height;
    vec4 color;
    float glass_height;
};

struct ObjectData {
    float height;
    float glass_height;
    vec3 normal;
    vec4 color;
};

vec4 COLORS[] = vec4[](vec4(0, 0, 0, 1),       // BLACK, //0
                       vec4(0.8, 0, 0, 1),     // RED, //1
                       vec4(0., 0.8, 0., 1),   // GREEN, //2
                       vec4(0.8, 0.8, 0., 1),  // YELLOW, //3
                       vec4(0, 0, 0.8, 1),     // BLUE, //4
                       vec4(0.8, 0, 0.8, 1),   // MAGENTA, //5
                       vec4(0, 0.8, 0.8, 1),   // CYAN, //6
                       vec4(0.8, 0.8, 0.8, 1), // WHITE, //7
                       vec4(0.2, 0.2, 0.2, 1), // BRIGHT_BLACK, //8
                       vec4(1, 0, 0, 1),       // BRIGHT_RED, //9
                       vec4(0, 1, 0, 1),       // BRIGHT_GREEN, //10
                       vec4(1, 1, 0, 1),       // BRIGHT_YELLOW, //11
                       vec4(0, 0, 1, 1),       // BRIGHT_BLUE, //12
                       vec4(1, 0, 1, 1),       // BRIGHT_MAGENTA, //13
                       vec4(0, 1, 1, 1),       // BRIGHT_CYAN, //14
                       vec4(1, 1, 1, 1),       // BRIGHT_WHITE, //15
                       vec4(1.2, 1.2, 1.2, 1), // EMMISIVE_BLACK, //16
                       vec4(2, 0, 0, 1),       // EMMISIVE_RED, //17
                       vec4(0, 2, 0, 1),       // EMMISIVE_GREEN, //18
                       vec4(2, 2, 0, 1),       // EMMISIVE_YELLOW, //19
                       vec4(0, 0, 2, 1),       // EMMISIVE_BLUE, //20
                       vec4(2, 0, 2, 1),       // EMMISIVE_MAGENTA, //21
                       vec4(0, 2, 2, 1),       // EMMISIVE_CYAN, //22
                       vec4(2, 2, 2, 1)        // EMMISIVE_WHITE, //23
);

const int COLORS_COUNT = COLORS.length();
vec4 v_parse_color(int col) { return COLORS[(col % COLORS_COUNT)]; }

vec3 get_camera_position(){
    return vec3(float(render_width)/2, float(render_height)/2, 100);
}
float hash(vec2 uv)
{
    return fract(sin(7.289 * uv.x + 11.23 * uv.y) * 23758.5453);
}

float hash_point(int x, int y){
    return hash(vec2(float(x), float(y)));
}

PixelData extract_pixel_data(vec4 col) {
    PixelData outp;
    outp.height = col.r / (10.);
    outp.glass_height = col.g;
    outp.color = v_parse_color(int(col.b * 255));
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
    return outp;
}

float specular_light_contribution(vec3 position, vec3 normal){
    vec3 input_light_delta =
        position - input_light_pos;
    vec3 input_light_direction = normalize(input_light_delta);
    float spec_mul = 0.;
    vec3 rf = reflect(input_light_direction, normal);
    vec3 d0 = normalize(get_camera_position()-position);
    if (dot(rf, d0)>0.6){
        spec_mul = dot(rf, d0);
    }
    return spec_mul;
}

vec4 calculate_incident_light(vec3 position, vec3 normal, float directional_obscurance, float specular){
    vec4 outv =input_light_color;
    vec3 input_light_delta =
        position - input_light_pos;
    vec3 input_light_direction = normalize(input_light_delta);
    float dist = length(input_light_direction);
    dist *= dist;
    vec3 nhat = -normal;
    float mul = dot(nhat, input_light_direction) * directional_obscurance;
    if (mul < 0.0) {
        mul = 0.0;
    }
    float spec_mul = specular_light_contribution(position, normal)*directional_obscurance;
    return outv*mul*(1-specular)+(outv*spec_mul)*specular;
}

vec4 handle_materials(ObjectData obj, int pos_x, int pos_y,vec4 base_lighting, float directional_obscurance) {
    vec4 outv = base_lighting;         
    outv.r *= obj.color.r;
    outv.g *= obj.color.g;
    outv.b *= obj.color.b;   
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

    outp += calculate_incident_light(vec3(float(pos_x), float(pos_y), obj.height), obj.normal, directional_obscurance, 0.0);
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