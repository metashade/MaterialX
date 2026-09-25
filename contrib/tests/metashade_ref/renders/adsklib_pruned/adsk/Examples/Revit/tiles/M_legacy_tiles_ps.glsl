#version 400


struct BSDF { vec3 response; vec3 throughput; };
#define EDF vec3
struct VDF { vec3 response; vec3 throughput; };
struct surfaceshader { vec3 color; vec3 transparency; };
struct volumeshader { vec3 color; vec3 transparency; };
struct displacementshader { vec3 offset; float scale; };
struct lightshader { vec3 intensity; vec3 direction; };
#define material surfaceshader

// Uniform block: PrivateUniforms
uniform mat4 u_envMatrix = mat4(-1.000000, 0.000000, 0.000000, 0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, 0.000000, -1.000000, 0.000000, 0.000000, 0.000000, 0.000000, 1.000000);
uniform sampler2D u_envRadiance;
uniform float u_envLightIntensity = 1.000000;
uniform int u_envRadianceMips = 1;
uniform int u_envRadianceSamples = 16;
uniform sampler2D u_envIrradiance;
uniform bool u_refractionTwoSided = false;
uniform vec3 u_viewPosition = vec3(0.0);

// Uniform block: PublicUniforms
uniform surfaceshader backsurfaceshader;
uniform displacementshader displacementshader1;
uniform int geomprop_UV0_index = 0;
uniform vec2 legacy_tiles_realworld_scale_unit_in1 = vec2(24.000000, 24.000000);
uniform float legacy_tiles_realworld_scale_unit_in2 = 2.540000;
uniform vec2 legacy_tiles_realworld_offset_unit_in1 = vec2(-3.000000, -4.500000);
uniform float legacy_tiles_realworld_offset_unit_in2 = 2.540000;
uniform float legacy_tiles_rotation_angle_unit_in1 = 0.000000;
uniform float legacy_tiles_rotation_angle_unit_in2 = 1.000000;
uniform vec3 legacy_tiles_tile_color = vec3(0.620000, 0.240000, 0.060000);
uniform vec3 legacy_tiles_grout_color = vec3(0.100000, 0.100000, 0.100000);
uniform float legacy_tiles_tiles_num_x = 4.000000;
uniform float legacy_tiles_tiles_num_y = 8.000000;
uniform float legacy_tiles_grout_gap_x = 0.330000;
uniform float legacy_tiles_grout_gap_y = 0.330000;
uniform float legacy_tiles_grout_bias = 0.000000;
uniform float legacy_tiles_line_shift = 0.000000;
uniform float legacy_tiles_random_shift = 0.000000;
uniform float legacy_tiles_color_variance = 7.100000;
uniform float legacy_tiles_fade_variance = 1.900000;
uniform float legacy_tiles_seed = 0.000000;
uniform bool legacy_tiles_brightness_variance = true;
uniform bool legacy_tiles_alpha_fade = true;
uniform float legacy_tiles_roughness_scale = 30.000000;
uniform float legacy_tiles_roughness_amount = 5.300000;
uniform bool legacy_tiles_rows_mod_enable = false;
uniform float legacy_tiles_num_rows = 5.000000;
uniform float legacy_tiles_rows_mod_amount = 3.000000;
uniform bool legacy_tiles_tile_x = true;
uniform bool legacy_tiles_tile_y = true;
uniform float add_float_in2 = 0.000000;
uniform float SR_testmat1_base = 1.000000;
uniform float SR_testmat1_diffuse_roughness = 0.000000;
uniform float SR_testmat1_metalness = 0.000000;
uniform float SR_testmat1_specular = 1.000000;
uniform vec3 SR_testmat1_specular_color = vec3(1.000000, 1.000000, 1.000000);
uniform float SR_testmat1_specular_roughness = 0.100000;
uniform float SR_testmat1_specular_IOR = 1.500000;
uniform float SR_testmat1_specular_anisotropy = 0.000000;
uniform float SR_testmat1_specular_rotation = 0.000000;
uniform float SR_testmat1_transmission = 0.000000;
uniform vec3 SR_testmat1_transmission_color = vec3(1.000000, 1.000000, 1.000000);
uniform float SR_testmat1_transmission_depth = 0.000000;
uniform vec3 SR_testmat1_transmission_scatter = vec3(0.000000, 0.000000, 0.000000);
uniform float SR_testmat1_transmission_scatter_anisotropy = 0.000000;
uniform float SR_testmat1_transmission_dispersion = 0.000000;
uniform float SR_testmat1_transmission_extra_roughness = 0.000000;
uniform float SR_testmat1_subsurface = 0.400000;
uniform vec3 SR_testmat1_subsurface_color = vec3(1.000000, 1.000000, 1.000000);
uniform vec3 SR_testmat1_subsurface_radius = vec3(1.000000, 1.000000, 1.000000);
uniform float SR_testmat1_subsurface_scale = 1.000000;
uniform float SR_testmat1_subsurface_anisotropy = 0.000000;
uniform float SR_testmat1_sheen = 0.000000;
uniform vec3 SR_testmat1_sheen_color = vec3(1.000000, 1.000000, 1.000000);
uniform float SR_testmat1_sheen_roughness = 0.300000;
uniform float SR_testmat1_coat = 0.000000;
uniform vec3 SR_testmat1_coat_color = vec3(1.000000, 1.000000, 1.000000);
uniform float SR_testmat1_coat_roughness = 0.100000;
uniform float SR_testmat1_coat_anisotropy = 0.000000;
uniform float SR_testmat1_coat_rotation = 0.000000;
uniform float SR_testmat1_coat_IOR = 1.500000;
uniform float SR_testmat1_coat_affect_color = 0.000000;
uniform float SR_testmat1_coat_affect_roughness = 0.000000;
uniform float SR_testmat1_thin_film_thickness = 0.000000;
uniform float SR_testmat1_thin_film_IOR = 1.500000;
uniform float SR_testmat1_emission = 0.000000;
uniform vec3 SR_testmat1_emission_color = vec3(1.000000, 1.000000, 1.000000);
uniform bool SR_testmat1_thin_walled = false;

in VertexData
{
    vec3 normalWorld;
    vec3 tangentWorld;
    vec2 texcoord_0;
    vec3 positionWorld;
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

#define DIRECTIONAL_ALBEDO_METHOD 0

#define AIRY_FRESNEL_ITERATIONS 2

#define M_PI 3.1415926535897932
#define M_PI_INV (1.0 / M_PI)

float mx_pow5(float x)
{
    return mx_square(mx_square(x)) * x;
}

float mx_pow6(float x)
{
    float x2 = mx_square(x);
    return mx_square(x2) * x2;
}

// Standard Schlick Fresnel
float mx_fresnel_schlick(float cosTheta, float F0)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    float x5 = mx_pow5(x);
    return F0 + (1.0 - F0) * x5;
}
vec3 mx_fresnel_schlick(float cosTheta, vec3 F0)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    float x5 = mx_pow5(x);
    return F0 + (1.0 - F0) * x5;
}

// Generalized Schlick Fresnel
float mx_fresnel_schlick(float cosTheta, float F0, float F90)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    float x5 = mx_pow5(x);
    return mix(F0, F90, x5);
}
vec3 mx_fresnel_schlick(float cosTheta, vec3 F0, vec3 F90)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    float x5 = mx_pow5(x);
    return mix(F0, F90, x5);
}

// Generalized Schlick Fresnel with a variable exponent
float mx_fresnel_schlick(float cosTheta, float F0, float F90, float exponent)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    return mix(F0, F90, pow(x, exponent));
}
vec3 mx_fresnel_schlick(float cosTheta, vec3 F0, vec3 F90, float exponent)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    return mix(F0, F90, pow(x, exponent));
}

// Enforce that the given normal is forward-facing from the specified view direction.
vec3 mx_forward_facing_normal(vec3 N, vec3 V)
{
    return (dot(N, V) < 0.0) ? -N : N;
}

// https://www.graphics.rwth-aachen.de/publication/2/jgt.pdf
float mx_golden_ratio_sequence(int i)
{
    const float GOLDEN_RATIO = 1.6180339887498948;
    return fract((float(i) + 1.0) * GOLDEN_RATIO);
}

// https://people.irisa.fr/Ricardo.Marques/articles/2013/SF_CGF.pdf
vec2 mx_spherical_fibonacci(int i, int numSamples)
{
    return vec2((float(i) + 0.5) / float(numSamples), mx_golden_ratio_sequence(i));
}

// Generate a uniform-weighted sample on the unit hemisphere.
vec3 mx_uniform_sample_hemisphere(vec2 Xi)
{
    float phi = 2.0 * M_PI * Xi.x;
    float cosTheta = 1.0 - Xi.y;
    float sinTheta = sqrt(1.0 - mx_square(cosTheta));
    return vec3(mx_cos(phi) * sinTheta,
                mx_sin(phi) * sinTheta,
                cosTheta);
}

// Generate a cosine-weighted sample on the unit hemisphere.
vec3 mx_cosine_sample_hemisphere(vec2 Xi)
{
    float phi = 2.0 * M_PI * Xi.x;
    float cosTheta = sqrt(Xi.y);
    float sinTheta = sqrt(1.0 - Xi.y);
    return vec3(mx_cos(phi) * sinTheta,
                mx_sin(phi) * sinTheta,
                cosTheta);
}

// PDF of a cosine-weighted hemisphere sample.
float mx_cosine_hemisphere_PDF(float cosTheta)
{
    return max(cosTheta, 0.0) * M_PI_INV;
}

// PDF of a uniform hemisphere sample.
float mx_uniform_hemisphere_PDF()
{
    return 0.5 * M_PI_INV;
}

// Construct an orthonormal basis from a unit vector.
// https://graphics.pixar.com/library/OrthonormalB/paper.pdf
mat3 mx_orthonormal_basis(vec3 N)
{
    float sign = (N.z < 0.0) ? -1.0 : 1.0;
    float a = -1.0 / (sign + N.z);
    float b = N.x * N.y * a;
    vec3 X = vec3(1.0 + sign * N.x * N.x * a, sign * b, -sign * N.x);
    vec3 Y = vec3(b, sign + N.y * N.y * a, -N.y);
    return mat3(X, Y, N);
}

const int FRESNEL_MODEL_DIELECTRIC = 0;
const int FRESNEL_MODEL_CONDUCTOR = 1;
const int FRESNEL_MODEL_SCHLICK = 2;

// Parameters for Fresnel calculations
struct FresnelData
{
    // Fresnel model
    int model;
    bool airy;

    // Physical Fresnel
    vec3 ior;
    vec3 extinction;

    // Generalized Schlick Fresnel
    vec3 F0;
    vec3 F82;
    vec3 F90;
    float exponent;

    // Thin film
    float tf_thickness;
    float tf_ior;

    // Refraction
    bool refraction;
};

// https://media.disneyanimation.com/uploads/production/publication_asset/48/asset/s2012_pbs_disney_brdf_notes_v3.pdf
// Appendix B.2 Equation 13
float mx_ggx_NDF(vec3 H, vec2 alpha)
{
    vec2 He = H.xy / alpha;
    float denom = dot(He, He) + mx_square(H.z);
    return 1.0 / (M_PI * alpha.x * alpha.y * mx_square(denom));
}

// https://ggx-research.github.io/publication/2023/06/09/publication-ggx.html
vec3 mx_ggx_importance_sample_VNDF(vec2 Xi, vec3 V, vec2 alpha)
{
    // Transform the view direction to the hemisphere configuration.
    V = normalize(vec3(V.xy * alpha, V.z));

    // Sample a spherical cap in (-V.z, 1].
    float phi = 2.0 * M_PI * Xi.x;
    float z = (1.0 - Xi.y) * (1.0 + V.z) - V.z;
    float sinTheta = sqrt(clamp(1.0 - z * z, 0.0, 1.0));
    float x = sinTheta * mx_cos(phi);
    float y = sinTheta * mx_sin(phi);
    vec3 c = vec3(x, y, z);

    // Compute the microfacet normal.
    vec3 H = c + V;

    // Transform the microfacet normal back to the ellipsoid configuration.
    H = normalize(vec3(H.xy * alpha, max(H.z, 0.0)));

    return H;
}

// PDF of a reflection direction sampled from the GGX VNDF.
float mx_ggx_VNDF_reflection_PDF(vec3 H, vec2 alpha, float G1V, float NdotV)
{
    return mx_ggx_NDF(H, alpha) * G1V / (4.0 * NdotV);
}

// https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
// Equation 34
float mx_ggx_smith_G1(float cosTheta, float alpha)
{
    float cosTheta2 = mx_square(cosTheta);
    float tanTheta2 = (1.0 - cosTheta2) / cosTheta2;
    return 2.0 / (1.0 + sqrt(1.0 + mx_square(alpha) * tanTheta2));
}

// Height-correlated Smith masking-shadowing
// http://jcgt.org/published/0003/02/03/paper.pdf
// Equations 72 and 99
float mx_ggx_smith_G2(float NdotL, float NdotV, float alpha)
{
    float alpha2 = mx_square(alpha);
    float lambdaL = sqrt(alpha2 + (1.0 - alpha2) * mx_square(NdotL));
    float lambdaV = sqrt(alpha2 + (1.0 - alpha2) * mx_square(NdotV));
    return 2.0 * NdotL * NdotV / (lambdaL * NdotV + lambdaV * NdotL);
}

// Rational quadratic fit to Monte Carlo data for GGX directional albedo.
vec3 mx_ggx_dir_albedo_analytic(float NdotV, float alpha, vec3 F0, vec3 F90)
{
    float x = NdotV;
    float y = alpha;
    float x2 = mx_square(x);
    float y2 = mx_square(y);
    vec4 r = vec4(0.1003, 0.9345, 1.0, 1.0) +
             vec4(-0.6303, -2.323, -1.765, 0.2281) * x +
             vec4(9.748, 2.229, 8.263, 15.94) * y +
             vec4(-2.038, -3.748, 11.53, -55.83) * x * y +
             vec4(29.34, 1.424, 28.96, 13.08) * x2 +
             vec4(-8.245, -0.7684, -7.507, 41.26) * y2 +
             vec4(-26.44, 1.436, -36.11, 54.9) * x2 * y +
             vec4(19.99, 0.2913, 15.86, 300.2) * x * y2 +
             vec4(-5.448, 0.6286, 33.37, -285.1) * x2 * y2;
    vec2 AB = clamp(r.xy / r.zw, 0.0, 1.0);
    return F0 * AB.x + F90 * AB.y;
}

vec3 mx_ggx_dir_albedo_table_lookup(float NdotV, float alpha, vec3 F0, vec3 F90)
{
#if DIRECTIONAL_ALBEDO_METHOD == 1
    if (textureSize(u_albedoTable, 0).x > 1)
    {
        vec2 AB = texture(u_albedoTable, vec2(NdotV, alpha)).rg;
        return F0 * AB.x + F90 * AB.y;
    }
#endif
    return vec3(0.0);
}

// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
vec3 mx_ggx_dir_albedo_monte_carlo(float NdotV, float alpha, vec3 F0, vec3 F90)
{
    NdotV = clamp(NdotV, M_FLOAT_EPS, 1.0);
    vec3 V = vec3(sqrt(1.0 - mx_square(NdotV)), 0, NdotV);

    vec2 AB = vec2(0.0);
    const int SAMPLE_COUNT = 64;
    for (int i = 0; i < SAMPLE_COUNT; i++)
    {
        vec2 Xi = mx_spherical_fibonacci(i, SAMPLE_COUNT);

        // Compute the half vector and incoming light direction.
        vec3 H = mx_ggx_importance_sample_VNDF(Xi, V, vec2(alpha));
        vec3 L = -reflect(V, H);
        
        // Compute dot products for this sample.
        float NdotL = clamp(L.z, M_FLOAT_EPS, 1.0);
        float VdotH = clamp(dot(V, H), M_FLOAT_EPS, 1.0);

        // Compute the Fresnel term.
        float Fc = mx_fresnel_schlick(VdotH, 0.0, 1.0);

        // Compute the per-sample geometric term.
        // https://hal.inria.fr/hal-00996995v2/document, Algorithm 2
        float G2 = mx_ggx_smith_G2(NdotL, NdotV, alpha);
        
        // Add the contribution of this sample.
        AB += vec2(G2 * (1.0 - Fc), G2 * Fc);
    }

    // Apply the global component of the geometric term and normalize.
    AB /= mx_ggx_smith_G1(NdotV, alpha) * float(SAMPLE_COUNT);

    // Return the final directional albedo.
    return F0 * AB.x + F90 * AB.y;
}

vec3 mx_ggx_dir_albedo(float NdotV, float alpha, vec3 F0, vec3 F90)
{
#if DIRECTIONAL_ALBEDO_METHOD == 0
    return mx_ggx_dir_albedo_analytic(NdotV, alpha, F0, F90);
#elif DIRECTIONAL_ALBEDO_METHOD == 1
    return mx_ggx_dir_albedo_table_lookup(NdotV, alpha, F0, F90);
#else
    return mx_ggx_dir_albedo_monte_carlo(NdotV, alpha, F0, F90);
#endif
}

float mx_ggx_dir_albedo(float NdotV, float alpha, float F0, float F90)
{
    return mx_ggx_dir_albedo(NdotV, alpha, vec3(F0), vec3(F90)).x;
}

// https://blog.selfshadow.com/publications/turquin/ms_comp_final.pdf
// Equations 14 and 16
vec3 mx_ggx_energy_compensation(float NdotV, float alpha, vec3 Fss)
{
    float Ess = mx_ggx_dir_albedo(NdotV, alpha, 1.0, 1.0);
    return 1.0 + Fss * (1.0 - Ess) / Ess;
}

float mx_ggx_energy_compensation(float NdotV, float alpha, float Fss)
{
    return mx_ggx_energy_compensation(NdotV, alpha, vec3(Fss)).x;
}

// Compute the average of an anisotropic alpha pair.
float mx_average_alpha(vec2 alpha)
{
    return sqrt(alpha.x * alpha.y);
}

// Convert a real-valued index of refraction to normal-incidence reflectivity.
float mx_ior_to_f0(float ior)
{
    return mx_square((ior - 1.0) / (ior + 1.0));
}

// Convert normal-incidence reflectivity to real-valued index of refraction.
float mx_f0_to_ior(float F0)
{
    float sqrtF0 = sqrt(clamp(F0, 0.01, 0.99));
    return (1.0 + sqrtF0) / (1.0 - sqrtF0);
}
vec3 mx_f0_to_ior(vec3 F0)
{
    vec3 sqrtF0 = sqrt(clamp(F0, 0.01, 0.99));
    return (vec3(1.0) + sqrtF0) / (vec3(1.0) - sqrtF0);
}

// https://renderwonk.com/publications/wp-generalization-adobe/gen-adobe.pdf
vec3 mx_fresnel_hoffman_schlick(float cosTheta, FresnelData fd)
{
    const float COS_THETA_MAX = 1.0 / 7.0;
    const float COS_THETA_FACTOR = 1.0 / (COS_THETA_MAX * pow(1.0 - COS_THETA_MAX, 6.0));

    float x = clamp(cosTheta, 0.0, 1.0);
    vec3 a = mix(fd.F0, fd.F90, pow(1.0 - COS_THETA_MAX, fd.exponent)) * (vec3(1.0) - fd.F82) * COS_THETA_FACTOR;
    return mix(fd.F0, fd.F90, pow(1.0 - x, fd.exponent)) - a * x * mx_pow6(1.0 - x);
}

// https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
float mx_fresnel_dielectric(float cosTheta, float ior)
{
    float c = cosTheta;
    float g2 = ior*ior + c*c - 1.0;
    if (g2 < 0.0)
    {
        // Total internal reflection
        return 1.0;
    }

    float g = sqrt(g2);
    return 0.5 * mx_square((g - c) / (g + c)) *
                (1.0 + mx_square(((g + c) * c - 1.0) / ((g - c) * c + 1.0)));
}

// https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
vec2 mx_fresnel_dielectric_polarized(float cosTheta, float ior)
{
    float cosTheta2 = mx_square(clamp(cosTheta, 0.0, 1.0));
    float sinTheta2 = 1.0 - cosTheta2;

    float t0 = max(ior * ior - sinTheta2, 0.0);
    float t1 = t0 + cosTheta2;
    float t2 = 2.0 * sqrt(t0) * cosTheta;
    float Rs = (t1 - t2) / (t1 + t2);

    float t3 = cosTheta2 * t0 + sinTheta2 * sinTheta2;
    float t4 = t2 * sinTheta2;
    float Rp = Rs * (t3 - t4) / (t3 + t4);

    return vec2(Rp, Rs);
}

// https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
void mx_fresnel_conductor_polarized(float cosTheta, vec3 n, vec3 k, out vec3 Rp, out vec3 Rs)
{
    float cosTheta2 = mx_square(clamp(cosTheta, 0.0, 1.0));
    float sinTheta2 = 1.0 - cosTheta2;
    vec3 n2 = n * n;
    vec3 k2 = k * k;

    vec3 t0 = n2 - k2 - vec3(sinTheta2);
    vec3 a2plusb2 = sqrt(t0 * t0 + 4.0 * n2 * k2);
    vec3 t1 = a2plusb2 + vec3(cosTheta2);
    vec3 a = sqrt(max(0.5 * (a2plusb2 + t0), 0.0));
    vec3 t2 = 2.0 * a * cosTheta;
    Rs = (t1 - t2) / (t1 + t2);

    vec3 t3 = cosTheta2 * a2plusb2 + vec3(sinTheta2 * sinTheta2);
    vec3 t4 = t2 * sinTheta2;
    Rp = Rs * (t3 - t4) / (t3 + t4);
}

vec3 mx_fresnel_conductor(float cosTheta, vec3 n, vec3 k)
{
    vec3 Rp, Rs;
    mx_fresnel_conductor_polarized(cosTheta, n, k, Rp, Rs);
    return 0.5 * (Rp  + Rs);
}

// https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html
void mx_fresnel_conductor_phase_polarized(float cosTheta, float eta1, vec3 eta2, vec3 kappa2, out vec3 phiP, out vec3 phiS)
{
    vec3 k2 = kappa2 / eta2;
    vec3 sinThetaSqr = vec3(1.0) - cosTheta * cosTheta;
    vec3 A = eta2*eta2*(vec3(1.0)-k2*k2) - eta1*eta1*sinThetaSqr;
    vec3 B = sqrt(A*A + mx_square(2.0*eta2*eta2*k2));
    vec3 U = sqrt((A+B)/2.0);
    vec3 V = max(vec3(0.0), sqrt((B-A)/2.0));

    phiS = mx_atan(2.0*eta1*V*cosTheta, U*U + V*V - mx_square(eta1*cosTheta));
    phiP = mx_atan(2.0*eta1*eta2*eta2*cosTheta * (2.0*k2*U - (vec3(1.0)-k2*k2) * V),
                   mx_square(eta2*eta2*(vec3(1.0)+k2*k2)*cosTheta) - eta1*eta1*(U*U+V*V));
}

// https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html
vec3 mx_eval_sensitivity(float opd, vec3 shift)
{
    // Use Gaussian fits, given by 3 parameters: val, pos and var
    float phase = 2.0*M_PI * opd;
    vec3 val = vec3(5.4856e-13, 4.4201e-13, 5.2481e-13);
    vec3 pos = vec3(1.6810e+06, 1.7953e+06, 2.2084e+06);
    vec3 var = vec3(4.3278e+09, 9.3046e+09, 6.6121e+09);
    vec3 xyz = val * sqrt(2.0*M_PI * var) * mx_cos(pos * phase + shift) * exp(- var * phase*phase);
    xyz.x   += 9.7470e-14 * sqrt(2.0*M_PI * 4.5282e+09) * mx_cos(2.2399e+06 * phase + shift[0]) * exp(- 4.5282e+09 * phase*phase);
    return xyz / 1.0685e-7;
}

// A Practical Extension to Microfacet Theory for the Modeling of Varying Iridescence
// https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html
vec3 mx_fresnel_airy(float cosTheta, FresnelData fd)
{
    // XYZ to CIE 1931 RGB color space (using neutral E illuminant)
    const mat3 XYZ_TO_RGB = mat3(2.3706743, -0.5138850, 0.0052982, -0.9000405, 1.4253036, -0.0146949, -0.4706338, 0.0885814, 1.0093968);

    // Assume vacuum on the outside
    float eta1 = 1.0;
    float eta2 = max(fd.tf_ior, eta1);
    vec3 eta3 = (fd.model == FRESNEL_MODEL_SCHLICK) ? mx_f0_to_ior(fd.F0) : fd.ior;
    vec3 kappa3 = (fd.model == FRESNEL_MODEL_SCHLICK) ? vec3(0.0) : fd.extinction;
    float cosThetaT = sqrt(1.0 - (1.0 - mx_square(cosTheta)) * mx_square(eta1 / eta2));

    // First interface
    vec2 R12 = mx_fresnel_dielectric_polarized(cosTheta, eta2 / eta1);
    if (cosThetaT <= 0.0)
    {
        // Total internal reflection
        R12 = vec2(1.0);
    }
    vec2 T121 = vec2(1.0) - R12;

    // Second interface
    vec3 R23p, R23s;
    if (fd.model == FRESNEL_MODEL_SCHLICK)
    {
        vec3 f = mx_fresnel_hoffman_schlick(cosThetaT, fd);
        R23p = 0.5 * f;
        R23s = 0.5 * f;
    }
    else
    {
        mx_fresnel_conductor_polarized(cosThetaT, eta3 / eta2, kappa3 / eta2, R23p, R23s);
    }

    // Phase shift
    float cosB = mx_cos(mx_atan(eta2 / eta1));
    vec2 phi21 = vec2(cosTheta < cosB ? 0.0 : M_PI, M_PI);
    vec3 phi23p, phi23s;
    if (fd.model == FRESNEL_MODEL_SCHLICK)
    {
        phi23p = vec3((eta3[0] < eta2) ? M_PI : 0.0,
                      (eta3[1] < eta2) ? M_PI : 0.0,
                      (eta3[2] < eta2) ? M_PI : 0.0);
        phi23s = phi23p;
    }
    else
    {
        mx_fresnel_conductor_phase_polarized(cosThetaT, eta2, eta3, kappa3, phi23p, phi23s);
    }
    vec3 r123p = max(sqrt(R12.x*R23p), 0.0);
    vec3 r123s = max(sqrt(R12.y*R23s), 0.0);

    // Iridescence term
    vec3 I = vec3(0.0);
    vec3 Cm, Sm;

    // Optical path difference
    float distMeters = fd.tf_thickness * 1.0e-9;
    float opd = 2.0 * eta2 * cosThetaT * distMeters;

    // Iridescence term using spectral antialiasing for Parallel polarization

    // Reflectance term for m=0 (DC term amplitude)
    vec3 Rs = (mx_square(T121.x) * R23p) / (vec3(1.0) - R12.x*R23p);
    I += R12.x + Rs;

    // Reflectance term for m>0 (pairs of diracs)
    Cm = Rs - T121.x;
    for (int m = 1; m <= AIRY_FRESNEL_ITERATIONS; m++)
    {
        Cm *= r123p;
        Sm  = 2.0 * mx_eval_sensitivity(float(m) * opd, float(m)*(phi23p+vec3(phi21.x)));
        I  += Cm*Sm;
    }

    // Iridescence term using spectral antialiasing for Perpendicular polarization

    // Reflectance term for m=0 (DC term amplitude)
    vec3 Rp = (mx_square(T121.y) * R23s) / (vec3(1.0) - R12.y*R23s);
    I += R12.y + Rp;

    // Reflectance term for m>0 (pairs of diracs)
    Cm = Rp - T121.y;
    for (int m = 1; m <= AIRY_FRESNEL_ITERATIONS; m++)
    {
        Cm *= r123s;
        Sm  = 2.0 * mx_eval_sensitivity(float(m) * opd, float(m)*(phi23s+vec3(phi21.y)));
        I  += Cm*Sm;
    }

    // Average parallel and perpendicular polarization
    I *= 0.5;

    // Convert back to RGB reflectance
    I = clamp(mx_matrix_mul(XYZ_TO_RGB, I), 0.0, 1.0);

    return I;
}

FresnelData mx_init_fresnel_dielectric(float ior, float tf_thickness, float tf_ior)
{
    FresnelData fd;
    fd.model = FRESNEL_MODEL_DIELECTRIC;
    fd.airy = tf_thickness > 0.0;
    fd.ior = vec3(ior);
    fd.extinction = vec3(0.0);
    fd.F0 = vec3(0.0);
    fd.F82 = vec3(0.0);
    fd.F90 = vec3(0.0);
    fd.exponent = 0.0;
    fd.tf_thickness = tf_thickness;
    fd.tf_ior = tf_ior;
    fd.refraction = false;
    return fd;
}

FresnelData mx_init_fresnel_conductor(vec3 ior, vec3 extinction, float tf_thickness, float tf_ior)
{
    FresnelData fd;
    fd.model = FRESNEL_MODEL_CONDUCTOR;
    fd.airy = tf_thickness > 0.0;
    fd.ior = ior;
    fd.extinction = extinction;
    fd.F0 = vec3(0.0);
    fd.F82 = vec3(0.0);
    fd.F90 = vec3(0.0);
    fd.exponent = 0.0;
    fd.tf_thickness = tf_thickness;
    fd.tf_ior = tf_ior;
    fd.refraction = false;
    return fd;
}

FresnelData mx_init_fresnel_schlick(vec3 F0, vec3 F82, vec3 F90, float exponent, float tf_thickness, float tf_ior)
{
    FresnelData fd;
    fd.model = FRESNEL_MODEL_SCHLICK;
    fd.airy = tf_thickness > 0.0;
    fd.ior = vec3(0.0);
    fd.extinction = vec3(0.0);
    fd.F0 = F0;
    fd.F82 = F82;
    fd.F90 = F90;
    fd.exponent = exponent;
    fd.tf_thickness = tf_thickness;
    fd.tf_ior = tf_ior;
    fd.refraction = false;
    return fd;
}

vec3 mx_compute_fresnel(float cosTheta, FresnelData fd)
{
    if (fd.airy)
    {
         return mx_fresnel_airy(cosTheta, fd);
    }
    else if (fd.model == FRESNEL_MODEL_DIELECTRIC)
    {
        return vec3(mx_fresnel_dielectric(cosTheta, fd.ior.x));
    }
    else if (fd.model == FRESNEL_MODEL_CONDUCTOR)
    {
        return mx_fresnel_conductor(cosTheta, fd.ior, fd.extinction);
    }
    else // FRESNEL_MODEL_SCHLICK
    {
        return mx_fresnel_hoffman_schlick(cosTheta, fd);
    }
}

// Directional albedo accounting for different Fresnel functions.
vec3 mx_ggx_dir_albedo(float NdotV, float alpha, FresnelData fd)
{
    if (fd.airy)
    {
        // Approximation using a blend between mirror (alpha = 0)
        // and rougher cases. This helps to maintain angular
        // color variation at lower roughness values.
        vec3 mirrorDirAlbedo = mx_compute_fresnel(NdotV, fd);
        vec3 F0 = mx_fresnel_airy(1.0, fd);
        vec3 roughDirAlbedo = mx_ggx_dir_albedo(NdotV, alpha, F0, vec3(1.0));
        return mix(mirrorDirAlbedo, roughDirAlbedo, sqrt(alpha));
    }
    else if (fd.model == FRESNEL_MODEL_DIELECTRIC)
    {
        float F0 = mx_ior_to_f0(fd.ior.x);
        return mx_ggx_dir_albedo(NdotV, alpha, vec3(F0), vec3(1.0));
    }
    else if (fd.model == FRESNEL_MODEL_CONDUCTOR)
    {
        vec3 F0 = mx_fresnel_conductor(1.0, fd.ior, fd.extinction);
        return mx_ggx_dir_albedo(NdotV, alpha, F0, vec3(1.0));
    }
    else // FRESNEL_MODEL_SCHLICK
    {
        return mx_ggx_dir_albedo(NdotV, alpha, fd.F0, fd.F90);
    }
}

// Compute the refraction of a ray through a solid sphere.
vec3 mx_refraction_solid_sphere(vec3 R, vec3 N, float ior)
{
    R = refract(R, N, 1.0 / ior);
    vec3 N1 = normalize(R * dot(R, N) - N * 0.5);
    return refract(R, N1, ior);
}

vec2 mx_latlong_projection(vec3 dir)
{
    float latitude = -mx_asin(dir.y) * M_PI_INV + 0.5;
    float longitude = mx_atan(dir.x, -dir.z) * M_PI_INV * 0.5 + 0.5;
    return vec2(longitude, latitude);
}

vec3 mx_latlong_map_lookup(vec3 dir, mat4 transform, float lod, sampler2D tex_sampler)
{
    vec3 envDir = normalize(mx_matrix_mul(transform, vec4(dir,0.0)).xyz);
    vec2 uv = mx_latlong_projection(envDir);
    return textureLod(tex_sampler, uv, lod).rgb;
}

// Return the mip level with the appropriate coverage for a filtered importance sample.
// https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch20.html
// Section 20.4 Equation 13
float mx_latlong_compute_lod(vec3 dir, float pdf, float maxMipLevel, int envSamples)
{
    const float MIP_LEVEL_OFFSET = 1.5;
    float effectiveMaxMipLevel = maxMipLevel - MIP_LEVEL_OFFSET;
    float distortion = sqrt(1.0 - mx_square(dir.y));
    return max(effectiveMaxMipLevel - 0.5 * log2(float(envSamples) * pdf * distortion), 0.0);
}

vec3 mx_environment_radiance(vec3 N, vec3 V, vec3 X, vec2 alpha, int distribution, FresnelData fd)
{
    // Generate tangent frame.
    X = normalize(X - dot(X, N) * N);
    vec3 Y = cross(N, X);
    mat3 tangentToWorld = mat3(X, Y, N);

    // Transform the view vector to tangent space.
    V = vec3(dot(V, X), dot(V, Y), dot(V, N));

    // Compute derived properties.
    float NdotV = clamp(V.z, M_FLOAT_EPS, 1.0);
    float avgAlpha = mx_average_alpha(alpha);
    float G1V = mx_ggx_smith_G1(NdotV, avgAlpha);
    
    // Integrate outgoing radiance using filtered importance sampling.
    // http://cgg.mff.cuni.cz/~jaroslav/papers/2008-egsr-fis/2008-egsr-fis-final-embedded.pdf
    vec3 radiance = vec3(0.0);
    int envRadianceSamples = u_envRadianceSamples;
    for (int i = 0; i < envRadianceSamples; i++)
    {
        vec2 Xi = mx_spherical_fibonacci(i, envRadianceSamples);

        // Compute the half vector and incoming light direction.
        vec3 H = mx_ggx_importance_sample_VNDF(Xi, V, alpha);
        vec3 L = fd.refraction ? mx_refraction_solid_sphere(-V, H, fd.ior.x) : -reflect(V, H);
        
        // Compute dot products for this sample.
        float NdotL = clamp(L.z, M_FLOAT_EPS, 1.0);
        float VdotH = clamp(dot(V, H), M_FLOAT_EPS, 1.0);

        // Sample the environment light from the given direction.
        vec3 Lw = mx_matrix_mul(tangentToWorld, L);
        float pdf = mx_ggx_VNDF_reflection_PDF(H, alpha, G1V, NdotV);
        float lod = mx_latlong_compute_lod(Lw, pdf, float(u_envRadianceMips - 1), envRadianceSamples);
        vec3 sampleColor = mx_latlong_map_lookup(Lw, u_envMatrix, lod, u_envRadiance);

        // Compute the Fresnel term.
        vec3 F = mx_compute_fresnel(VdotH, fd);

        // Compute the geometric term.
        float G = mx_ggx_smith_G2(NdotL, NdotV, avgAlpha);

        // Compute the combined FG term, which simplifies to inverted Fresnel for refraction.
        vec3 FG = fd.refraction ? vec3(1.0) - F : F * G;

        // Add the radiance contribution of this sample.
        // From https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
        //   incidentLight = sampleColor * NdotL
        //   microfacetSpecular = D * F * G / (4 * NdotL * NdotV)
        //   pdf = D * G1V / (4 * NdotV);
        //   radiance = incidentLight * microfacetSpecular / pdf
        radiance += sampleColor * FG;
    }

    // Apply the global component of the geometric term and normalize.
    radiance /= G1V * float(envRadianceSamples);

    // Return the final radiance.
    return (u_envRadianceSamples == 0 ? vec3(0.0) : radiance) * u_envLightIntensity;
}

vec3 mx_environment_irradiance(vec3 N)
{
    vec3 Li = mx_latlong_map_lookup(N, u_envMatrix, 0.0, u_envIrradiance);
    return Li * u_envLightIntensity;
}


vec3 mx_surface_transmission(vec3 N, vec3 V, vec3 X, vec2 alpha, int distribution, FresnelData fd, vec3 tint)
{
    // Approximate the appearance of surface transmission as glossy
    // environment map refraction, ignoring any scene geometry that might
    // be visible through the surface.
    fd.refraction = true;
    if (u_refractionTwoSided)
    {
        tint = mx_square(tint);
    }
    return mx_environment_radiance(N, V, X, alpha, distribution, fd) * tint;
}

void NG_separate2_vector2(vec2 in1, out float outx, out float outy)
{
    const int N_extract_0_index_tmp = 0;
    float N_extract_0_out = in1[N_extract_0_index_tmp];
    const int N_extract_1_index_tmp = 1;
    float N_extract_1_out = in1[N_extract_1_index_tmp];
    outx = N_extract_0_out;
    outy = N_extract_1_out;
}

void mx_rotate_vector2(vec2 _in, float amount, out vec2 result)
{
    float rotationRadians = mx_radians(amount);
    float sa = mx_sin(rotationRadians);
    float ca = mx_cos(rotationRadians);
    result = vec2(ca*_in.x + sa*_in.y, -sa*_in.x + ca*_in.y);
}

/*
Noise Library.

This library is a modified version of the noise library found in
Open Shading Language:
github.com/imageworks/OpenShadingLanguage/blob/master/src/include/OSL/oslnoise.h

It contains the subset of noise types needed to implement the MaterialX
standard library. The modifications are mainly conversions from C++ to GLSL.
Produced results should be identical to the OSL noise functions.

Original copyright notice:
------------------------------------------------------------------------
Copyright (c) 2009-2010 Sony Pictures Imageworks Inc., et al.
All Rights Reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
* Neither the name of Sony Pictures Imageworks nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
------------------------------------------------------------------------
*/

float mx_select(bool b, float t, float f)
{
    return b ? t : f;
}

float mx_negate_if(float val, bool b)
{
    return b ? -val : val;
}

int mx_floor(float x)
{
    return int(floor(x));
}

// return mx_floor as well as the fractional remainder
float mx_floorfrac(float x, out int i)
{
    i = mx_floor(x);
    return x - float(i);
}

float mx_bilerp(float v0, float v1, float v2, float v3, float s, float t)
{
    float s1 = 1.0 - s;
    return (1.0 - t) * (v0*s1 + v1*s) + t * (v2*s1 + v3*s);
}
vec3 mx_bilerp(vec3 v0, vec3 v1, vec3 v2, vec3 v3, float s, float t)
{
    float s1 = 1.0 - s;
    return (1.0 - t) * (v0*s1 + v1*s) + t * (v2*s1 + v3*s);
}
float mx_trilerp(float v0, float v1, float v2, float v3, float v4, float v5, float v6, float v7, float s, float t, float r)
{
    float s1 = 1.0 - s;
    float t1 = 1.0 - t;
    float r1 = 1.0 - r;
    return (r1*(t1*(v0*s1 + v1*s) + t*(v2*s1 + v3*s)) +
            r*(t1*(v4*s1 + v5*s) + t*(v6*s1 + v7*s)));
}
vec3 mx_trilerp(vec3 v0, vec3 v1, vec3 v2, vec3 v3, vec3 v4, vec3 v5, vec3 v6, vec3 v7, float s, float t, float r)
{
    float s1 = 1.0 - s;
    float t1 = 1.0 - t;
    float r1 = 1.0 - r;
    return (r1*(t1*(v0*s1 + v1*s) + t*(v2*s1 + v3*s)) +
            r*(t1*(v4*s1 + v5*s) + t*(v6*s1 + v7*s)));
}

// 2 and 3 dimensional gradient functions - perform a dot product against a
// randomly chosen vector. Note that the gradient vector is not normalized, but
// this only affects the overall "scale" of the result, so we simply account for
// the scale by multiplying in the corresponding "perlin" function.
float mx_gradient_float(uint hash, float x, float y)
{
    // 8 possible directions (+-1,+-2) and (+-2,+-1)
    uint h = hash & 7u;
    float u = mx_select(h<4u, x, y);
    float v = 2.0 * mx_select(h<4u, y, x);
    // compute the dot product with (x,y).
    return mx_negate_if(u, bool(h&1u)) + mx_negate_if(v, bool(h&2u));
}
float mx_gradient_float(uint hash, float x, float y, float z)
{
    // use vectors pointing to the edges of the cube
    uint h = hash & 15u;
    float u = mx_select(h<8u, x, y);
    float v = mx_select(h<4u, y, mx_select((h==12u)||(h==14u), x, z));
    return mx_negate_if(u, bool(h&1u)) + mx_negate_if(v, bool(h&2u));
}
vec3 mx_gradient_vec3(uvec3 hash, float x, float y)
{
    return vec3(mx_gradient_float(hash.x, x, y), mx_gradient_float(hash.y, x, y), mx_gradient_float(hash.z, x, y));
}
vec3 mx_gradient_vec3(uvec3 hash, float x, float y, float z)
{
    return vec3(mx_gradient_float(hash.x, x, y, z), mx_gradient_float(hash.y, x, y, z), mx_gradient_float(hash.z, x, y, z));
}
// Scaling factors to normalize the result of gradients above.
// These factors were experimentally calculated to be:
//    2D:   0.6616
//    3D:   0.9820
float mx_gradient_scale2d(float v) { return 0.6616 * v; }
float mx_gradient_scale3d(float v) { return 0.9820 * v; }
vec3 mx_gradient_scale2d(vec3 v) { return 0.6616 * v; }
vec3 mx_gradient_scale3d(vec3 v) { return 0.9820 * v; }

/// Bitwise circular rotation left by k bits (for 32 bit unsigned integers)
uint mx_rotl32(uint x, int k)
{
    return (x<<k) | (x>>(32-k));
}

void mx_bjmix(inout uint a, inout uint b, inout uint c)
{
    a -= c; a ^= mx_rotl32(c, 4); c += b;
    b -= a; b ^= mx_rotl32(a, 6); a += c;
    c -= b; c ^= mx_rotl32(b, 8); b += a;
    a -= c; a ^= mx_rotl32(c,16); c += b;
    b -= a; b ^= mx_rotl32(a,19); a += c;
    c -= b; c ^= mx_rotl32(b, 4); b += a;
}

// Mix up and combine the bits of a, b, and c (doesn't change them, but
// returns a hash of those three original values).
uint mx_bjfinal(uint a, uint b, uint c)
{
    c ^= b; c -= mx_rotl32(b,14);
    a ^= c; a -= mx_rotl32(c,11);
    b ^= a; b -= mx_rotl32(a,25);
    c ^= b; c -= mx_rotl32(b,16);
    a ^= c; a -= mx_rotl32(c,4);
    b ^= a; b -= mx_rotl32(a,14);
    c ^= b; c -= mx_rotl32(b,24);
    return c;
}

// Convert a 32 bit integer into a floating point number in [0,1]
float mx_bits_to_01(uint bits)
{
    return float(bits) / float(uint(0xffffffff));
}

float mx_fade(float t)
{
   return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

uint mx_hash_int(int x)
{
    uint len = 1u;
    uint seed = uint(0xdeadbeef) + (len << 2u) + 13u;
    return mx_bjfinal(seed+uint(x), seed, seed);
}

uint mx_hash_int(int x, int y)
{
    uint len = 2u;
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (len << 2u) + 13u;
    a += uint(x);
    b += uint(y);
    return mx_bjfinal(a, b, c);
}

uint mx_hash_int(int x, int y, int z)
{
    uint len = 3u;
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (len << 2u) + 13u;
    a += uint(x);
    b += uint(y);
    c += uint(z);
    return mx_bjfinal(a, b, c);
}

uint mx_hash_int(int x, int y, int z, int xx)
{
    uint len = 4u;
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (len << 2u) + 13u;
    a += uint(x);
    b += uint(y);
    c += uint(z);
    mx_bjmix(a, b, c);
    a += uint(xx);
    return mx_bjfinal(a, b, c);
}

uint mx_hash_int(int x, int y, int z, int xx, int yy)
{
    uint len = 5u;
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (len << 2u) + 13u;
    a += uint(x);
    b += uint(y);
    c += uint(z);
    mx_bjmix(a, b, c);
    a += uint(xx);
    b += uint(yy);
    return mx_bjfinal(a, b, c);
}

uvec3 mx_hash_vec3(int x, int y)
{
    uint h = mx_hash_int(x, y);
    // we only need the low-order bits to be random, so split out
    // the 32 bit result into 3 parts for each channel
    uvec3 result;
    result.x = (h      ) & 0xFFu;
    result.y = (h >> 8 ) & 0xFFu;
    result.z = (h >> 16) & 0xFFu;
    return result;
}

uvec3 mx_hash_vec3(int x, int y, int z)
{
    uint h = mx_hash_int(x, y, z);
    // we only need the low-order bits to be random, so split out
    // the 32 bit result into 3 parts for each channel
    uvec3 result;
    result.x = (h      ) & 0xFFu;
    result.y = (h >> 8 ) & 0xFFu;
    result.z = (h >> 16) & 0xFFu;
    return result;
}

float mx_perlin_noise_float(vec2 p)
{
    int X, Y;
    float fx = mx_floorfrac(p.x, X);
    float fy = mx_floorfrac(p.y, Y);
    float u = mx_fade(fx);
    float v = mx_fade(fy);
    float result = mx_bilerp(
        mx_gradient_float(mx_hash_int(X  , Y  ), fx    , fy     ),
        mx_gradient_float(mx_hash_int(X+1, Y  ), fx-1.0, fy     ),
        mx_gradient_float(mx_hash_int(X  , Y+1), fx    , fy-1.0),
        mx_gradient_float(mx_hash_int(X+1, Y+1), fx-1.0, fy-1.0),
        u, v);
    return mx_gradient_scale2d(result);
}

float mx_perlin_noise_float(vec3 p)
{
    int X, Y, Z;
    float fx = mx_floorfrac(p.x, X);
    float fy = mx_floorfrac(p.y, Y);
    float fz = mx_floorfrac(p.z, Z);
    float u = mx_fade(fx);
    float v = mx_fade(fy);
    float w = mx_fade(fz);
    float result = mx_trilerp(
        mx_gradient_float(mx_hash_int(X  , Y  , Z  ), fx    , fy    , fz     ),
        mx_gradient_float(mx_hash_int(X+1, Y  , Z  ), fx-1.0, fy    , fz     ),
        mx_gradient_float(mx_hash_int(X  , Y+1, Z  ), fx    , fy-1.0, fz     ),
        mx_gradient_float(mx_hash_int(X+1, Y+1, Z  ), fx-1.0, fy-1.0, fz     ),
        mx_gradient_float(mx_hash_int(X  , Y  , Z+1), fx    , fy    , fz-1.0),
        mx_gradient_float(mx_hash_int(X+1, Y  , Z+1), fx-1.0, fy    , fz-1.0),
        mx_gradient_float(mx_hash_int(X  , Y+1, Z+1), fx    , fy-1.0, fz-1.0),
        mx_gradient_float(mx_hash_int(X+1, Y+1, Z+1), fx-1.0, fy-1.0, fz-1.0),
        u, v, w);
    return mx_gradient_scale3d(result);
}

vec3 mx_perlin_noise_vec3(vec2 p)
{
    int X, Y;
    float fx = mx_floorfrac(p.x, X);
    float fy = mx_floorfrac(p.y, Y);
    float u = mx_fade(fx);
    float v = mx_fade(fy);
    vec3 result = mx_bilerp(
        mx_gradient_vec3(mx_hash_vec3(X  , Y  ), fx    , fy     ),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y  ), fx-1.0, fy     ),
        mx_gradient_vec3(mx_hash_vec3(X  , Y+1), fx    , fy-1.0),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y+1), fx-1.0, fy-1.0),
        u, v);
    return mx_gradient_scale2d(result);
}

vec3 mx_perlin_noise_vec3(vec3 p)
{
    int X, Y, Z;
    float fx = mx_floorfrac(p.x, X);
    float fy = mx_floorfrac(p.y, Y);
    float fz = mx_floorfrac(p.z, Z);
    float u = mx_fade(fx);
    float v = mx_fade(fy);
    float w = mx_fade(fz);
    vec3 result = mx_trilerp(
        mx_gradient_vec3(mx_hash_vec3(X  , Y  , Z  ), fx    , fy    , fz     ),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y  , Z  ), fx-1.0, fy    , fz     ),
        mx_gradient_vec3(mx_hash_vec3(X  , Y+1, Z  ), fx    , fy-1.0, fz     ),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y+1, Z  ), fx-1.0, fy-1.0, fz     ),
        mx_gradient_vec3(mx_hash_vec3(X  , Y  , Z+1), fx    , fy    , fz-1.0),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y  , Z+1), fx-1.0, fy    , fz-1.0),
        mx_gradient_vec3(mx_hash_vec3(X  , Y+1, Z+1), fx    , fy-1.0, fz-1.0),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y+1, Z+1), fx-1.0, fy-1.0, fz-1.0),
        u, v, w);
    return mx_gradient_scale3d(result);
}

float mx_cell_noise_float(float p)
{
    int ix = mx_floor(p);
    return mx_bits_to_01(mx_hash_int(ix));
}

float mx_cell_noise_float(vec2 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    return mx_bits_to_01(mx_hash_int(ix, iy));
}

float mx_cell_noise_float(vec3 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    int iz = mx_floor(p.z);
    return mx_bits_to_01(mx_hash_int(ix, iy, iz));
}

float mx_cell_noise_float(vec4 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    int iz = mx_floor(p.z);
    int iw = mx_floor(p.w);
    return mx_bits_to_01(mx_hash_int(ix, iy, iz, iw));
}

vec3 mx_cell_noise_vec3(float p)
{
    int ix = mx_floor(p);
    return vec3(
            mx_bits_to_01(mx_hash_int(ix, 0)),
            mx_bits_to_01(mx_hash_int(ix, 1)),
            mx_bits_to_01(mx_hash_int(ix, 2))
    );
}

vec3 mx_cell_noise_vec3(vec2 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    return vec3(
            mx_bits_to_01(mx_hash_int(ix, iy, 0)),
            mx_bits_to_01(mx_hash_int(ix, iy, 1)),
            mx_bits_to_01(mx_hash_int(ix, iy, 2))
    );
}

vec3 mx_cell_noise_vec3(vec3 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    int iz = mx_floor(p.z);
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (4u << 2u) + 13u;
    a += uint(ix);
    b += uint(iy);
    c += uint(iz);
    mx_bjmix(a, b, c);
    return vec3(
            mx_bits_to_01(mx_bjfinal(a,      b, c)),
            mx_bits_to_01(mx_bjfinal(a + 1u, b, c)),
            mx_bits_to_01(mx_bjfinal(a + 2u, b, c))
    );
}

vec3 mx_cell_noise_vec3(vec4 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    int iz = mx_floor(p.z);
    int iw = mx_floor(p.w);
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (5u << 2u) + 13u;
    a += uint(ix);
    b += uint(iy);
    c += uint(iz);
    mx_bjmix(a, b, c);
    a += uint(iw);
    return vec3(
            mx_bits_to_01(mx_bjfinal(a, b,      c)),
            mx_bits_to_01(mx_bjfinal(a, b + 1u, c)),
            mx_bits_to_01(mx_bjfinal(a, b + 2u, c))
    );
}

float mx_fractal2d_noise_float(vec2 p, int octaves, float lacunarity, float diminish)
{
    float result = 0.0;
    float amplitude = 1.0;
    for (int i = 0;  i < octaves; ++i)
    {
        result += amplitude * mx_perlin_noise_float(p);
        amplitude *= diminish;
        p *= lacunarity;
    }
    return result;
}

vec3 mx_fractal2d_noise_vec3(vec2 p, int octaves, float lacunarity, float diminish)
{
    vec3 result = vec3(0.0);
    float amplitude = 1.0;
    for (int i = 0;  i < octaves; ++i)
    {
        result += amplitude * mx_perlin_noise_vec3(p);
        amplitude *= diminish;
        p *= lacunarity;
    }
    return result;
}

vec2 mx_fractal2d_noise_vec2(vec2 p, int octaves, float lacunarity, float diminish)
{
    return vec2(mx_fractal2d_noise_float(p, octaves, lacunarity, diminish),
                mx_fractal2d_noise_float(p+vec2(19, 193), octaves, lacunarity, diminish));
}

vec4 mx_fractal2d_noise_vec4(vec2 p, int octaves, float lacunarity, float diminish)
{
    vec3  c = mx_fractal2d_noise_vec3(p, octaves, lacunarity, diminish);
    float f = mx_fractal2d_noise_float(p+vec2(19, 193), octaves, lacunarity, diminish);
    return vec4(c, f);
}

float mx_fractal3d_noise_float(vec3 p, int octaves, float lacunarity, float diminish)
{
    float result = 0.0;
    float amplitude = 1.0;
    for (int i = 0;  i < octaves; ++i)
    {
        result += amplitude * mx_perlin_noise_float(p);
        amplitude *= diminish;
        p *= lacunarity;
    }
    return result;
}

vec3 mx_fractal3d_noise_vec3(vec3 p, int octaves, float lacunarity, float diminish)
{
    vec3 result = vec3(0.0);
    float amplitude = 1.0;
    for (int i = 0;  i < octaves; ++i)
    {
        result += amplitude * mx_perlin_noise_vec3(p);
        amplitude *= diminish;
        p *= lacunarity;
    }
    return result;
}

vec2 mx_fractal3d_noise_vec2(vec3 p, int octaves, float lacunarity, float diminish)
{
    return vec2(mx_fractal3d_noise_float(p, octaves, lacunarity, diminish),
                mx_fractal3d_noise_float(p+vec3(19, 193, 17), octaves, lacunarity, diminish));
}

vec4 mx_fractal3d_noise_vec4(vec3 p, int octaves, float lacunarity, float diminish)
{
    vec3  c = mx_fractal3d_noise_vec3(p, octaves, lacunarity, diminish);
    float f = mx_fractal3d_noise_float(p+vec3(19, 193, 17), octaves, lacunarity, diminish);
    return vec4(c, f);
}

vec2 mx_worley_cell_position(int x, int y, int xoff, int yoff, float jitter)
{
    vec3  tmp = mx_cell_noise_vec3(vec2(x+xoff, y+yoff));
    vec2  off = vec2(tmp.x, tmp.y);

    off -= 0.5f;
    off *= jitter;
    off += 0.5f;
    
    return vec2(float(x), float(y)) + off;
}

vec3 mx_worley_cell_position(int x, int y, int z, int xoff, int yoff, int zoff, float jitter)
{
    vec3  off = mx_cell_noise_vec3(vec3(x+xoff, y+yoff, z+zoff));

    off -= 0.5f;
    off *= jitter;
    off += 0.5f;
    
    return vec3(float(x), float(y), float(z)) + off;
}

float mx_worley_distance(vec2 p, int x, int y, int xoff, int yoff, float jitter, int metric)
{
    vec2 cellpos = mx_worley_cell_position(x, y, xoff, yoff, jitter);
    vec2 diff = cellpos - p;
    if (metric == 2)
        return abs(diff.x) + abs(diff.y);       // Manhattan distance
    if (metric == 3)
        return max(abs(diff.x), abs(diff.y));   // Chebyshev distance
    // Either Euclidean or Distance^2
    return dot(diff, diff);
}

float mx_worley_distance(vec3 p, int x, int y, int z, int xoff, int yoff, int zoff, float jitter, int metric)
{
    vec3 cellpos = mx_worley_cell_position(x, y, z, xoff, yoff, zoff, jitter);
    vec3 diff = cellpos - p;
    if (metric == 2)
        return abs(diff.x) + abs(diff.y) + abs(diff.z); // Manhattan distance
    if (metric == 3)
        return max(max(abs(diff.x), abs(diff.y)), abs(diff.z)); // Chebyshev distance
    // Either Euclidean or Distance^2
    return dot(diff, diff);
}

float mx_worley_noise_float(vec2 p, float jitter, int style, int metric)
{
    int X, Y;
    float dist;
    vec2 localpos = vec2(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y));
    float sqdist = 1e6f;        // Some big number for jitter > 1 (not all GPUs may be IEEE)
    vec2 minpos = vec2(0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float dist = mx_worley_distance(localpos, x, y, X, Y, jitter, metric);
            vec2 cellpos = mx_worley_cell_position(x, y, X, Y, jitter) - localpos;
            if(dist < sqdist)
            {
                sqdist = dist;
                minpos = cellpos;
            }
        }
    }
    if (style == 1)
        return mx_cell_noise_float(minpos + p);
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

vec2 mx_worley_noise_vec2(vec2 p, float jitter, int style, int metric)
{
    int X, Y;
    vec2 localpos = vec2(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y));
    vec2 sqdist = vec2(1e6f, 1e6f);
    vec2 minpos = vec2(0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float dist = mx_worley_distance(localpos, x, y, X, Y, jitter, metric);
            vec2 cellpos = mx_worley_cell_position(x, y, X, Y, jitter) - localpos;
            if (dist < sqdist.x)
            {
                sqdist.y = sqdist.x;
                sqdist.x = dist;
                minpos = cellpos;
            }
            else if (dist < sqdist.y)
            {
                sqdist.y = dist;
            }
        }
    }
    if (style == 1)
    {
        vec3 tmp = mx_cell_noise_vec3(minpos + p);
        return vec2(tmp.x,tmp.y);
    }
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

vec3 mx_worley_noise_vec3(vec2 p, float jitter, int style, int metric)
{
    int X, Y;
    vec2 localpos = vec2(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y));
    vec3 sqdist = vec3(1e6f, 1e6f, 1e6f);
    vec2 minpos = vec2(0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float dist = mx_worley_distance(localpos, x, y, X, Y, jitter, metric);
            vec2 cellpos = mx_worley_cell_position(x, y, X, Y, jitter) - localpos;
            if (dist < sqdist.x)
            {
                sqdist.z = sqdist.y;
                sqdist.y = sqdist.x;
                sqdist.x = dist;
                minpos = cellpos;
            }
            else if (dist < sqdist.y)
            {
                sqdist.z = sqdist.y;
                sqdist.y = dist;
            }
            else if (dist < sqdist.z)
            {
                sqdist.z = dist;
            }
        }
    }
    if (style == 1)
        return mx_cell_noise_vec3(minpos + p);
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

float mx_worley_noise_float(vec3 p, float jitter, int style, int metric)
{
    int X, Y, Z;
    vec3 localpos = vec3(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y), mx_floorfrac(p.z, Z));
    float sqdist = 1e6f;
    vec3 minpos = vec3(0,0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int z = -1; z <= 1; ++z)
            {
                float dist = mx_worley_distance(localpos, x, y, z, X, Y, Z, jitter, metric);
                vec3 cellpos = mx_worley_cell_position(x, y, z, X, Y, Z, jitter) - localpos;
                if(dist < sqdist)
                {
                    sqdist = dist;
                    minpos = cellpos;
                }
            }
        }
    }
    if (style == 1)
        return mx_cell_noise_float(minpos + p);
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

vec2 mx_worley_noise_vec2(vec3 p, float jitter, int style, int metric)
{
    int X, Y, Z;
    vec3 localpos = vec3(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y), mx_floorfrac(p.z, Z));
    vec2 sqdist = vec2(1e6f, 1e6f);
    vec3 minpos = vec3(0,0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int z = -1; z <= 1; ++z)
            {
                float dist = mx_worley_distance(localpos, x, y, z, X, Y, Z, jitter, metric);
                vec3 cellpos = mx_worley_cell_position(x, y, z, X, Y, Z, jitter) - localpos;
                if (dist < sqdist.x)
                {
                    sqdist.y = sqdist.x;
                    sqdist.x = dist;
                    minpos = cellpos;
                }
                else if (dist < sqdist.y)
                {
                    sqdist.y = dist;
                }
            }
        }
    }
    if (style == 1)
    {
        vec3 tmp = mx_cell_noise_vec3(minpos + p);
        return vec2(tmp.x,tmp.y);
    }
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

vec3 mx_worley_noise_vec3(vec3 p, float jitter, int style, int metric)
{
    int X, Y, Z;
    vec3 localpos = vec3(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y), mx_floorfrac(p.z, Z));
    vec3 sqdist = vec3(1e6f, 1e6f, 1e6f);
    vec3 minpos = vec3(0,0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int z = -1; z <= 1; ++z)
            {
                float dist = mx_worley_distance(localpos, x, y, z, X, Y, Z, jitter, metric);
                vec3 cellpos = mx_worley_cell_position(x, y, z, X, Y, Z, jitter) - localpos;
                if (dist < sqdist.x)
                {
                    sqdist.z = sqdist.y;
                    sqdist.y = sqdist.x;
                    sqdist.x = dist;
                    minpos = cellpos;
                }
                else if (dist < sqdist.y)
                {
                    sqdist.z = sqdist.y;
                    sqdist.y = dist;
                }
                else if (dist < sqdist.z)
                {
                    sqdist.z = dist;
                }
            }
        }
    }
    if (style == 1)
        return mx_cell_noise_vec3(minpos + p);
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

void mx_noise2d_vector2(vec2 amplitude, float pivot, vec2 texcoord, out vec2 result)
{
    vec3 value = mx_perlin_noise_vec3(texcoord);
    result = value.xy * amplitude + pivot;
}


void mx_noise2d_float(float amplitude, float pivot, vec2 texcoord, out float result)
{
    float value = mx_perlin_noise_float(texcoord);
    result = value * amplitude + pivot;
}

/*
Color transform functions.

These functions are modified versions of the color operators found in Open Shading Language:
github.com/imageworks/OpenShadingLanguage/blob/master/src/liboslexec/opcolor.cpp

It contains the subset of color operators needed to implement the MaterialX
standard library. The modifications are for conversions from C++ to GLSL.

Original copyright notice:
------------------------------------------------------------------------
Copyright (c) 2009-2010 Sony Pictures Imageworks Inc., et al.
All Rights Reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
* Neither the name of Sony Pictures Imageworks nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
------------------------------------------------------------------------
*/

vec3 mx_hsvtorgb(vec3 hsv)
{
    // Reference for this technique: Foley & van Dam
    float h = hsv.x; float s = hsv.y; float v = hsv.z;
    if (s < 0.0001f) {
      return vec3 (v, v, v);
    } else {
        h = 6.0f * (h - floor(h));  // expand to [0..6)
        int hi = int(trunc(h));
        float f = h - float(hi);
        float p = v * (1.0f-s);
        float q = v * (1.0f-s*f);
        float t = v * (1.0f-s*(1.0f-f));
        if (hi == 0)
            return vec3 (v, t, p);
        else if (hi == 1)
            return vec3 (q, v, p);
        else if (hi == 2)
            return vec3 (p, v, t);
        else if (hi == 3)
            return vec3 (p, q, v);
        else if (hi == 4)
            return vec3 (t, p, v);
        return vec3 (v, p, q);
    }
}


vec3 mx_rgbtohsv(vec3 c)
{
    // See Foley & van Dam
    float r = c.x; float g = c.y; float b = c.z;
    float mincomp = min (r, min(g, b));
    float maxcomp = max (r, max(g, b));
    float delta = maxcomp - mincomp;  // chroma
    float h, s, v;
    v = maxcomp;
    if (maxcomp > 0.0f)
        s = delta / maxcomp;
    else s = 0.0f;
    if (s <= 0.0f)
        h = 0.0f;
    else {
        if      (r >= maxcomp) h = (g-b) / delta;
        else if (g >= maxcomp) h = 2.0f + (b-r) / delta;
        else                   h = 4.0f + (r-g) / delta;
        h *= (1.0f/6.0f);
        if (h < 0.0f)
            h += 1.0f;
    }
    return vec3(h, s, v);
}

void mx_rgbtohsv_color3(vec3 _in, out vec3 result)
{
    result = mx_rgbtohsv(_in);
}

void NG_separate3_vector3(vec3 in1, out float outx, out float outy, out float outz)
{
    const int N_extract_0_index_tmp = 0;
    float N_extract_0_out = in1[N_extract_0_index_tmp];
    const int N_extract_1_index_tmp = 1;
    float N_extract_1_out = in1[N_extract_1_index_tmp];
    const int N_extract_2_index_tmp = 2;
    float N_extract_2_out = in1[N_extract_2_index_tmp];
    outx = N_extract_0_out;
    outy = N_extract_1_out;
    outz = N_extract_2_out;
}

void NG_convert_vector3_color3(vec3 in1, out vec3 out1)
{
    float separate_outx = 0.0;
    float separate_outy = 0.0;
    float separate_outz = 0.0;
    NG_separate3_vector3(in1, separate_outx, separate_outy, separate_outz);
    vec3 combine_out = vec3(separate_outx,separate_outy,separate_outz);
    out1 = combine_out;
}


void mx_hsvtorgb_color3(vec3 _in, out vec3 result)
{
    result = mx_hsvtorgb(_in);
}

void NG_hsvadjust_color3(vec3 in1, vec3 amount, out vec3 out1)
{
    vec3 N_inhsv_color3_out = vec3(0.0);
    mx_rgbtohsv_color3(in1, N_inhsv_color3_out);
    vec3 N_camount_color3_out = vec3(0.0);
    NG_convert_vector3_color3(amount, N_camount_color3_out);
    const vec3 N_hchans_color3_in2_tmp = vec3(1.000000, 0.000000, 0.000000);
    vec3 N_hchans_color3_out = N_camount_color3_out * N_hchans_color3_in2_tmp;
    const vec3 N_tmp1_color3_in2_tmp = vec3(0.000000, 1.000000, 1.000000);
    vec3 N_tmp1_color3_out = N_camount_color3_out * N_tmp1_color3_in2_tmp;
    vec3 N_tmp2_color3_out = N_inhsv_color3_out + N_hchans_color3_out;
    const vec3 N_svchans_color3_in2_tmp = vec3(1.000000, 0.000000, 0.000000);
    vec3 N_svchans_color3_out = N_tmp1_color3_out + N_svchans_color3_in2_tmp;
    vec3 N_tmp3_color3_out = N_tmp2_color3_out * N_svchans_color3_out;
    vec3 N_torgb_color3_out = vec3(0.0);
    mx_hsvtorgb_color3(N_tmp3_color3_out, N_torgb_color3_out);
    out1 = N_torgb_color3_out;
}

void mx_luminance_color3(vec3 _in, vec3 lumacoeffs, out vec3 result)
{
    result = vec3(dot(_in, lumacoeffs));
}

void NG_saturate_color3(vec3 in1, float amount, vec3 lumacoeffs, out vec3 out1)
{
    vec3 N_gray_color3_out = vec3(0.0);
    mx_luminance_color3(in1, lumacoeffs, N_gray_color3_out);
    vec3 N_mix_color3_out = mix(N_gray_color3_out, in1, amount);
    out1 = N_mix_color3_out;
}

void NG_range_color3FA(vec3 in1, float inlow, float inhigh, float gamma, float outlow, float outhigh, bool doclamp, out vec3 out1)
{
    const float N_remap1_color3FA_outlow_tmp = 0.000000;
    const float N_remap1_color3FA_outhigh_tmp = 1.000000;
    vec3 N_remap1_color3FA_out = N_remap1_color3FA_outlow_tmp + (in1 - inlow) * (N_remap1_color3FA_outhigh_tmp - N_remap1_color3FA_outlow_tmp) / (inhigh - inlow);
    const float N_recip_color3FA_in1_tmp = 1.000000;
    float N_recip_color3FA_out = N_recip_color3FA_in1_tmp / gamma;
    vec3 N_abs_color3FA_out = abs(N_remap1_color3FA_out);
    vec3 N_sign_color3FA_out = sign(N_remap1_color3FA_out);
    vec3 N_pow_color3FA_out = pow(N_abs_color3FA_out, vec3(N_recip_color3FA_out));
    vec3 N_gamma_color3FA_out = N_pow_color3FA_out * N_sign_color3FA_out;
    const float N_remap2_color3FA_inlow_tmp = 0.000000;
    const float N_remap2_color3FA_inhigh_tmp = 1.000000;
    vec3 N_remap2_color3FA_out = outlow + (N_gamma_color3FA_out - N_remap2_color3FA_inlow_tmp) * (outhigh - outlow) / (N_remap2_color3FA_inhigh_tmp - N_remap2_color3FA_inlow_tmp);
    vec3 N_clamp_color3FA_out = clamp(N_remap2_color3FA_out, outlow, outhigh);
    const bool N_switch_color3FA_value2_tmp = true;
    vec3 N_switch_color3FA_out = (doclamp == N_switch_color3FA_value2_tmp) ? N_clamp_color3FA_out : N_remap2_color3FA_out;
    out1 = N_switch_color3FA_out;
}

void NG_contrast_color3FA(vec3 in1, float amount, float pivot, out vec3 out1)
{
    vec3 N_sub_color3FA_out = in1 - pivot;
    vec3 N_mul_color3FA_out = N_sub_color3FA_out * amount;
    vec3 N_add_color3FA_out = N_mul_color3FA_out + pivot;
    out1 = N_add_color3FA_out;
}

void NG_colorcorrect_color3(vec3 in1, float hue, float saturation, float gamma, float lift, float gain, float contrast, float contrastpivot, float exposure, out vec3 out1)
{
    const float N_parm2hue_in2_tmp = 1.000000;
    const float N_parm2hue_in3_tmp = 1.000000;
    vec3 N_parm2hue_out = vec3(hue,N_parm2hue_in2_tmp,N_parm2hue_in3_tmp);
    const float N_liftsubtract_in1_tmp = 1.000000;
    float N_liftsubtract_out = N_liftsubtract_in1_tmp - lift;
    const float N_exposurepwr_in1_tmp = 2.000000;
    float N_exposurepwr_out = pow(N_exposurepwr_in1_tmp, exposure);
    vec3 N_hsvadjust_out = vec3(0.0);
    NG_hsvadjust_color3(in1, N_parm2hue_out, N_hsvadjust_out);
    vec3 N_saturation_out = vec3(0.0);
    NG_saturate_color3(N_hsvadjust_out, saturation, vec3(0.272229, 0.674082, 0.053689), N_saturation_out);
    vec3 N_gamma_out = vec3(0.0);
    NG_range_color3FA(N_saturation_out, 0.000000, 1.000000, gamma, 0.000000, 1.000000, false, N_gamma_out);
    vec3 N_liftmult_out = N_gamma_out * N_liftsubtract_out;
    vec3 N_liftadd_out = N_liftmult_out + lift;
    vec3 N_gain_out = N_liftadd_out * gain;
    vec3 N_contrast_out = vec3(0.0);
    NG_contrast_color3FA(N_gain_out, contrast, contrastpivot, N_contrast_out);
    vec3 N_exposure_out = N_contrast_out * N_exposurepwr_out;
    out1 = N_exposure_out;
}

void NG_separate3_color3(vec3 in1, out float outr, out float outg, out float outb)
{
    const int N_extract_0_index_tmp = 0;
    float N_extract_0_out = in1[N_extract_0_index_tmp];
    const int N_extract_1_index_tmp = 1;
    float N_extract_1_out = in1[N_extract_1_index_tmp];
    const int N_extract_2_index_tmp = 2;
    float N_extract_2_out = in1[N_extract_2_index_tmp];
    outr = N_extract_0_out;
    outg = N_extract_1_out;
    outb = N_extract_2_out;
}

void NG_legacy_tiles_color3(vec2 texcoord, vec3 tile_color, vec3 grout_color, float tiles_num_x, float tiles_num_y, float grout_gap_x, float grout_gap_y, float grout_bias, float line_shift, float random_shift, float color_variance, float fade_variance, float seed, bool brightness_variance, bool alpha_fade, float roughness_scale, float roughness_amount, bool rows_mod_enable, float num_rows, float rows_mod_amount, vec2 realworld_scale, vec2 realworld_offset, float rotation_angle, bool tile_x, bool tile_y, out vec3 output_color3, out float output_alpha, out vec4 output_color4)
{
    const float invert_rotation_amount_tmp = 0.000000;
    float invert_rotation_out = invert_rotation_amount_tmp - rotation_angle;
    vec2 texcoord_scale_out = texcoord / realworld_scale;
    float separate_size_outx = 0.0;
    float separate_size_outy = 0.0;
    NG_separate2_vector2(realworld_scale, separate_size_outx, separate_size_outy);
    float separate_offset_outx = 0.0;
    float separate_offset_outy = 0.0;
    NG_separate2_vector2(realworld_offset, separate_offset_outx, separate_offset_outy);
    vec2 combine_tiles_out = vec2(tiles_num_x,tiles_num_y);
    const float roughness_amount_approx_in2_tmp = 2000.000000;
    float roughness_amount_approx_out = roughness_amount / roughness_amount_approx_in2_tmp;
    float nrows_int_out = floor(num_rows);
    const float gap_x_half_in2_tmp = 2.000000;
    float gap_x_half_out = grout_gap_x / gap_x_half_in2_tmp;
    const float remap_bias_outlow_tmp = 0.000000;
    const float remap_bias_inlow_tmp = -1.000000;
    const float remap_bias_outhigh_tmp = 1.000000;
    const float remap_bias_inhigh_tmp = 1.000000;
    float remap_bias_out = remap_bias_outlow_tmp + (grout_bias - remap_bias_inlow_tmp) * (remap_bias_outhigh_tmp - remap_bias_outlow_tmp) / (remap_bias_inhigh_tmp - remap_bias_inlow_tmp);
    const float gap_y_half_in2_tmp = 2.000000;
    float gap_y_half_out = grout_gap_y / gap_y_half_in2_tmp;
    float adj_offx_out = separate_offset_outx / separate_size_outx;
    float adj_offxy_out = separate_offset_outy / separate_size_outy;
    const float nrow_prev_in2_tmp = 1.000000;
    float nrow_prev_out = nrows_int_out - nrow_prev_in2_tmp;
    const float gap_x_approx_in2_tmp = 0.050000;
    float gap_x_approx_out = gap_x_half_out * gap_x_approx_in2_tmp;
    const float invert3_amount_tmp = 1.000000;
    float invert3_out = invert3_amount_tmp - remap_bias_out;
    const float gap_y_approx_in2_tmp = 0.050000;
    float gap_y_approx_out = gap_y_half_out * gap_y_approx_in2_tmp;
    vec2 combine_offset_out = vec2(adj_offx_out,adj_offxy_out);
    float grout_y_adj_out = gap_y_approx_out * tiles_num_y;
    vec2 sub_offset_out = texcoord_scale_out - combine_offset_out;
    float grout_y_bias2_out = remap_bias_out * grout_y_adj_out;
    float grout_y_bias1_out = invert3_out * grout_y_adj_out;
    vec2 rotate_texcoord_out = vec2(0.0);
    mx_rotate_vector2(sub_offset_out, invert_rotation_out, rotate_texcoord_out);
    float separate2_2_outx = 0.0;
    float separate2_2_outy = 0.0;
    NG_separate2_vector2(rotate_texcoord_out, separate2_2_outx, separate2_2_outy);
    vec2 roughness_scale_mult_out = rotate_texcoord_out * roughness_scale;
    const float ifgreater_x_1_value2_tmp = 1.000000;
    const float ifgreater_x_1_in1_tmp = 0.000000;
    const float ifgreater_x_1_in2_tmp = 1.000000;
    float ifgreater_x_1_out = (separate2_2_outx > ifgreater_x_1_value2_tmp) ? ifgreater_x_1_in1_tmp : ifgreater_x_1_in2_tmp;
    const float ifgreater_y_1_value2_tmp = 1.000000;
    const float ifgreater_y_1_in1_tmp = 0.000000;
    const float ifgreater_y_1_in2_tmp = 1.000000;
    float ifgreater_y_1_out = (separate2_2_outy > ifgreater_y_1_value2_tmp) ? ifgreater_y_1_in1_tmp : ifgreater_y_1_in2_tmp;
    vec2 roughness_const_size_out = roughness_scale_mult_out * combine_tiles_out;
    const float ifgreater_x_0_value2_tmp = 0.000000;
    const float ifgreater_x_0_in2_tmp = 0.000000;
    float ifgreater_x_0_out = (separate2_2_outx > ifgreater_x_0_value2_tmp) ? ifgreater_x_1_out : ifgreater_x_0_in2_tmp;
    const float ifgreater_y_0_value2_tmp = 0.000000;
    const float ifgreater_y_0_in2_tmp = 0.000000;
    float ifgreater_y_0_out = (separate2_2_outy > ifgreater_y_0_value2_tmp) ? ifgreater_y_1_out : ifgreater_y_0_in2_tmp;
    vec2 noise_roughness_out = vec2(0.0);
    mx_noise2d_vector2(vec2(1.000000, 1.000000), 0.000000, roughness_const_size_out, noise_roughness_out);
    const bool check_trim_x_value2_tmp = false;
    const float check_trim_x_in2_tmp = 1.000000;
    float check_trim_x_out = (tile_x == check_trim_x_value2_tmp) ? ifgreater_x_0_out : check_trim_x_in2_tmp;
    const bool check_trim_y_value2_tmp = false;
    const float check_trim_y_in2_tmp = 1.000000;
    float check_trim_y_out = (tile_y == check_trim_y_value2_tmp) ? ifgreater_y_0_out : check_trim_y_in2_tmp;
    vec2 roughness_amount1_out = noise_roughness_out * roughness_amount_approx_out;
    float combine_tiling_alpha_out = check_trim_x_out * check_trim_y_out;
    vec2 add_roughness_out = rotate_texcoord_out + roughness_amount1_out;
    float separate_texcoord_outx = 0.0;
    float separate_texcoord_outy = 0.0;
    NG_separate2_vector2(add_roughness_out, separate_texcoord_outx, separate_texcoord_outy);
    float multiply_tilesx_out = separate_texcoord_outx * tiles_num_x;
    float multiply_tilesy_out = separate_texcoord_outy * tiles_num_y;
    float add_altrow_shift_out = multiply_tilesx_out + line_shift;
    float rownum_out = floor(multiply_tilesy_out);
    const float modulo_altrow_in2_tmp = 2.000000;
    float modulo_altrow_out = mx_mod(multiply_tilesy_out, modulo_altrow_in2_tmp);
    float current_row_check_out = mx_mod(multiply_tilesy_out, nrows_int_out);
    float tile_y1_out = floor(multiply_tilesy_out);
    const float tiley_in2_tmp = 1.000000;
    float tiley_out = mx_mod(multiply_tilesy_out, tiley_in2_tmp);
    const float default_altrow_shift_in2_tmp = 0.500000;
    float default_altrow_shift_out = add_altrow_shift_out + default_altrow_shift_in2_tmp;
    const float arbitrary_noise_scale1_in2_tmp = 12.345000;
    float arbitrary_noise_scale1_out = rownum_out * arbitrary_noise_scale1_in2_tmp;
    float nrow_range_out = current_row_check_out - nrow_prev_out;
    const float invert2_amount_tmp = 1.000000;
    float invert2_out = invert2_amount_tmp - tiley_out;
    const float grout_y_range_check1_in1_tmp = 0.000000;
    const float grout_y_range_check1_in2_tmp = 1.000000;
    float grout_y_range_check1_out = (tiley_out > grout_y_bias2_out) ? grout_y_range_check1_in1_tmp : grout_y_range_check1_in2_tmp;
    const float altrow_select_value2_tmp = 1.000000;
    float altrow_select_out = (modulo_altrow_out > altrow_select_value2_tmp) ? default_altrow_shift_out : multiply_tilesx_out;
    float seed_simulation1_out = arbitrary_noise_scale1_out + seed;
    const float nrow_check2_value2_tmp = 0.000000;
    const float nrow_check2_in2_tmp = 1.000000;
    float nrow_check2_out = (nrow_range_out > nrow_check2_value2_tmp) ? rows_mod_amount : nrow_check2_in2_tmp;
    const float grout_y_range_check2_in2_tmp = 1.000000;
    float grout_y_range_check2_out = (invert2_out > grout_y_bias1_out) ? grout_y_range_check1_out : grout_y_range_check2_in2_tmp;
    const float tex_x_only_in2_tmp = 0.000000;
    vec2 tex_x_only_out = vec2(seed_simulation1_out,tex_x_only_in2_tmp);
    const bool nrowmod_enable2_value2_tmp = true;
    const float nrowmod_enable2_in2_tmp = 1.000000;
    float nrowmod_enable2_out = (rows_mod_enable == nrowmod_enable2_value2_tmp) ? nrow_check2_out : nrowmod_enable2_in2_tmp;
    float random_shift1_out = 0.0;
    mx_noise2d_float(1.000000, 0.000000, tex_x_only_out, random_shift1_out);
    float adj_nrow_bias_out = tiles_num_x / nrowmod_enable2_out;
    float random_shift_amount_out = random_shift1_out * random_shift;
    float grout_x_adj_out = gap_x_approx_out * adj_nrow_bias_out;
    float add_random_shift_out = random_shift_amount_out + altrow_select_out;
    float grout_x_bias1_out = remap_bias_out * grout_x_adj_out;
    float grout_x_bias2_out = invert3_out * grout_x_adj_out;
    float shift_adj_out = add_random_shift_out / rows_mod_amount;
    const float nrow_check1_value2_tmp = 0.000000;
    float nrow_check1_out = (nrow_range_out > nrow_check1_value2_tmp) ? shift_adj_out : add_random_shift_out;
    const bool nrowmod_enable1_value2_tmp = true;
    float nrowmod_enable1_out = (rows_mod_enable == nrowmod_enable1_value2_tmp) ? nrow_check1_out : add_random_shift_out;
    float tile_x1_out = floor(nrowmod_enable1_out);
    const float tilex_in2_tmp = 1.000000;
    float tilex_out = mx_mod(nrowmod_enable1_out, tilex_in2_tmp);
    vec2 combine_tilexy1_out = vec2(tile_x1_out,tile_y1_out);
    const float invert1_amount_tmp = 1.000000;
    float invert1_out = invert1_amount_tmp - tilex_out;
    const float grout_x_range_check1_in1_tmp = 0.000000;
    const float grout_x_range_check1_in2_tmp = 1.000000;
    float grout_x_range_check1_out = (tilex_out > grout_x_bias1_out) ? grout_x_range_check1_in1_tmp : grout_x_range_check1_in2_tmp;
    const float arbitrary_noise_scale2_in2_tmp = 34.567799;
    vec2 arbitrary_noise_scale2_out = combine_tilexy1_out * arbitrary_noise_scale2_in2_tmp;
    const float grout_x_range_check2_in2_tmp = 1.000000;
    float grout_x_range_check2_out = (invert1_out > grout_x_bias2_out) ? grout_x_range_check1_out : grout_x_range_check2_in2_tmp;
    const float arbitrary_noise_shift_in2_tmp = 12.345600;
    vec2 arbitrary_noise_shift_out = arbitrary_noise_scale2_out + arbitrary_noise_shift_in2_tmp;
    vec2 seed_simulation2_out = arbitrary_noise_scale2_out + seed;
    float combine_grout_out = max(grout_x_range_check2_out, grout_y_range_check2_out);
    vec2 seed_simulation3_out = arbitrary_noise_shift_out + seed;
    float color_var1_out = 0.0;
    mx_noise2d_float(0.500000, 0.000000, seed_simulation2_out, color_var1_out);
    float fade_var_out = 0.0;
    mx_noise2d_float(0.500000, 0.500000, seed_simulation3_out, fade_var_out);
    float color_var_amount_out = color_var1_out * color_variance;
    const float noise_range_adj_in2_tmp = 2.000000;
    float noise_range_adj_out = color_var1_out * noise_range_adj_in2_tmp;
    float fade_var_amount_out = fade_var_out * fade_variance;
    vec3 colorcorrect1_out = vec3(0.0);
    NG_colorcorrect_color3(tile_color, color_var_amount_out, 1.000000, 1.000000, 0.000000, 1.000000, 1.000000, 0.500000, 0.000000, colorcorrect1_out);
    float fade_var_amount2_out = noise_range_adj_out * fade_variance;
    float color_var_amount2_out = noise_range_adj_out * color_variance;
    const float invert4_amount_tmp = 1.000000;
    float invert4_out = invert4_amount_tmp - fade_var_amount_out;
    const float var_positive2_in2_tmp = 1.000000;
    float var_positive2_out = fade_var_amount2_out + var_positive2_in2_tmp;
    const float var_positive1_in2_tmp = 1.000000;
    float var_positive1_out = color_var_amount2_out + var_positive1_in2_tmp;
    vec3 color_and_fade_var_out = colorcorrect1_out * invert4_out;
    float fade_alpha1_out = invert4_out * combine_tiling_alpha_out;
    const float clamp_alpha_low_tmp = 0.000000;
    const float clamp_alpha_high_tmp = 1.000000;
    float clamp_alpha_out = clamp(var_positive2_out, clamp_alpha_low_tmp, clamp_alpha_high_tmp);
    const bool fade_alpha1_enable_value2_tmp = true;
    float fade_alpha1_enable_out = (alpha_fade == fade_alpha1_enable_value2_tmp) ? fade_alpha1_out : combine_tiling_alpha_out;
    float col_alpha_adj_out = var_positive1_out * clamp_alpha_out;
    float fade_alpha2_out = combine_tiling_alpha_out * clamp_alpha_out;
    vec3 color_var2_out = tile_color * col_alpha_adj_out;
    const bool fade_alpha2_enable_value2_tmp = true;
    float fade_alpha2_enable_out = (alpha_fade == fade_alpha2_enable_value2_tmp) ? fade_alpha2_out : combine_tiling_alpha_out;
    const vec3 clamp_color_low_tmp = vec3(0.000000, 0.000000, 0.000000);
    const vec3 clamp_color_high_tmp = vec3(1.000000, 1.000000, 1.000000);
    vec3 clamp_color_out = clamp(color_var2_out, clamp_color_low_tmp, clamp_color_high_tmp);
    const bool alpha_variance_behavior_select_value2_tmp = true;
    float alpha_variance_behavior_select_out = (brightness_variance == alpha_variance_behavior_select_value2_tmp) ? fade_alpha2_enable_out : fade_alpha1_enable_out;
    const bool color_variance_behavior_select_value2_tmp = true;
    vec3 color_variance_behavior_select_out = (brightness_variance == color_variance_behavior_select_value2_tmp) ? clamp_color_out : color_and_fade_var_out;
    float max_grout_out = max(alpha_variance_behavior_select_out, combine_grout_out);
    vec3 mix_grout_tiles_out = mix(color_variance_behavior_select_out, grout_color, combine_grout_out);
    float min_tiling_alpha_out = min(max_grout_out, combine_tiling_alpha_out);
    vec3 tiling_black_out = mix_grout_tiles_out * combine_tiling_alpha_out;
    float separate_color_outr = 0.0;
    float separate_color_outg = 0.0;
    float separate_color_outb = 0.0;
    NG_separate3_color3(tiling_black_out, separate_color_outr, separate_color_outg, separate_color_outb);
    vec4 combine_color_alpha_out = vec4(separate_color_outr,separate_color_outg,separate_color_outb,min_tiling_alpha_out);
    output_color3 = tiling_black_out;
    output_alpha = min_tiling_alpha_out;
    output_color4 = combine_color_alpha_out;
}

void NG_convert_float_color3(float in1, out vec3 out1)
{
    vec3 combine_out = vec3(in1,in1,in1);
    out1 = combine_out;
}

void mx_roughness_anisotropy(float roughness, float anisotropy, out vec2 result)
{
    float roughness_sqr = clamp(roughness*roughness, M_FLOAT_EPS, 1.0);
    if (anisotropy > 0.0)
    {
        float aspect = sqrt(1.0 - clamp(anisotropy, 0.0, 0.98));
        result.x = min(roughness_sqr / aspect, 1.0);
        result.y = roughness_sqr * aspect;
    }
    else
    {
        result.x = roughness_sqr;
        result.y = roughness_sqr;
    }
}

// These are defined based on the HwShaderGenerator::ClosureContextType enum
// if that changes - these need to be updated accordingly.

#define CLOSURE_TYPE_DEFAULT 0
#define CLOSURE_TYPE_REFLECTION 1
#define CLOSURE_TYPE_TRANSMISSION 2
#define CLOSURE_TYPE_INDIRECT 3
#define CLOSURE_TYPE_EMISSION 4

struct ClosureData {
    int closureType;
    vec3 L;
    vec3 V;
    vec3 N;
    vec3 P;
    float occlusion;
};

ClosureData makeClosureData(int closureType, vec3 L, vec3 V, vec3 N, vec3 P, float occlusion)
{
    return ClosureData(closureType, L, V, N, P, occlusion);
}

// https://fpsunflower.github.io/ckulla/data/s2017_pbs_imageworks_sheen.pdf
// Equation 2
float mx_imageworks_sheen_NDF(float NdotH, float roughness)
{
    float invRoughness = 1.0 / max(roughness, 0.005);
    float cos2 = NdotH * NdotH;
    float sin2 = 1.0 - cos2;
    return (2.0 + invRoughness) * pow(sin2, invRoughness * 0.5) / (2.0 * M_PI);
}

float mx_imageworks_sheen_brdf(float NdotL, float NdotV, float NdotH, float roughness)
{
    // Microfacet distribution.
    float D = mx_imageworks_sheen_NDF(NdotH, roughness);

    // Fresnel and geometry terms are ignored.
    float F = 1.0;
    float G = 1.0;

    // We use a smoother denominator, as in:
    // https://blog.selfshadow.com/publications/s2013-shading-course/rad/s2013_pbs_rad_notes.pdf
    return D * F * G / (4.0 * (NdotL + NdotV - NdotL*NdotV));
}

// Rational quadratic fit to Monte Carlo data for Imageworks sheen directional albedo.
float mx_imageworks_sheen_dir_albedo_analytic(float NdotV, float roughness)
{
    vec2 r = vec2(13.67300, 1.0) +
             vec2(-68.78018, 61.57746) * NdotV +
             vec2(799.08825, 442.78211) * roughness +
             vec2(-905.00061, 2597.49308) * NdotV * roughness +
             vec2(60.28956, 121.81241) * mx_square(NdotV) +
             vec2(1086.96473, 3045.55075) * mx_square(roughness);
    return r.x / r.y;
}

float mx_imageworks_sheen_dir_albedo_table_lookup(float NdotV, float roughness)
{
#if DIRECTIONAL_ALBEDO_METHOD == 1
    if (textureSize(u_albedoTable, 0).x > 1)
    {
        return texture(u_albedoTable, vec2(NdotV, roughness)).b;
    }
#endif
    return 0.0;
}

float mx_imageworks_sheen_dir_albedo_monte_carlo(float NdotV, float roughness)
{
    NdotV = clamp(NdotV, M_FLOAT_EPS, 1.0);
    vec3 V = vec3(sqrt(1.0f - mx_square(NdotV)), 0, NdotV);

    float radiance = 0.0;
    const int SAMPLE_COUNT = 64;
    for (int i = 0; i < SAMPLE_COUNT; i++)
    {
        vec2 Xi = mx_spherical_fibonacci(i, SAMPLE_COUNT);

        // Compute the incoming light direction and half vector.
        vec3 L = mx_uniform_sample_hemisphere(Xi);
        vec3 H = normalize(L + V);
        
        // Compute dot products for this sample.
        float NdotL = clamp(L.z, M_FLOAT_EPS, 1.0);
        float NdotH = clamp(H.z, M_FLOAT_EPS, 1.0);

        // Compute sheen reflectance.
        float reflectance = mx_imageworks_sheen_brdf(NdotL, NdotV, NdotH, roughness);

        // Add the radiance contribution of this sample.
        //   radiance = reflectance * NdotL / uniform_pdf;
        radiance += reflectance * NdotL / mx_uniform_hemisphere_PDF();
    }

    // Return the final directional albedo.
    return radiance / float(SAMPLE_COUNT);
}

float mx_imageworks_sheen_dir_albedo(float NdotV, float roughness)
{
#if DIRECTIONAL_ALBEDO_METHOD == 0
    float dirAlbedo = mx_imageworks_sheen_dir_albedo_analytic(NdotV, roughness);
#elif DIRECTIONAL_ALBEDO_METHOD == 1
    float dirAlbedo = mx_imageworks_sheen_dir_albedo_table_lookup(NdotV, roughness);
#else
    float dirAlbedo = mx_imageworks_sheen_dir_albedo_monte_carlo(NdotV, roughness);
#endif
    return clamp(dirAlbedo, 0.0, 1.0);
}

// The following functions are adapted from https://github.com/tizian/ltc-sheen.
// "Practical Multiple-Scattering Sheen Using Linearly Transformed Cosines", Zeltner et al.

// Gaussian fit to directional albedo table.
float mx_zeltner_sheen_dir_albedo(float x, float y)
{
    float s = y*(0.0206607 + 1.58491*y)/(0.0379424 + y*(1.32227 + y));
    float m = y*(-0.193854 + y*(-1.14885 + y*(1.7932 - 0.95943*y*y)))/(0.046391 + y);
    float o = y*(0.000654023 + (-0.0207818 + 0.119681*y)*y)/(1.26264 + y*(-1.92021 + y));
    return exp(-0.5*mx_square((x - m)/s))/(s*sqrt(2.0*M_PI)) + o;
}

// Rational fits to LTC matrix coefficients.
float mx_zeltner_sheen_ltc_aInv(float x, float y)
{
    return (2.58126*x + 0.813703*y)*y/(1.0 + 0.310327*x*x + 2.60994*x*y);
}

float mx_zeltner_sheen_ltc_bInv(float x, float y)
{
    return sqrt(1.0 - x)*(y - 1.0)*y*y*y/(0.0000254053 + 1.71228*x - 1.71506*x*y + 1.34174*y*y);
}

// V and N are assumed to be unit vectors.
mat3 mx_orthonormal_basis_ltc(vec3 V, vec3 N, float NdotV)
{
    // Generate a tangent vector in the plane of V and N.
    // This required to correctly orient the LTC lobe.
    vec3 X = V - N*NdotV;
    float lenSqr = dot(X, X);
    if (lenSqr > 0.0)
    {
        X *= mx_inversesqrt(lenSqr);
        vec3 Y = cross(N, X);
        return mat3(X, Y, N);
    }

    // If lenSqr == 0, then V == N, so any orthonormal basis will do.
    return mx_orthonormal_basis(N);
}

// Multiplication by directional albedo is handled by the calling function.
float mx_zeltner_sheen_brdf(vec3 L, vec3 V, vec3 N, float NdotV, float roughness)
{
    mat3 toLTC = transpose(mx_orthonormal_basis_ltc(V, N, NdotV));
    vec3 w = mx_matrix_mul(toLTC, L);

    float aInv = mx_zeltner_sheen_ltc_aInv(NdotV, roughness);
    float bInv = mx_zeltner_sheen_ltc_bInv(NdotV, roughness);

    // Transform w to original configuration (clamped cosine).
    //                 |aInv    0 bInv|
    // wo = M^-1 . w = |   0 aInv    0| . w
    //                 |   0    0    1|
    vec3 wo = vec3(aInv*w.x + bInv*w.z, aInv * w.y, w.z);
    float lenSqr = dot(wo, wo);

    // D(w) = Do(M^-1.w / ||M^-1.w||) . |M^-1| / ||M^-1.w||^3
    //      = Do(M^-1.w) . |M^-1| / ||M^-1.w||^4
    //      = Do(wo) . |M^-1| / dot(wo, wo)^2
    //      = Do(wo) . aInv^2 / dot(wo, wo)^2
    //      = Do(wo) . (aInv / dot(wo, wo))^2
    return mx_cosine_hemisphere_PDF(wo.z) * mx_square(aInv / lenSqr);
}

vec3 mx_zeltner_sheen_importance_sample(vec2 Xi, vec3 V, vec3 N, float roughness, out float pdf)
{
    float NdotV = clamp(dot(N, V), 0.0, 1.0);
    roughness = clamp(roughness, 0.01, 1.0); // Clamp to range of original impl.

    vec3 wo = mx_cosine_sample_hemisphere(Xi);

    float aInv = mx_zeltner_sheen_ltc_aInv(NdotV, roughness);
    float bInv = mx_zeltner_sheen_ltc_bInv(NdotV, roughness);

    // Transform wo from original configuration (clamped cosine).
    //              |1/aInv      0 -bInv/aInv|
    // w = M . wo = |     0 1/aInv          0| . wo
    //              |     0      0          1|    
    vec3 w = vec3(wo.x/aInv - wo.z*bInv/aInv, wo.y / aInv, wo.z);

    float lenSqr = dot(w, w);
    w *= mx_inversesqrt(lenSqr);

    // D(w) = Do(wo) . ||M.wo||^3 / |M|
    //      = Do(wo / ||M.wo||) . ||M.wo||^4 / |M| 
    //      = Do(w) . ||M.wo||^4 / |M| (possible because M doesn't change z component)
    //      = Do(w) . dot(w, w)^2 * aInv^2
    //      = Do(w) . (aInv * dot(w, w))^2
    pdf = mx_cosine_hemisphere_PDF(w.z) * mx_square(aInv * lenSqr);

    mat3 fromLTC = mx_orthonormal_basis_ltc(V, N, NdotV);
    w = mx_matrix_mul(fromLTC, w);

    return w;
}

void mx_sheen_bsdf(ClosureData closureData, float weight, vec3 color, float roughness, vec3 N, int mode, inout BSDF bsdf)
{
    if (weight < M_FLOAT_EPS)
    {
        return;
    }

    vec3 V = closureData.V;
    vec3 L = closureData.L;

    N = mx_forward_facing_normal(N, V);
    float NdotV = clamp(dot(N, V), M_FLOAT_EPS, 1.0);

    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        float dirAlbedo;
        if (mode == 0)
        {
            vec3 H = normalize(L + V);

            float NdotL = clamp(dot(N, L), M_FLOAT_EPS, 1.0);
            float NdotH = clamp(dot(N, H), M_FLOAT_EPS, 1.0);

            vec3 fr = color * mx_imageworks_sheen_brdf(NdotL, NdotV, NdotH, roughness);
            dirAlbedo = mx_imageworks_sheen_dir_albedo(NdotV, roughness);

            // We need to include NdotL from the light integral here
            // as in this case it's not cancelled out by the BRDF denominator.
            bsdf.response = fr * NdotL * closureData.occlusion * weight;
        }
        else
        {
            roughness = clamp(roughness, 0.01, 1.0); // Clamp to range of original impl.

            vec3 fr = color * mx_zeltner_sheen_brdf(L, V, N, NdotV, roughness);
            dirAlbedo = mx_zeltner_sheen_dir_albedo(NdotV, roughness);
            bsdf.response = dirAlbedo * fr * closureData.occlusion * weight;
        }
        bsdf.throughput = vec3(1.0 - dirAlbedo * weight);
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        float dirAlbedo;
        if (mode == 0)
        {
            dirAlbedo = mx_imageworks_sheen_dir_albedo(NdotV, roughness);
        }
        else
        {
            roughness = clamp(roughness, 0.01, 1.0); // Clamp to range of original impl.
            dirAlbedo = mx_zeltner_sheen_dir_albedo(NdotV, roughness);
        }

        vec3 Li = mx_environment_irradiance(N);
        bsdf.response = Li * color * dirAlbedo * weight;
        bsdf.throughput = vec3(1.0 - dirAlbedo * weight);
    }
}

void mx_rotate_vector3(vec3 _in, float amount, vec3 axis, out vec3 result)
{
    // Based on https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula, where the
    // Wikipedia formula follows v' = M * v and MaterialX follows v' = v * M, thus the
    // order of parameters to cross are reversed.

    axis = normalize(axis);
    float rotationRadians = mx_radians(amount);
    float s = mx_sin(rotationRadians);
    float c = mx_cos(rotationRadians);
    float oc = 1.0 - c;
    result = _in * c + cross(_in, axis) * s + axis * dot(axis, _in) * oc;
}

void mx_artistic_ior(vec3 reflectivity, vec3 edge_color, out vec3 ior, out vec3 extinction)
{
    // "Artist Friendly Metallic Fresnel", Ole Gulbrandsen, 2014
    // http://jcgt.org/published/0003/04/03/paper.pdf

    vec3 r = clamp(reflectivity, 0.0, 0.99);
    vec3 r_sqrt = sqrt(r);
    vec3 n_min = (1.0 - r) / (1.0 + r);
    vec3 n_max = (1.0 + r_sqrt) / (1.0 - r_sqrt);
    ior = mix(n_max, n_min, edge_color);

    vec3 np1 = ior + 1.0;
    vec3 nm1 = ior - 1.0;
    vec3 k2 = (np1*np1 * r - nm1*nm1) / (1.0 - r);
    k2 = max(k2, 0.0);
    extinction = sqrt(k2);
}


void mx_uniform_edf(ClosureData closureData, vec3 color, out EDF result)
{
    if (closureData.closureType == CLOSURE_TYPE_EMISSION)
    {
        result = color;
    }
}


void mx_multiply_edf_color3(ClosureData closureData, EDF in1, vec3 in2, out EDF result)
{
    result = in1 * in2;
}


void mx_dielectric_bsdf(ClosureData closureData, float weight, vec3 tint, float ior, vec2 roughness, bool retroreflective, float thinfilm_thickness, float thinfilm_ior, vec3 N, vec3 X, int distribution, int scatter_mode, inout BSDF bsdf)
{
    if (weight < M_FLOAT_EPS)
    {
        return;
    }
    if (closureData.closureType != CLOSURE_TYPE_TRANSMISSION && scatter_mode == 1)
    {
        return;
    }

    vec3 V = closureData.V;
    vec3 L = closureData.L;

    // Retroreflective mode is only supported for reflection and indirect
    if (retroreflective && (closureData.closureType != CLOSURE_TYPE_TRANSMISSION))
        V = reflect(-V, N);
    
    N = mx_forward_facing_normal(N, V);
    float NdotV = clamp(dot(N, V), M_FLOAT_EPS, 1.0);

    FresnelData fd = mx_init_fresnel_dielectric(ior, thinfilm_thickness, thinfilm_ior);
    float F0 = mx_ior_to_f0(ior);

    vec2 safeAlpha = clamp(roughness, M_FLOAT_EPS, 1.0);
    float avgAlpha = mx_average_alpha(safeAlpha);
    vec3 safeTint = max(tint, 0.0);

    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        X = normalize(X - dot(X, N) * N);
        vec3 Y = cross(N, X);
        vec3 H = normalize(L + V);

        float NdotL = clamp(dot(N, L), M_FLOAT_EPS, 1.0);
        float VdotH = clamp(dot(V, H), M_FLOAT_EPS, 1.0);

        vec3 Ht = vec3(dot(H, X), dot(H, Y), dot(H, N));

        vec3 F = mx_compute_fresnel(VdotH, fd);
        float D = mx_ggx_NDF(Ht, safeAlpha);
        float G = mx_ggx_smith_G2(NdotL, NdotV, avgAlpha);

        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
        vec3 dirAlbedo = mx_ggx_dir_albedo(NdotV, avgAlpha, F0, 1.0) * comp;
        bsdf.throughput = 1.0 - dirAlbedo * weight;

        bsdf.response = D * F * G * comp * safeTint * closureData.occlusion * weight / (4.0 * NdotV);
    }
    else if (closureData.closureType == CLOSURE_TYPE_TRANSMISSION)
    {
        vec3 F = mx_compute_fresnel(NdotV, fd);

        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
        vec3 dirAlbedo = mx_ggx_dir_albedo(NdotV, avgAlpha, F0, 1.0) * comp;
        bsdf.throughput = 1.0 - dirAlbedo * weight;

        if (scatter_mode != 0)
        {
            bsdf.response = mx_surface_transmission(N, V, X, safeAlpha, distribution, fd, safeTint) * weight;
        }
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        vec3 F = mx_compute_fresnel(NdotV, fd);

        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
        vec3 dirAlbedo = mx_ggx_dir_albedo(NdotV, avgAlpha, F0, 1.0) * comp;
        bsdf.throughput = 1.0 - dirAlbedo * weight;

        vec3 Li = mx_environment_radiance(N, V, X, safeAlpha, distribution, fd);
        bsdf.response = Li * safeTint * comp * weight;
    }
}


void mx_conductor_bsdf(ClosureData closureData, float weight, vec3 ior_n, vec3 ior_k, vec2 roughness, bool retroreflective, float thinfilm_thickness, float thinfilm_ior, vec3 N, vec3 X, int distribution, inout BSDF bsdf)
{
    bsdf.throughput = vec3(0.0);

    if (weight < M_FLOAT_EPS)
    {
        return;
    }

    vec3 V = closureData.V;
    vec3 L = closureData.L;

    V = retroreflective ? reflect(-V, N) : V;
    N = mx_forward_facing_normal(N, V);
    float NdotV = clamp(dot(N, V), M_FLOAT_EPS, 1.0);

    FresnelData fd = mx_init_fresnel_conductor(ior_n, ior_k, thinfilm_thickness, thinfilm_ior);

    vec2 safeAlpha = clamp(roughness, M_FLOAT_EPS, 1.0);
    float avgAlpha = mx_average_alpha(safeAlpha);

    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        X = normalize(X - dot(X, N) * N);
        vec3 Y = cross(N, X);
        vec3 H = normalize(L + V);

        float NdotL = clamp(dot(N, L), M_FLOAT_EPS, 1.0);
        float VdotH = clamp(dot(V, H), M_FLOAT_EPS, 1.0);

        vec3 Ht = vec3(dot(H, X), dot(H, Y), dot(H, N));

        vec3 F = mx_compute_fresnel(VdotH, fd);
        float D = mx_ggx_NDF(Ht, safeAlpha);
        float G = mx_ggx_smith_G2(NdotL, NdotV, avgAlpha);

        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);

        // Note: NdotL is cancelled out
        bsdf.response = D * F * G * comp * closureData.occlusion * weight / (4.0 * NdotV);
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        vec3 F = mx_compute_fresnel(NdotV, fd);
        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
        vec3 Li = mx_environment_radiance(N, V, X, safeAlpha, distribution, fd);
        bsdf.response = Li * comp * weight;
    }
}


void mx_translucent_bsdf(ClosureData closureData, float weight, vec3 color, vec3 N, inout BSDF bsdf)
{
    bsdf.throughput = vec3(0.0);

    if (weight < M_FLOAT_EPS)
    {
        return;
    }

    vec3 V = closureData.V;
    vec3 L = closureData.L;

    // Invert normal since we're transmitting light from the other side
    N = -N;

    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        float NdotL = clamp(dot(N, L), 0.0, 1.0);
        bsdf.response = color * weight * NdotL * M_PI_INV;
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        vec3 Li = mx_environment_irradiance(N);
        bsdf.response = Li * color * weight;
    }
}


const float FUJII_CONSTANT_1 = 0.5 - 2.0 / (3.0 * M_PI);
const float FUJII_CONSTANT_2 = 2.0 / 3.0 - 28.0 / (15.0 * M_PI);

// Qualitative Oren-Nayar diffuse with simplified math:
// https://www1.cs.columbia.edu/CAVE/publications/pdfs/Oren_SIGGRAPH94.pdf
float mx_oren_nayar_diffuse(float NdotV, float NdotL, float LdotV, float roughness)
{
    float s = LdotV - NdotL * NdotV;
    float stinv = (s > 0.0) ? s / max(NdotL, NdotV) : 0.0;

    float sigma2 = mx_square(roughness);
    float A = 1.0 - 0.5 * (sigma2 / (sigma2 + 0.33));
    float B = 0.45 * sigma2 / (sigma2 + 0.09);

    return A + B * stinv;
}

// Rational quadratic fit to Monte Carlo data for Oren-Nayar directional albedo.
float mx_oren_nayar_diffuse_dir_albedo_analytic(float NdotV, float roughness)
{
    vec2 r = vec2(1.0, 1.0) +
             vec2(-0.4297, -0.6076) * roughness +
             vec2(-0.7632, -0.4993) * NdotV * roughness +
             vec2(1.4385, 2.0315) * mx_square(roughness);
    return r.x / r.y;
}

float mx_oren_nayar_diffuse_dir_albedo_table_lookup(float NdotV, float roughness)
{
#if DIRECTIONAL_ALBEDO_METHOD == 1
    if (textureSize(u_albedoTable, 0).x > 1)
    {
        return texture(u_albedoTable, vec2(NdotV, roughness)).b;
    }
#endif
    return 0.0;
}

float mx_oren_nayar_diffuse_dir_albedo_monte_carlo(float NdotV, float roughness)
{
    NdotV = clamp(NdotV, M_FLOAT_EPS, 1.0);
    vec3 V = vec3(sqrt(1.0 - mx_square(NdotV)), 0, NdotV);

    float radiance = 0.0;
    const int SAMPLE_COUNT = 64;
    for (int i = 0; i < SAMPLE_COUNT; i++)
    {
        vec2 Xi = mx_spherical_fibonacci(i, SAMPLE_COUNT);

        // Compute the incoming light direction.
        vec3 L = mx_uniform_sample_hemisphere(Xi);
        
        // Compute dot products for this sample.
        float NdotL = clamp(L.z, M_FLOAT_EPS, 1.0);
        float LdotV = clamp(dot(L, V), M_FLOAT_EPS, 1.0);

        // Compute diffuse reflectance.
        float reflectance = mx_oren_nayar_diffuse(NdotV, NdotL, LdotV, roughness);

        // Add the radiance contribution of this sample.
        //   uniform_pdf = 1 / (2 * PI)
        //   radiance = (reflectance * NdotL) / (uniform_pdf * PI);
        radiance += reflectance * NdotL;
    }

    // Apply global components and normalize.
    radiance *= 2.0 / float(SAMPLE_COUNT);

    // Return the final directional albedo.
    return radiance;
}

float mx_oren_nayar_diffuse_dir_albedo(float NdotV, float roughness)
{
#if DIRECTIONAL_ALBEDO_METHOD == 2
    float dirAlbedo = mx_oren_nayar_diffuse_dir_albedo_monte_carlo(NdotV, roughness);
#else
    float dirAlbedo = mx_oren_nayar_diffuse_dir_albedo_analytic(NdotV, roughness);
#endif
    return clamp(dirAlbedo, 0.0, 1.0);
}

// Improved Oren-Nayar diffuse from Fujii:
// https://mimosa-pudica.net/improved-oren-nayar.html
float mx_oren_nayar_fujii_diffuse_dir_albedo(float cosTheta, float roughness)
{
    float A = 1.0 / (1.0 + FUJII_CONSTANT_1 * roughness);
    float B = roughness * A;
    float Si = sqrt(max(0.0, 1.0 - mx_square(cosTheta)));
    float G = Si * (mx_acos(clamp(cosTheta, -1.0, 1.0)) - Si * cosTheta) +
              2.0 * ((Si / cosTheta) * (1.0 - Si * Si * Si) - Si) / 3.0;
    return A + (B * G * M_PI_INV);
}

float mx_oren_nayar_fujii_diffuse_avg_albedo(float roughness)
{
    float A = 1.0 / (1.0 + FUJII_CONSTANT_1 * roughness);
    return A * (1.0 + FUJII_CONSTANT_2 * roughness);
}   

// Energy-compensated Oren-Nayar diffuse from OpenPBR Surface:
// https://academysoftwarefoundation.github.io/OpenPBR/
vec3 mx_oren_nayar_compensated_diffuse(float NdotV, float NdotL, float LdotV, float roughness, vec3 color)
{
    float s = LdotV - NdotL * NdotV;
    float stinv = (s > 0.0) ? s / max(NdotL, NdotV) : s;

    // Compute the single-scatter lobe.
    float A = 1.0 / (1.0 + FUJII_CONSTANT_1 * roughness);
    vec3 lobeSingleScatter = color * A * (1.0 + roughness * stinv);

    // Compute the multi-scatter lobe.
    float dirAlbedoV = mx_oren_nayar_fujii_diffuse_dir_albedo(NdotV, roughness);
    float dirAlbedoL = mx_oren_nayar_fujii_diffuse_dir_albedo(NdotL, roughness);
    float avgAlbedo = mx_oren_nayar_fujii_diffuse_avg_albedo(roughness);
    vec3 colorMultiScatter = mx_square(color) * avgAlbedo /
                             (vec3(1.0) - color * max(0.0, 1.0 - avgAlbedo));
    vec3 lobeMultiScatter = colorMultiScatter *
                            max(M_FLOAT_EPS, 1.0 - dirAlbedoV) *
                            max(M_FLOAT_EPS, 1.0 - dirAlbedoL) /
                            max(M_FLOAT_EPS, 1.0 - avgAlbedo);

    // Return the sum.
    return lobeSingleScatter + lobeMultiScatter;
}

vec3 mx_oren_nayar_compensated_diffuse_dir_albedo(float cosTheta, float roughness, vec3 color)
{
    float dirAlbedo = mx_oren_nayar_fujii_diffuse_dir_albedo(cosTheta, roughness);
    float avgAlbedo = mx_oren_nayar_fujii_diffuse_avg_albedo(roughness);
    vec3 colorMultiScatter = mx_square(color) * avgAlbedo /
                             (vec3(1.0) - color * max(0.0, 1.0 - avgAlbedo));
    return mix(colorMultiScatter, color, dirAlbedo);
}
  
// https://media.disneyanimation.com/uploads/production/publication_asset/48/asset/s2012_pbs_disney_brdf_notes_v3.pdf
// Section 5.3
float mx_burley_diffuse(float NdotV, float NdotL, float LdotH, float roughness)
{
    float F90 = 0.5 + (2.0 * roughness * mx_square(LdotH));
    float refL = mx_fresnel_schlick(NdotL, 1.0, F90);
    float refV = mx_fresnel_schlick(NdotV, 1.0, F90);
    return refL * refV;
}

// Compute the directional albedo component of Burley diffuse for the given
// view angle and roughness.  Curve fit provided by Stephen Hill.
float mx_burley_diffuse_dir_albedo(float NdotV, float roughness)
{
    float x = NdotV;
    float fit0 = 0.97619 - 0.488095 * mx_pow5(1.0 - x);
    float fit1 = 1.55754 + (-2.02221 + (2.56283 - 1.06244 * x) * x) * x;
    return mix(fit0, fit1, roughness);
}

// Evaluate the Burley diffusion profile for the given distance and diffusion shape.
// Based on https://graphics.pixar.com/library/ApproxBSSRDF/
vec3 mx_burley_diffusion_profile(float dist, vec3 shape)
{
    vec3 num1 = exp(-shape * dist);
    vec3 num2 = exp(-shape * dist / 3.0);
    float denom = max(dist, M_FLOAT_EPS);
    return (num1 + num2) / denom;
}

// Integrate the Burley diffusion profile over a sphere of the given radius.
// Inspired by Eric Penner's presentation in http://advances.realtimerendering.com/s2011/
vec3 mx_integrate_burley_diffusion(vec3 N, vec3 L, float radius, vec3 mfp)
{
    float theta = mx_acos(dot(N, L));

    // Estimate the Burley diffusion shape from mean free path.
    vec3 shape = vec3(1.0) / max(mfp, 0.1);

    // Integrate the profile over the sphere.
    vec3 sumD = vec3(0.0);
    vec3 sumR = vec3(0.0);
    const int SAMPLE_COUNT = 32;
    const float SAMPLE_WIDTH = (2.0 * M_PI) / float(SAMPLE_COUNT);
    for (int i = 0; i < SAMPLE_COUNT; i++)
    {
        float x = -M_PI + (float(i) + 0.5) * SAMPLE_WIDTH;
        float dist = radius * abs(2.0 * mx_sin(x * 0.5));
        vec3 R = mx_burley_diffusion_profile(dist, shape);
        sumD += R * max(mx_cos(theta + x), 0.0);
        sumR += R;
    }

    return sumD / sumR;
}

vec3 mx_subsurface_scattering_approx(vec3 N, vec3 L, vec3 P, vec3 albedo, vec3 mfp)
{
    float curvature = length(fwidth(N)) / length(fwidth(P));
    float radius = 1.0 / max(curvature, 0.01);
    return albedo * mx_integrate_burley_diffusion(N, L, radius, mfp) / vec3(M_PI);
}

void mx_subsurface_bsdf(ClosureData closureData, float weight, vec3 color, vec3 radius, float anisotropy, vec3 N, inout BSDF bsdf)
{
    bsdf.throughput = vec3(0.0);

    if (weight < M_FLOAT_EPS)
    {
        return;
    }

    vec3 V = closureData.V;
    vec3 L = closureData.L;
    vec3 P = closureData.P;
    float occlusion = closureData.occlusion;

    N = mx_forward_facing_normal(N, V);

    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        vec3 sss = mx_subsurface_scattering_approx(N, L, P, color, radius);
        float NdotL = clamp(dot(N, L), M_FLOAT_EPS, 1.0);
        float visibleOcclusion = 1.0 - NdotL * (1.0 - occlusion);
        bsdf.response = sss * visibleOcclusion * weight;
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        // For now, we render indirect subsurface as simple indirect diffuse.
        vec3 Li = mx_environment_irradiance(N);
        bsdf.response = Li * color * weight;
    }
}


void mx_oren_nayar_diffuse_bsdf(ClosureData closureData, float weight, vec3 color, float roughness, vec3 N, bool energy_compensation, inout BSDF bsdf)
{
    bsdf.throughput = vec3(0.0);

    if (weight < M_FLOAT_EPS)
    {
        return;
    }

    vec3 V = closureData.V;
    vec3 L = closureData.L;

    N = mx_forward_facing_normal(N, V);
    float NdotV = clamp(dot(N, V), M_FLOAT_EPS, 1.0);

    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        float NdotL = clamp(dot(N, L), M_FLOAT_EPS, 1.0);
        float LdotV = clamp(dot(L, V), M_FLOAT_EPS, 1.0);

        vec3 diffuse = energy_compensation ?
                       mx_oren_nayar_compensated_diffuse(NdotV, NdotL, LdotV, roughness, color) :
                       mx_oren_nayar_diffuse(NdotV, NdotL, LdotV, roughness) * color;
        bsdf.response = diffuse * closureData.occlusion * weight * NdotL * M_PI_INV;
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        vec3 diffuse = energy_compensation ?
                       mx_oren_nayar_compensated_diffuse_dir_albedo(NdotV, roughness, color) :
                       mx_oren_nayar_diffuse_dir_albedo(NdotV, roughness) * color;
        vec3 Li = mx_environment_irradiance(N);
        bsdf.response = Li * diffuse * weight;
    }
}


void mx_add_bsdf(ClosureData closureData, BSDF in1, BSDF in2, out BSDF result)
{
    result.response = in1.response + in2.response;

    // We derive the throughput for closure addition as follows:
    //   throughput_1 = 1 - dir_albedo_1
    //   throughput_2 = 1 - dir_albedo_2
    //   throughput_sum = 1 - (dir_albedo_1 + dir_albedo_2)
    //                  = 1 - ((1 - throughput_1) + (1 - throughput_2))
    //                  = throughput_1 + throughput_2 - 1
    result.throughput = max(in1.throughput + in2.throughput - 1.0, 0.0);
}


void mx_generalized_schlick_edf(ClosureData closureData, vec3 color0, vec3 color90, float exponent, EDF base, out EDF result)
{
    if (closureData.closureType == CLOSURE_TYPE_EMISSION)
    {
        vec3 N = mx_forward_facing_normal(closureData.N, closureData.V);
        float NdotV = clamp(dot(N, closureData.V), M_FLOAT_EPS, 1.0);
        vec3 f = mx_fresnel_schlick(NdotV, color0, color90, exponent);
        result = base * f;
    }
}


void mx_multiply_bsdf_float(ClosureData closureData, BSDF in1, float in2, out BSDF result)
{
    float weight = clamp(in2, 0.0, 1.0);
    result.response = in1.response * weight;
    result.throughput = in1.throughput;
}


void mx_mix_edf(ClosureData closureData, EDF fg, EDF bg, float mixValue, out EDF result)
{
    result = mix(bg, fg, mixValue);
}


void mx_layer_bsdf(ClosureData closureData, BSDF top, BSDF base, out BSDF result)
{
    result.response = top.response + base.response * top.throughput;
    result.throughput = top.throughput * base.throughput;
}


void mx_multiply_bsdf_color3(ClosureData closureData, BSDF in1, vec3 in2, out BSDF result)
{
    vec3 tint = clamp(in2, 0.0, 1.0);
    result.response = in1.response * tint;
    result.throughput = in1.throughput;
}

void NG_standard_surface_surfaceshader_100(float base, vec3 base_color, float diffuse_roughness, float metalness, float specular, vec3 specular_color, float specular_roughness, float specular_IOR, float specular_anisotropy, float specular_rotation, float transmission, vec3 transmission_color, float transmission_depth, vec3 transmission_scatter, float transmission_scatter_anisotropy, float transmission_dispersion, float transmission_extra_roughness, float subsurface, vec3 subsurface_color, vec3 subsurface_radius, float subsurface_scale, float subsurface_anisotropy, float sheen, vec3 sheen_color, float sheen_roughness, float coat, vec3 coat_color, float coat_roughness, float coat_anisotropy, float coat_rotation, float coat_IOR, vec3 coat_normal, float coat_affect_color, float coat_affect_roughness, float thin_film_thickness, float thin_film_IOR, float emission, vec3 emission_color, vec3 opacity, bool thin_walled, vec3 normal, vec3 tangent, out surfaceshader out1)
{
    vec2 coat_roughness_vector_out = vec2(0.0);
    mx_roughness_anisotropy(coat_roughness, coat_anisotropy, coat_roughness_vector_out);
    const float coat_tangent_rotate_degree_in2_tmp = 360.000000;
    float coat_tangent_rotate_degree_out = coat_rotation * coat_tangent_rotate_degree_in2_tmp;
    const float metalness_mix_fg_weight_in1_tmp = 1.000000;
    float metalness_mix_fg_weight_out = metalness_mix_fg_weight_in1_tmp * metalness;
    vec3 metal_reflectivity_out = base_color * base;
    vec3 metal_edgecolor_out = specular_color * specular;
    float coat_affect_roughness_multiply1_out = coat_affect_roughness * coat;
    const float tangent_rotate_degree_in2_tmp = 360.000000;
    float tangent_rotate_degree_out = specular_rotation * tangent_rotate_degree_in2_tmp;
    const float transmission_mix_fg_weight_in1_tmp = 1.000000;
    float transmission_mix_fg_weight_out = transmission_mix_fg_weight_in1_tmp * transmission;
    float transmission_roughness_add_out = specular_roughness + transmission_extra_roughness;
    float subsurface_selector_out = float(thin_walled);
    const float subsurface_color_nonnegative_in2_tmp = 0.000000;
    vec3 subsurface_color_nonnegative_out = max(subsurface_color, subsurface_color_nonnegative_in2_tmp);
    const float coat_clamped_low_tmp = 0.000000;
    const float coat_clamped_high_tmp = 1.000000;
    float coat_clamped_out = clamp(coat, coat_clamped_low_tmp, coat_clamped_high_tmp);
    vec3 subsurface_radius_scaled_out = subsurface_radius * subsurface_scale;
    const float subsurface_mix_mix_inv_amount_tmp = 1.000000;
    float subsurface_mix_mix_inv_out = subsurface_mix_mix_inv_amount_tmp - subsurface;
    const float base_color_nonnegative_in2_tmp = 0.000000;
    vec3 base_color_nonnegative_out = max(base_color, base_color_nonnegative_in2_tmp);
    const float transmission_mix_mix_inv_amount_tmp = 1.000000;
    float transmission_mix_mix_inv_out = transmission_mix_mix_inv_amount_tmp - transmission;
    const float metalness_mix_mix_inv_amount_tmp = 1.000000;
    float metalness_mix_mix_inv_out = metalness_mix_mix_inv_amount_tmp - metalness;
    const vec3 coat_attenuation_bg_tmp = vec3(1.000000, 1.000000, 1.000000);
    vec3 coat_attenuation_out = mix(coat_attenuation_bg_tmp, coat_color, coat);
    const float one_minus_coat_ior_in1_tmp = 1.000000;
    float one_minus_coat_ior_out = one_minus_coat_ior_in1_tmp - coat_IOR;
    const float one_plus_coat_ior_in1_tmp = 1.000000;
    float one_plus_coat_ior_out = one_plus_coat_ior_in1_tmp + coat_IOR;
    vec3 emission_weight_out = emission_color * emission;
    vec3 opacity_luminance_out = vec3(0.0);
    mx_luminance_color3(opacity, vec3(0.272229, 0.674082, 0.053689), opacity_luminance_out);
    vec3 coat_tangent_rotate_out = vec3(0.0);
    mx_rotate_vector3(tangent, coat_tangent_rotate_degree_out, coat_normal, coat_tangent_rotate_out);
    vec3 artistic_ior_ior = vec3(0.0);
    vec3 artistic_ior_extinction = vec3(0.0);
    mx_artistic_ior(metal_reflectivity_out, metal_edgecolor_out, artistic_ior_ior, artistic_ior_extinction);
    float coat_affect_roughness_multiply2_out = coat_affect_roughness_multiply1_out * coat_roughness;
    vec3 tangent_rotate_out = vec3(0.0);
    mx_rotate_vector3(tangent, tangent_rotate_degree_out, normal, tangent_rotate_out);
    const float transmission_roughness_clamped_low_tmp = 0.000000;
    const float transmission_roughness_clamped_high_tmp = 1.000000;
    float transmission_roughness_clamped_out = clamp(transmission_roughness_add_out, transmission_roughness_clamped_low_tmp, transmission_roughness_clamped_high_tmp);
    const float selected_subsurface_bsdf_mix_inv_amount_tmp = 1.000000;
    float selected_subsurface_bsdf_mix_inv_out = selected_subsurface_bsdf_mix_inv_amount_tmp - subsurface_selector_out;
    const float selected_subsurface_bsdf_fg_weight_in1_tmp = 1.000000;
    float selected_subsurface_bsdf_fg_weight_out = selected_subsurface_bsdf_fg_weight_in1_tmp * subsurface_selector_out;
    float coat_gamma_multiply_out = coat_clamped_out * coat_affect_color;
    float subsurface_mix_bg_weight_out = base * subsurface_mix_mix_inv_out;
    float coat_ior_to_F0_sqrt_out = one_minus_coat_ior_out / one_plus_coat_ior_out;
    const int opacity_luminance_float_index_tmp = 0;
    float opacity_luminance_float_out = opacity_luminance_out[opacity_luminance_float_index_tmp];
    vec3 coat_tangent_rotate_normalize_out = normalize(coat_tangent_rotate_out);
    const float coat_affected_roughness_fg_tmp = 1.000000;
    float coat_affected_roughness_out = mix(specular_roughness, coat_affected_roughness_fg_tmp, coat_affect_roughness_multiply2_out);
    vec3 tangent_rotate_normalize_out = normalize(tangent_rotate_out);
    const float coat_affected_transmission_roughness_fg_tmp = 1.000000;
    float coat_affected_transmission_roughness_out = mix(transmission_roughness_clamped_out, coat_affected_transmission_roughness_fg_tmp, coat_affect_roughness_multiply2_out);
    const float selected_subsurface_bsdf_bg_weight_in1_tmp = 1.000000;
    float selected_subsurface_bsdf_bg_weight_out = selected_subsurface_bsdf_bg_weight_in1_tmp * selected_subsurface_bsdf_mix_inv_out;
    const float coat_gamma_in2_tmp = 1.000000;
    float coat_gamma_out = coat_gamma_multiply_out + coat_gamma_in2_tmp;
    float coat_ior_to_F0_out = coat_ior_to_F0_sqrt_out * coat_ior_to_F0_sqrt_out;
    const float coat_tangent_value2_tmp = 0.000000;
    vec3 coat_tangent_out = (coat_anisotropy > coat_tangent_value2_tmp) ? coat_tangent_rotate_normalize_out : tangent;
    vec2 main_roughness_out = vec2(0.0);
    mx_roughness_anisotropy(coat_affected_roughness_out, specular_anisotropy, main_roughness_out);
    const float main_tangent_value2_tmp = 0.000000;
    vec3 main_tangent_out = (specular_anisotropy > main_tangent_value2_tmp) ? tangent_rotate_normalize_out : tangent;
    vec2 transmission_roughness_out = vec2(0.0);
    mx_roughness_anisotropy(coat_affected_transmission_roughness_out, specular_anisotropy, transmission_roughness_out);
    vec3 coat_affected_subsurface_color_out = pow(subsurface_color_nonnegative_out, vec3(coat_gamma_out));
    vec3 coat_affected_diffuse_color_out = pow(base_color_nonnegative_out, vec3(coat_gamma_out));
    const float one_minus_coat_ior_to_F0_in1_tmp = 1.000000;
    float one_minus_coat_ior_to_F0_out = one_minus_coat_ior_to_F0_in1_tmp - coat_ior_to_F0_out;
    vec3 emission_color0_out = vec3(0.0);
    NG_convert_float_color3(one_minus_coat_ior_to_F0_out, emission_color0_out);
    surfaceshader shader_constructor_out = surfaceshader(vec3(0.0),vec3(0.0));
    {
        vec3 N = normalize(vd.normalWorld);
        vec3 V = normalize(u_viewPosition - vd.positionWorld);
        vec3 P = vd.positionWorld;
        vec3 L = vec3(0.000000, 0.000000, 0.000000);
        float occlusion = 1.0;

        float surfaceOpacity = opacity_luminance_float_out;

        // Shadow occlusion

        // Ambient occlusion
        occlusion = 1.0;

        // Add environment contribution
        {
            ClosureData closureData = makeClosureData(CLOSURE_TYPE_INDIRECT, L, V, N, P, occlusion);
            BSDF coat_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_dielectric_bsdf(closureData, coat, vec3(1.000000, 1.000000, 1.000000), coat_IOR, coat_roughness_vector_out, false, 0.000000, 1.500000, coat_normal, coat_tangent_out, 0, 0, coat_bsdf_out);
            BSDF metal_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_conductor_bsdf(closureData, metalness_mix_fg_weight_out, artistic_ior_ior, artistic_ior_extinction, main_roughness_out, false, thin_film_thickness, thin_film_IOR, normal, main_tangent_out, 0, metal_bsdf_out);
            BSDF specular_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_dielectric_bsdf(closureData, specular, specular_color, specular_IOR, main_roughness_out, false, thin_film_thickness, thin_film_IOR, normal, main_tangent_out, 0, 0, specular_bsdf_out);
            BSDF transmission_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_dielectric_bsdf(closureData, transmission_mix_fg_weight_out, transmission_color, specular_IOR, transmission_roughness_out, false, 0.000000, 1.500000, normal, main_tangent_out, 0, 1, transmission_bsdf_out);
            BSDF sheen_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_sheen_bsdf(closureData, sheen, sheen_color, sheen_roughness, normal, 0, sheen_bsdf_out);
            BSDF translucent_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_translucent_bsdf(closureData, selected_subsurface_bsdf_fg_weight_out, coat_affected_subsurface_color_out, normal, translucent_bsdf_out);
            BSDF subsurface_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_subsurface_bsdf(closureData, selected_subsurface_bsdf_bg_weight_out, coat_affected_subsurface_color_out, subsurface_radius_scaled_out, subsurface_anisotropy, normal, subsurface_bsdf_out);
            BSDF selected_subsurface_bsdf_add_out = BSDF(vec3(0.0),vec3(1.0));
            mx_add_bsdf(closureData, translucent_bsdf_out, subsurface_bsdf_out, selected_subsurface_bsdf_add_out);
            BSDF subsurface_mix_fg_mul_out = BSDF(vec3(0.0),vec3(1.0));
            mx_multiply_bsdf_float(closureData, selected_subsurface_bsdf_add_out, subsurface, subsurface_mix_fg_mul_out);
            BSDF diffuse_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_oren_nayar_diffuse_bsdf(closureData, subsurface_mix_bg_weight_out, coat_affected_diffuse_color_out, diffuse_roughness, normal, false, diffuse_bsdf_out);
            BSDF subsurface_mix_add_out = BSDF(vec3(0.0),vec3(1.0));
            mx_add_bsdf(closureData, subsurface_mix_fg_mul_out, diffuse_bsdf_out, subsurface_mix_add_out);
            BSDF sheen_layer_out = BSDF(vec3(0.0),vec3(1.0));
            mx_layer_bsdf(closureData, sheen_bsdf_out, subsurface_mix_add_out, sheen_layer_out);
            BSDF transmission_mix_bg_mul_out = BSDF(vec3(0.0),vec3(1.0));
            mx_multiply_bsdf_float(closureData, sheen_layer_out, transmission_mix_mix_inv_out, transmission_mix_bg_mul_out);
            BSDF transmission_mix_add_out = BSDF(vec3(0.0),vec3(1.0));
            mx_add_bsdf(closureData, transmission_bsdf_out, transmission_mix_bg_mul_out, transmission_mix_add_out);
            BSDF specular_layer_out = BSDF(vec3(0.0),vec3(1.0));
            mx_layer_bsdf(closureData, specular_bsdf_out, transmission_mix_add_out, specular_layer_out);
            BSDF metalness_mix_bg_mul_out = BSDF(vec3(0.0),vec3(1.0));
            mx_multiply_bsdf_float(closureData, specular_layer_out, metalness_mix_mix_inv_out, metalness_mix_bg_mul_out);
            BSDF metalness_mix_add_out = BSDF(vec3(0.0),vec3(1.0));
            mx_add_bsdf(closureData, metal_bsdf_out, metalness_mix_bg_mul_out, metalness_mix_add_out);
            BSDF thin_film_layer_attenuated_out = BSDF(vec3(0.0),vec3(1.0));
            mx_multiply_bsdf_color3(closureData, metalness_mix_add_out, coat_attenuation_out, thin_film_layer_attenuated_out);
            BSDF coat_layer_out = BSDF(vec3(0.0),vec3(1.0));
            mx_layer_bsdf(closureData, coat_bsdf_out, thin_film_layer_attenuated_out, coat_layer_out);

            shader_constructor_out.color += occlusion * coat_layer_out.response;
        }

        // Add surface emission
        {
            ClosureData closureData = makeClosureData(CLOSURE_TYPE_EMISSION, L, V, N, P, occlusion);
            EDF emission_edf_out = EDF(0.0);
            mx_uniform_edf(closureData, emission_weight_out, emission_edf_out);
            EDF coat_tinted_emission_edf_out = EDF(0.0);
            mx_multiply_edf_color3(closureData, emission_edf_out, coat_color, coat_tinted_emission_edf_out);
            EDF coat_emission_edf_out = EDF(0.0);
            mx_generalized_schlick_edf(closureData, emission_color0_out, vec3(0.000000, 0.000000, 0.000000), 5.000000, coat_tinted_emission_edf_out, coat_emission_edf_out);
            EDF blended_coat_emission_edf_out = EDF(0.0);
            mx_mix_edf(closureData, coat_emission_edf_out, emission_edf_out, coat, blended_coat_emission_edf_out);
            shader_constructor_out.color += blended_coat_emission_edf_out;
        }

        // Calculate the BSDF transmission for viewing direction
        ClosureData closureData = makeClosureData(CLOSURE_TYPE_TRANSMISSION, L, V, N, P, occlusion);
        BSDF coat_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        mx_dielectric_bsdf(closureData, coat, vec3(1.000000, 1.000000, 1.000000), coat_IOR, coat_roughness_vector_out, false, 0.000000, 1.500000, coat_normal, coat_tangent_out, 0, 0, coat_bsdf_out);
        BSDF metal_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        mx_conductor_bsdf(closureData, metalness_mix_fg_weight_out, artistic_ior_ior, artistic_ior_extinction, main_roughness_out, false, thin_film_thickness, thin_film_IOR, normal, main_tangent_out, 0, metal_bsdf_out);
        BSDF specular_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        mx_dielectric_bsdf(closureData, specular, specular_color, specular_IOR, main_roughness_out, false, thin_film_thickness, thin_film_IOR, normal, main_tangent_out, 0, 0, specular_bsdf_out);
        BSDF transmission_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        mx_dielectric_bsdf(closureData, transmission_mix_fg_weight_out, transmission_color, specular_IOR, transmission_roughness_out, false, 0.000000, 1.500000, normal, main_tangent_out, 0, 1, transmission_bsdf_out);
        BSDF sheen_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        mx_sheen_bsdf(closureData, sheen, sheen_color, sheen_roughness, normal, 0, sheen_bsdf_out);
        BSDF translucent_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        mx_translucent_bsdf(closureData, selected_subsurface_bsdf_fg_weight_out, coat_affected_subsurface_color_out, normal, translucent_bsdf_out);
        BSDF subsurface_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        mx_subsurface_bsdf(closureData, selected_subsurface_bsdf_bg_weight_out, coat_affected_subsurface_color_out, subsurface_radius_scaled_out, subsurface_anisotropy, normal, subsurface_bsdf_out);
        BSDF selected_subsurface_bsdf_add_out = BSDF(vec3(0.0),vec3(1.0));
        mx_add_bsdf(closureData, translucent_bsdf_out, subsurface_bsdf_out, selected_subsurface_bsdf_add_out);
        BSDF subsurface_mix_fg_mul_out = BSDF(vec3(0.0),vec3(1.0));
        mx_multiply_bsdf_float(closureData, selected_subsurface_bsdf_add_out, subsurface, subsurface_mix_fg_mul_out);
        BSDF diffuse_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        mx_oren_nayar_diffuse_bsdf(closureData, subsurface_mix_bg_weight_out, coat_affected_diffuse_color_out, diffuse_roughness, normal, false, diffuse_bsdf_out);
        BSDF subsurface_mix_add_out = BSDF(vec3(0.0),vec3(1.0));
        mx_add_bsdf(closureData, subsurface_mix_fg_mul_out, diffuse_bsdf_out, subsurface_mix_add_out);
        BSDF sheen_layer_out = BSDF(vec3(0.0),vec3(1.0));
        mx_layer_bsdf(closureData, sheen_bsdf_out, subsurface_mix_add_out, sheen_layer_out);
        BSDF transmission_mix_bg_mul_out = BSDF(vec3(0.0),vec3(1.0));
        mx_multiply_bsdf_float(closureData, sheen_layer_out, transmission_mix_mix_inv_out, transmission_mix_bg_mul_out);
        BSDF transmission_mix_add_out = BSDF(vec3(0.0),vec3(1.0));
        mx_add_bsdf(closureData, transmission_bsdf_out, transmission_mix_bg_mul_out, transmission_mix_add_out);
        BSDF specular_layer_out = BSDF(vec3(0.0),vec3(1.0));
        mx_layer_bsdf(closureData, specular_bsdf_out, transmission_mix_add_out, specular_layer_out);
        BSDF metalness_mix_bg_mul_out = BSDF(vec3(0.0),vec3(1.0));
        mx_multiply_bsdf_float(closureData, specular_layer_out, metalness_mix_mix_inv_out, metalness_mix_bg_mul_out);
        BSDF metalness_mix_add_out = BSDF(vec3(0.0),vec3(1.0));
        mx_add_bsdf(closureData, metal_bsdf_out, metalness_mix_bg_mul_out, metalness_mix_add_out);
        BSDF thin_film_layer_attenuated_out = BSDF(vec3(0.0),vec3(1.0));
        mx_multiply_bsdf_color3(closureData, metalness_mix_add_out, coat_attenuation_out, thin_film_layer_attenuated_out);
        BSDF coat_layer_out = BSDF(vec3(0.0),vec3(1.0));
        mx_layer_bsdf(closureData, coat_bsdf_out, thin_film_layer_attenuated_out, coat_layer_out);
        shader_constructor_out.color += coat_layer_out.response;

        // Compute and apply surface opacity
        {
            shader_constructor_out.color *= surfaceOpacity;
            shader_constructor_out.transparency = mix(vec3(1.000000, 1.000000, 1.000000), shader_constructor_out.transparency, surfaceOpacity);
        }
    }

    out1 = shader_constructor_out;
}

void main()
{
    vec3 geomprop_Nworld_out1 = normalize(vd.normalWorld);
    vec3 geomprop_Tworld_out1 = normalize(vd.tangentWorld);
    vec2 geomprop_UV0_out1 = vd.texcoord_0.xy;
    vec2 legacy_tiles_realworld_scale_unit_out = legacy_tiles_realworld_scale_unit_in1 * legacy_tiles_realworld_scale_unit_in2;
    vec2 legacy_tiles_realworld_offset_unit_out = legacy_tiles_realworld_offset_unit_in1 * legacy_tiles_realworld_offset_unit_in2;
    float legacy_tiles_rotation_angle_unit_out = legacy_tiles_rotation_angle_unit_in1 * legacy_tiles_rotation_angle_unit_in2;
    vec3 legacy_tiles_output_color3 = vec3(0.0);
    float legacy_tiles_output_alpha = 0.0;
    vec4 legacy_tiles_output_color4 = vec4(0.0);
    NG_legacy_tiles_color3(geomprop_UV0_out1, legacy_tiles_tile_color, legacy_tiles_grout_color, legacy_tiles_tiles_num_x, legacy_tiles_tiles_num_y, legacy_tiles_grout_gap_x, legacy_tiles_grout_gap_y, legacy_tiles_grout_bias, legacy_tiles_line_shift, legacy_tiles_random_shift, legacy_tiles_color_variance, legacy_tiles_fade_variance, legacy_tiles_seed, legacy_tiles_brightness_variance, legacy_tiles_alpha_fade, legacy_tiles_roughness_scale, legacy_tiles_roughness_amount, legacy_tiles_rows_mod_enable, legacy_tiles_num_rows, legacy_tiles_rows_mod_amount, legacy_tiles_realworld_scale_unit_out, legacy_tiles_realworld_offset_unit_out, legacy_tiles_rotation_angle_unit_out, legacy_tiles_tile_x, legacy_tiles_tile_y, legacy_tiles_output_color3, legacy_tiles_output_alpha, legacy_tiles_output_color4);
    float add_float_out = legacy_tiles_output_alpha + add_float_in2;
    vec3 convert_float_color3_out = vec3(0.0);
    NG_convert_float_color3(add_float_out, convert_float_color3_out);
    surfaceshader SR_testmat1_out = surfaceshader(vec3(0.0),vec3(0.0));
    NG_standard_surface_surfaceshader_100(SR_testmat1_base, legacy_tiles_output_color3, SR_testmat1_diffuse_roughness, SR_testmat1_metalness, SR_testmat1_specular, SR_testmat1_specular_color, SR_testmat1_specular_roughness, SR_testmat1_specular_IOR, SR_testmat1_specular_anisotropy, SR_testmat1_specular_rotation, SR_testmat1_transmission, SR_testmat1_transmission_color, SR_testmat1_transmission_depth, SR_testmat1_transmission_scatter, SR_testmat1_transmission_scatter_anisotropy, SR_testmat1_transmission_dispersion, SR_testmat1_transmission_extra_roughness, SR_testmat1_subsurface, SR_testmat1_subsurface_color, SR_testmat1_subsurface_radius, SR_testmat1_subsurface_scale, SR_testmat1_subsurface_anisotropy, SR_testmat1_sheen, SR_testmat1_sheen_color, SR_testmat1_sheen_roughness, SR_testmat1_coat, SR_testmat1_coat_color, SR_testmat1_coat_roughness, SR_testmat1_coat_anisotropy, SR_testmat1_coat_rotation, SR_testmat1_coat_IOR, geomprop_Nworld_out1, SR_testmat1_coat_affect_color, SR_testmat1_coat_affect_roughness, SR_testmat1_thin_film_thickness, SR_testmat1_thin_film_IOR, SR_testmat1_emission, SR_testmat1_emission_color, convert_float_color3_out, SR_testmat1_thin_walled, geomprop_Nworld_out1, geomprop_Tworld_out1, SR_testmat1_out);
    material M_legacy_tiles_out = SR_testmat1_out;
    out1 = vec4(M_legacy_tiles_out.color, 1.0);
}

