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
uniform sampler2D tiledimage1_file;
uniform vec2 tiledimage1_default = vec2(0.000000, 0.000000);
uniform vec2 tiledimage1_uvtiling = vec2(1.000000, 1.000000);
uniform vec2 tiledimage1_uvoffset = vec2(0.000000, 0.000000);
uniform vec2 tiledimage1_realworldimagesize = vec2(1.000000, 1.000000);
uniform vec2 tiledimage1_realworldtilesize = vec2(1.000000, 1.000000);
uniform int tiledimage1_filtertype = 1;
uniform int tiledimage1_framerange = 0;
uniform int tiledimage1_frameoffset = 0;
uniform int tiledimage1_frameendaction = 0;
uniform float blur_vector2_size = 0.500000;
uniform int blur_vector2_filtertype = 0;

in VertexData
{
    vec2 texcoord_0;
} vd;

// Pixel shader outputs
out vec4 out11;

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

vec2 mx_transform_uv(vec2 uv, vec2 uv_scale, vec2 uv_offset)
{
    uv = uv * uv_scale + uv_offset;
    return vec2(uv.x, 1.0 - uv.y);
}

void mx_image_vector2(sampler2D tex_sampler, int layer, vec2 defaultval, vec2 texcoord, int uaddressmode, int vaddressmode, int filtertype, int framerange, int frameoffset, int frameendaction, vec2 uv_scale, vec2 uv_offset, out vec2 result)
{
    vec2 uv = mx_transform_uv(texcoord, uv_scale, uv_offset);
    result = texture(tex_sampler, uv).rg;
}

void NG_tiledimage_vector2(sampler2D file, vec2 default1, vec2 texcoord, vec2 uvtiling, vec2 uvoffset, vec2 realworldimagesize, vec2 realworldtilesize, int filtertype, int framerange, int frameoffset, int frameendaction, out vec2 out1)
{
    vec2 N_mult_vector2_out = texcoord * uvtiling;
    vec2 N_sub_vector2_out = N_mult_vector2_out - uvoffset;
    vec2 N_divtilesize_vector2_out = N_sub_vector2_out / realworldimagesize;
    vec2 N_multtilesize_vector2_out = N_divtilesize_vector2_out * realworldtilesize;
    vec2 N_img_vector2_out = vec2(0.0);
    mx_image_vector2(file, 0, default1, N_multtilesize_vector2_out, 2, 2, filtertype, framerange, frameoffset, frameendaction, vec2(1.000000, 1.000000), vec2(0.000000, 0.000000), N_img_vector2_out);
    out1 = N_img_vector2_out;
}

void NG_blur_vector2(vec2 in1, float size, int filtertype, out vec2 out1)
{
    out1 = in1;
}

void main()
{
    vec2 geomprop_UV0_out1 = vd.texcoord_0.xy;
    vec2 tiledimage1_out = vec2(0.0);
    NG_tiledimage_vector2(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1, tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out);
    vec2 blur_vector2_out = vec2(0.0);
    NG_blur_vector2(tiledimage1_out, blur_vector2_size, blur_vector2_filtertype, blur_vector2_out);
    out11 = vec4(blur_vector2_out, 0.0, 1.0);
}

