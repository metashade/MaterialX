#version 400


struct BSDF { vec3 response; vec3 throughput; };
#define EDF vec3
struct VDF { vec3 response; vec3 throughput; };
struct surfaceshader { vec3 color; vec3 transparency; };
struct volumeshader { vec3 color; vec3 transparency; };
struct displacementshader { vec3 offset; float scale; };
struct lightshader { vec3 intensity; vec3 direction; };
#define material surfaceshader

// Uniform block: PublicUniforms
uniform int geomprop_UV0_index = 0;
uniform vec2 simplebitmap_realworld_offset_unit_in1 = vec2(0.000000, 0.000000);
uniform float simplebitmap_realworld_offset_unit_in2 = 2.540000;
uniform vec2 simplebitmap_realworld_scale_unit_in1 = vec2(2.000000, 2.000000);
uniform float simplebitmap_realworld_scale_unit_in2 = 2.540000;
uniform sampler2D simplebitmap_file;
uniform vec2 simplebitmap_uv_offset = vec2(0.000000, 0.000000);
uniform vec2 simplebitmap_uv_scale = vec2(1.000000, 1.000000);
uniform float simplebitmap_rotation_angle = 0.000000;
uniform float simplebitmap_rgbamount = 1.000000;
uniform bool simplebitmap_invert = false;
uniform int simplebitmap_uaddressmode = 2;
uniform int simplebitmap_vaddressmode = 2;

in VertexData
{
    vec2 texcoord_0;
} vd;

// Pixel shader outputs
out vec4 bitmapoutput1;

#define M_FLOAT_EPS 1e-8
#define M_PI 3.1415926535897932

#define mx_mod mod
#define mx_inverse inverse
#define mx_inversesqrt inversesqrt
#define mx_sin sin
#define mx_cos cos
#define mx_tan tan
#define mx_asin asin
#define mx_acos acos
#define mx_atan atan
#define mx_radians radians
#define mx_float_bits_to_int floatBitsToInt

vec2 mx_matrix_mul(vec2 v, mat2 m) { return v * m; }
vec3 mx_matrix_mul(vec3 v, mat3 m) { return v * m; }
vec4 mx_matrix_mul(vec4 v, mat4 m) { return v * m; }
vec2 mx_matrix_mul(mat2 m, vec2 v) { return m * v; }
vec3 mx_matrix_mul(mat3 m, vec3 v) { return m * v; }
vec4 mx_matrix_mul(mat4 m, vec4 v) { return m * v; }
mat2 mx_matrix_mul(mat2 m1, mat2 m2) { return m1 * m2; }
mat3 mx_matrix_mul(mat3 m1, mat3 m2) { return m1 * m2; }
mat4 mx_matrix_mul(mat4 m1, mat4 m2) { return m1 * m2; }

float mx_square(float x)
{
    return x*x;
}

vec2 mx_square(vec2 x)
{
    return x*x;
}

vec3 mx_square(vec3 x)
{
    return x*x;
}

vec3 mx_srgb_encode(vec3 color)
{
    bvec3 isAbove = greaterThan(color, vec3(0.0031308));
    vec3 linSeg = color * 12.92;
    vec3 powSeg = 1.055 * pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
    return mix(linSeg, powSeg, isAbove);
}

#define AIRY_FRESNEL_ITERATIONS 2

void mx_rotate_vector2(vec2 _in, float amount, out vec2 result)
{
    float rotationRadians = mx_radians(amount);
    float sa = mx_sin(rotationRadians);
    float ca = mx_cos(rotationRadians);
    result = vec2(ca*_in.x + sa*_in.y, -sa*_in.x + ca*_in.y);
}

void NG_switch_vector2I(vec2 in1, vec2 in2, vec2 in3, vec2 in4, vec2 in5, vec2 in6, vec2 in7, vec2 in8, vec2 in9, vec2 in10, int which, out vec2 out1)
{
    const int ifgreater_10_value1_tmp = 10;
    const vec2 ifgreater_10_in2_tmp = vec2(0.000000, 0.000000);
    vec2 ifgreater_10_out = (ifgreater_10_value1_tmp > which) ? in10 : ifgreater_10_in2_tmp;
    const int ifgreater_9_value1_tmp = 9;
    vec2 ifgreater_9_out = (ifgreater_9_value1_tmp > which) ? in9 : ifgreater_10_out;
    const int ifgreater_8_value1_tmp = 8;
    vec2 ifgreater_8_out = (ifgreater_8_value1_tmp > which) ? in8 : ifgreater_9_out;
    const int ifgreater_7_value1_tmp = 7;
    vec2 ifgreater_7_out = (ifgreater_7_value1_tmp > which) ? in7 : ifgreater_8_out;
    const int ifgreater_6_value1_tmp = 6;
    vec2 ifgreater_6_out = (ifgreater_6_value1_tmp > which) ? in6 : ifgreater_7_out;
    const int ifgreater_5_value1_tmp = 5;
    vec2 ifgreater_5_out = (ifgreater_5_value1_tmp > which) ? in5 : ifgreater_6_out;
    const int ifgreater_4_value1_tmp = 4;
    vec2 ifgreater_4_out = (ifgreater_4_value1_tmp > which) ? in4 : ifgreater_5_out;
    const int ifgreater_3_value1_tmp = 3;
    vec2 ifgreater_3_out = (ifgreater_3_value1_tmp > which) ? in3 : ifgreater_4_out;
    const int ifgreater_2_value1_tmp = 2;
    vec2 ifgreater_2_out = (ifgreater_2_value1_tmp > which) ? in2 : ifgreater_3_out;
    const int ifgreater_1_value1_tmp = 1;
    vec2 ifgreater_1_out = (ifgreater_1_value1_tmp > which) ? in1 : ifgreater_2_out;
    out1 = ifgreater_1_out;
}

void NG_place2d_vector2(vec2 texcoord, vec2 pivot, vec2 scale, float rotate, vec2 offset, int operationorder, out vec2 out1)
{
    vec2 N_subpivot_out = texcoord - pivot;
    vec2 N_applyscale_out = N_subpivot_out / scale;
    vec2 N_applyoffset2_out = N_subpivot_out - offset;
    vec2 N_applyrot_out = vec2(0.0);
    mx_rotate_vector2(N_applyscale_out, rotate, N_applyrot_out);
    vec2 N_applyrot2_out = vec2(0.0);
    mx_rotate_vector2(N_applyoffset2_out, rotate, N_applyrot2_out);
    vec2 N_applyoffset_out = N_applyrot_out - offset;
    vec2 N_applyscale2_out = N_applyrot2_out / scale;
    vec2 N_addpivot_out = N_applyoffset_out + pivot;
    vec2 N_addpivot2_out = N_applyscale2_out + pivot;
    vec2 N_switch_operationorder_out = vec2(0.0);
    NG_switch_vector2I(N_addpivot_out, N_addpivot2_out, vec2(0.000000, 0.000000), vec2(0.000000, 0.000000), vec2(0.000000, 0.000000), vec2(0.000000, 0.000000), vec2(0.000000, 0.000000), vec2(0.000000, 0.000000), vec2(0.000000, 0.000000), vec2(0.000000, 0.000000), operationorder, N_switch_operationorder_out);
    out1 = N_switch_operationorder_out;
}

vec2 mx_transform_uv(vec2 uv, vec2 uv_scale, vec2 uv_offset)
{
    uv = uv * uv_scale + uv_offset;
    return vec2(uv.x, 1.0 - uv.y);
}

void mx_image_color3(sampler2D tex_sampler, int layer, vec3 defaultval, vec2 texcoord, int uaddressmode, int vaddressmode, int filtertype, int framerange, int frameoffset, int frameendaction, vec2 uv_scale, vec2 uv_offset, out vec3 result)
{
    vec2 uv = mx_transform_uv(texcoord, uv_scale, uv_offset);
    result = texture(tex_sampler, uv).rgb;
}

void adsk_NG_adsk_bitmap_color3(sampler2D file, vec2 realworld_offset, vec2 realworld_scale, vec2 uv_offset, vec2 uv_scale, float rotation_angle, float rgbamount, bool invert, int uaddressmode, int vaddressmode, vec2 texcoord, out vec3 out1)
{
    vec2 total_offset_out = realworld_offset + uv_offset;
    vec2 total_scale_out = realworld_scale / uv_scale;
    const float rotation_angle_param_in2_tmp = -1.000000;
    float rotation_angle_param_out = rotation_angle * rotation_angle_param_in2_tmp;
    vec2 a_place2d_out = vec2(0.0);
    NG_place2d_vector2(texcoord, vec2(0.000000, 0.000000), total_scale_out, rotation_angle_param_out, total_offset_out, 1, a_place2d_out);
    vec3 b_image_out = vec3(0.0);
    mx_image_color3(file, 0, vec3(0.000000, 0.000000, 0.000000), a_place2d_out, uaddressmode, vaddressmode, 1, 0, 0, 0, vec2(1.000000, 1.000000), vec2(0.000000, 0.000000), b_image_out);
    vec3 image_brightness_out = b_image_out * rgbamount;
    const vec3 image_invert_amount_tmp = vec3(1.000000, 1.000000, 1.000000);
    vec3 image_invert_out = image_invert_amount_tmp - image_brightness_out;
    const bool image_convert_value2_tmp = true;
    vec3 image_convert_out = (invert == image_convert_value2_tmp) ? image_invert_out : image_brightness_out;
    out1 = image_convert_out;
}

void main()
{
    vec2 geomprop_UV0_out1 = vd.texcoord_0.xy;
    vec2 simplebitmap_realworld_offset_unit_out = simplebitmap_realworld_offset_unit_in1 * simplebitmap_realworld_offset_unit_in2;
    vec2 simplebitmap_realworld_scale_unit_out = simplebitmap_realworld_scale_unit_in1 * simplebitmap_realworld_scale_unit_in2;
    vec3 simplebitmap_out = vec3(0.0);
    adsk_NG_adsk_bitmap_color3(simplebitmap_file, simplebitmap_realworld_offset_unit_out, simplebitmap_realworld_scale_unit_out, simplebitmap_uv_offset, simplebitmap_uv_scale, simplebitmap_rotation_angle, simplebitmap_rgbamount, simplebitmap_invert, simplebitmap_uaddressmode, simplebitmap_vaddressmode, geomprop_UV0_out1, simplebitmap_out);
    bitmapoutput1 = vec4(simplebitmap_out, 1.0);
}

