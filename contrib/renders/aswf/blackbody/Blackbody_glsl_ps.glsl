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
uniform float blackbody_color_out_temperature = 5000.000000;
uniform float SR_blackbody_emission = 1.000000;
uniform float SR_blackbody_transmission = 0.000000;
uniform vec3 SR_blackbody_transmission_color = vec3(1.000000, 1.000000, 1.000000);
uniform float SR_blackbody_opacity = 1.000000;

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

/// XYZ to Rec.709 RGB colorspace conversion
const mat3 XYZ_to_RGB = mat3( 3.2406, -0.9689, 0.0557,
                             -1.5372, 1.8758, -0.2040,
                             -0.4986, 0.0415, 1.0570);

void mx_blackbody(float temperatureKelvin, out vec3 colorValue)
{
    float xc, yc;
    float t, t2, t3, xc2, xc3;

    // Clamp to the range supported by the approximation.
    // Lower limit is near the Draper point (~798K), the minimum temperature for visible blackbody emission.
    // The Kang et al. (2002) xc polynomial is valid from 1000K, and extrapolates acceptably down to ~800K.
    temperatureKelvin = clamp(temperatureKelvin, 800.0, 25000.0);

    t = 1000.0 / temperatureKelvin;
    t2 = t * t;
    t3 = t * t * t;

    // Cubic spline approximation for Kelvin temperature to CIE xy chromaticity
    // (https://en.wikipedia.org/wiki/Planckian_locus#Approximation)
    // Kang et al. (2002): the same xc polynomial covers 1000K–4000K, so the
    // old 1667K lower clamp was unnecessarily conservative.
    if (temperatureKelvin < 4000.0) {  // 800K <= temperatureKelvin < 4000K
      xc = -0.2661239 * t3 - 0.2343580 * t2 + 0.8776956 * t + 0.179910;
    }
    else {  // 4000K <= temperatureKelvin <= 25000K
      xc = -3.0258469 * t3 + 2.1070379 * t2 + 0.2226347 * t + 0.240390;
    }
    xc2 = xc * xc;
    xc3 = xc * xc * xc;

    if (temperatureKelvin < 2222.0) {  // 800K <= temperatureKelvin < 2222K
      yc = -1.1063814 * xc3 - 1.34811020 * xc2 + 2.18555832 * xc - 0.20219683;
    }
    else if (temperatureKelvin < 4000.0) {  // 2222K <= temperatureKelvin < 4000K
      yc = -0.9549476 * xc3 - 1.37418593 * xc2 + 2.09137015 * xc - 0.16748867;
    }
    else {  // 4000K <= temperatureKelvin <= 25000K
      yc = 3.0817580 * xc3 - 5.87338670 * xc2 + 3.75112997 * xc - 0.37001483;
    }

    if (yc <= 0.0) {  // avoid division by zero
      colorValue = vec3(1.0);
      return;
    }

    vec3 XYZ = vec3(xc / yc, 1.0, (1.0 - xc - yc) / yc);

    colorValue = mx_matrix_mul(XYZ_to_RGB, XYZ);
    colorValue = max(colorValue, vec3(0.0));
}


void mx_surface_unlit(float emission, vec3 emission_color, float transmission, vec3 transmission_color, float opacity, out surfaceshader result)
{
    result.color = emission * emission_color * opacity;
    result.transparency = mix(vec3(1.0), transmission * transmission_color, opacity);
}

void main()
{
    vec3 blackbody_color_out_out = vec3(0.0);
    mx_blackbody(blackbody_color_out_temperature, blackbody_color_out_out);
    surfaceshader SR_blackbody_out = surfaceshader(vec3(0.0),vec3(0.0));
    mx_surface_unlit(SR_blackbody_emission, blackbody_color_out_out, SR_blackbody_transmission, SR_blackbody_transmission_color, SR_blackbody_opacity, SR_blackbody_out);
    material Blackbody_out = SR_blackbody_out;
    out1 = vec4(Blackbody_out.color, 1.0);
}

