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
uniform surfaceshader backsurfaceshader;
uniform displacementshader displacementshader1;
uniform int geomprop_UV0_index = 0;
uniform float julia_cx = -0.745430;
uniform float julia_cy = 0.113010;
uniform float julia_scale = 3.000000;
uniform int julia_max_iterations = 64;
uniform float julia_phase = 0.000000;
uniform float unlit_emission = 1.000000;
uniform float unlit_transmission = 0.000000;
uniform vec3 unlit_transmission_color = vec3(1.000000, 1.000000, 1.000000);
uniform float unlit_opacity = 1.000000;

in VertexData
{
    vec2 texcoord_0;
} vd;

// Pixel shader outputs
out vec4 out1;

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

// Color of the Julia set of z^2 + c, a placeholder returning hot pink.
// 
// Args:
// texcoord: Point in the complex plane, before scaling
// cx: Real part of the constant c
// cy: Imaginary part of the constant c
// scale: Extent of the complex plane per unit of texcoord
// max_iterations: Maximum number of iterations of z^2 + c
// phase: Offset of the color palette
//
vec3 julia2d(vec2 texcoord, float cx, float cy, float scale, int max_iterations, float phase)
{
	return vec3(1.0, 0.0, 0.5);
}

void mx_julia2d_color3(vec2 texcoord, float cx, float cy, float scale, int max_iterations, float phase, out vec3 out_)
{
	out_ = julia2d(texcoord, cx, cy, scale, max_iterations, phase);
}



void mx_surface_unlit(float emission, vec3 emission_color, float transmission, vec3 transmission_color, float opacity, out surfaceshader result)
{
    result.color = emission * emission_color * opacity;
    result.transparency = mix(vec3(1.0), transmission * transmission_color, opacity);
}

void main()
{
    vec2 geomprop_UV0_out1 = vd.texcoord_0.xy;
    vec3 julia_out = vec3(0.0);
    mx_julia2d_color3(geomprop_UV0_out1, julia_cx, julia_cy, julia_scale, julia_max_iterations, julia_phase, julia_out);
    surfaceshader unlit_out = surfaceshader(vec3(0.0),vec3(0.0));
    mx_surface_unlit(unlit_emission, julia_out, unlit_transmission, unlit_transmission_color, unlit_opacity, unlit_out);
    material julia2d_out = unlit_out;
    out1 = vec4(julia2d_out.color, 1.0);
}

