shader_type sky;

uniform samplerCube cubemap : source_color, filter_linear;

void sky() {
    COLOR = texture(cubemap, EYEDIR).rgb;
}