#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
out vec4 finalColor;

uniform float render_width;
uniform float render_height;

uniform vec3 input_light_direction;
uniform vec4 input_light_color;
uniform int display_raw;
uniform int display_normals;

struct PixelData {
    float height;
    vec4 color;
    float reflectivity;
};

struct ObjectData {
    float height;
    float reflectivity;
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

PixelData extract_pixel_data(vec4 col) {
    PixelData outp;
    outp.height = col.r / (10.);
    outp.reflectivity = col.g;
    outp.color = v_parse_color(int(col.b * 255));
    return outp;
}

PixelData get_pixel_data_at(int x, int y) {
    if (x >= render_width || x < 0 || y >= render_height || y < 0) {
        PixelData outp;
        outp.height = 0;
        outp.reflectivity = 0;
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
    vec3 xhat = normalize(vec3(1., 0., dx * 512.));
    vec3 yhat = normalize(vec3(0., 1., dy * 512.));
    vec3 norm = cross(xhat, yhat);
    outp.normal = norm;
    outp.height = base_data.height;
    outp.color = base_data.color;
    outp.reflectivity = base_data.reflectivity;
    return outp;
}

vec4 calculate_lighting(int pos_x, int pos_y, int inner_radius,
                        int outer_radius) {
    ObjectData obj = get_object_data_at(pos_x, pos_y);
    vec4 outp = vec4(0.);
    vec3 glare = vec3(0.);
    float directional_obscurance = 1.;
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
            float ds0 = sqrt(ds);
            ds = ds * ds;
            PixelData pix = get_pixel_data_at(pos_x + dx, pos_y + dy);
            float obs = point_obscurance(pos_x, pos_y, pos_x + dx, pos_y + dy);
            if (pix.color.r > 1.) {
                float tmp = pix.color.r / (ds) * 2;
                outp.r += tmp * obs / ds;
                glare.r += tmp / ds;
            }
            if (pix.color.g > 1.) {
                float tmp = pix.color.g / (ds) * 2;
                outp.g += tmp * obs;
                glare.g += tmp / ds;
            }
            if (pix.color.b > 1.) {
                float tmp = pix.color.b / (ds) * 2;
                outp.b += tmp * obs / ds;
                glare.b += tmp / ds;
            }
            vec3 d2 = normalize(vec3(float(dx), float(dx), 1.));
            float dt = dot(dir, d2);
            if (dt > 0.0) {
                directional_obscurance -= obs * 10;
            }
        }
    }
    for (int dy0 = -outer_radius / 4; dy0 <= outer_radius / 4; dy0++) {
        for (int dx0 = -outer_radius / 4; dx0 <= outer_radius / 4; dx0++) {
            int dx = dx0 * 4;
            int dy = dy0 * 4;
            if (dx == 0 && dy == 0) {
                continue;
            }
            float ds = sqrt(dy * dy + dx * dx);
            if (ds > float(outer_radius) || ds < float(inner_radius)) {
                continue;
            }
            float ds0 = sqrt(ds);
            ds = ds * ds;
            PixelData pix = get_pixel_data_at(pos_x + dx, pos_y + dy);
            if (!(pix.color.r > 1 || pix.color.g > 1 || pix.color.b > 1)) {
                continue;
            }
            float obs = point_obscurance(pos_x, pos_y, pos_x + dx, pos_y + dy);
            if (pix.color.r > 1.) {
                float tmp = pix.color.r / (ds) * 16;
                outp.r += tmp * obs / ds0 * 4;
                glare.r += tmp / (ds0);
            }
            if (pix.color.g > 1.) {
                float tmp = pix.color.g / (ds) * 16;
                outp.g += tmp * obs / ds0 * 4;
                glare.g += tmp / (ds0);
            }
            if (pix.color.b > 1.) {
                float tmp = pix.color.b / (ds) * 16;
                outp.b += tmp * obs / ds0 * 4;
                glare.b += tmp / (ds0);
            }
            vec3 d2 = normalize(vec3(float(dx), float(dx), 1.));
            float dt = dot(dir, d2);
            if (dt > 0.0) {
                directional_obscurance -= obs * 10;
            }
        }
    }
    if (directional_obscurance < 0.1) {
        directional_obscurance = 0.1;
    }
    vec3 nhat = -obj.normal;
    float mul = dot(nhat, input_light_direction) * directional_obscurance;
    if (mul < 0.0) {
        mul = 0.0;
    }
    outp += input_light_color * mul;
    vec4 tout = obj.color;
    tout.r *= outp.r;
    tout.g *= outp.g;
    tout.b *= outp.b;
    tout.rgb += glare / 2;
    if (obj.color.r > 1. || obj.color.g > 1. || obj.color.b > 1.) {
        tout.rgb = vec3(1.);
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
        vec3 tc = calculate_lighting(pos_x, pos_y, 6, 20).rgb;
        finalColor = vec4(tc, 1.0);
    }
}