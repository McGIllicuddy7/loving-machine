in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
out vec4 finalColor;

uniform float render_width;
uniform float render_height;

uniform vec3 input_light_pos;
uniform vec4 input_light_color;

void main() {
    finalColor = fragColor;
}