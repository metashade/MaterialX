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
uniform float squares_scale = 10.000000;
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

// Procedural randomized cell colors with sinusoidal UV distortion.
//
vec3 noisy_squares2d(vec2 texcoord, float scale)
{
	vec2 uv = texcoord * scale;
	vec2 warp = vec2(sin(uv.y * scale), sin(uv.x * scale));
	uv += warp / scale;
	float seed = floor(uv.x) + (floor(uv.y) * scale);
	float red = sin(seed * 12.9898) * 43758.5453;
	float green = sin(seed * 78.233) * 23421.631;
	float blue = sin(seed * 39.346) * 12741.371;
	return vec3(red - floor(red), green - floor(green), blue - floor(blue));
}

void mx_noisy_squares2d_color3(vec2 texcoord, float scale, out vec3 out_)
{
	out_ = noisy_squares2d(texcoord, scale);
}



void mx_surface_unlit(float emission, vec3 emission_color, float transmission, vec3 transmission_color, float opacity, out surfaceshader result)
{
    result.color = emission * emission_color * opacity;
    result.transparency = mix(vec3(1.0), transmission * transmission_color, opacity);
}

void main()
{
    vec2 geomprop_UV0_out1 = vd.texcoord_0.xy;
    vec3 squares_out = vec3(0.0);
    mx_noisy_squares2d_color3(geomprop_UV0_out1, squares_scale, squares_out);
    surfaceshader unlit_out = surfaceshader(vec3(0.0),vec3(0.0));
    mx_surface_unlit(unlit_emission, squares_out, unlit_transmission, unlit_transmission_color, unlit_opacity, unlit_out);
    material noisy_squares2d_out = unlit_out;
    out1 = vec4(noisy_squares2d_out.color, 1.0);
}

