#define rendered texture0
#define bloom texture1

#ifdef GL_ES
// Dithering requires sufficient floating-point precision
#ifndef GL_FRAGMENT_PRECISION_HIGH
#undef ENABLE_DITHERING
#endif
#endif

struct ExposureParams {
	float compensationFactor;
};

uniform sampler2D rendered;
uniform sampler2D bloom;

uniform vec2 texelSize0;
uniform float animationTimer;

uniform ExposureParams exposureParams;
uniform lowp float bloomIntensity;
uniform lowp float saturation;

CENTROID_ VARYING_ mediump vec2 varTexCoord;

#ifdef ENABLE_AUTO_EXPOSURE
VARYING_ float exposure; // linear exposure factor, see vertex shader
#endif

#ifdef ENABLE_BLOOM

vec4 applyBloom(vec4 color, vec2 uv)
{
	vec3 light = texture2D(bloom, uv).rgb;
#ifdef ENABLE_BLOOM_DEBUG
	if (uv.x > 0.5 && uv.y < 0.5)
		return vec4(light, color.a);
	if (uv.x < 0.5)
		return color;
#endif
	color.rgb = mix(color.rgb, light, bloomIntensity);
	return color;
}

#endif

#if ENABLE_TONE_MAPPING

/* Hable's UC2 Tone mapping parameters
	A = 0.22;
	B = 0.30;
	C = 0.10;
	D = 0.20;
	E = 0.01;
	F = 0.30;
	W = 11.2;
	equation used:  ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F
*/

// highp for GLES, see <https://github.com/luanti-org/luanti/pull/14688>
highp vec3 uncharted2Tonemap(highp vec3 x)
{
	return ((x * (0.22 * x + 0.03) + 0.002) / (x * (0.22 * x + 0.3) + 0.06)) - 0.03333;
}

vec4 applyToneMapping(vec4 color)
{
	color = vec4(pow(color.rgb, vec3(2.2)), color.a);
	const float gamma = 1.6;
	const float exposureBias = 5.5;
	color.rgb = uncharted2Tonemap(exposureBias * color.rgb);
	// Precalculated white_scale from
	//vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
	vec3 whiteScale = vec3(1.036015346);
	color.rgb *= whiteScale;
	return vec4(pow(color.rgb, vec3(1.0 / gamma)), color.a);
}
#endif

vec3 applySaturation(vec3 color, float factor)
{
	// Calculate the perceived luminosity from the RGB color.
	// See also: https://www.w3.org/WAI/GL/wiki/Relative_luminance
	float brightness = dot(color, vec3(0.2125, 0.7154, 0.0721));
	return mix(vec3(brightness), color, factor);
}

vec3 vhs_rgb2yuv(vec3 rgb)
{
	float y = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
	float u = 0.493 * (rgb.b - y);
	float v = 0.877 * (rgb.r - y);
	return vec3(y, u, v);
}

vec3 vhs_yuv2rgb(vec3 yuv)
{
	float y = yuv.x;
	float u = yuv.y;
	float v = yuv.z;
	float r = y + v / 0.877;
	float g = y - 0.39393 * u - 0.58081 * v;
	float b = y + u / 0.493;
	return vec3(r, g, b);
}

highp float vhs_rand(vec2 co)
{
	return fract(sin(dot(co, vec2(127.1, 311.7))) * 43758.5453);
}

#ifdef ENABLE_DITHERING
// From http://alex.vlachos.com/graphics/Alex_Vlachos_Advanced_VR_Rendering_GDC2015.pdf
// and https://www.shadertoy.com/view/MslGR8 (5th one starting from the bottom)
// NOTE: `frag_coord` is in pixels (i.e. not normalized UV).
vec3 screen_space_dither(highp vec2 frag_coord) {
	// Iestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified for VR.
	highp vec3 dither = vec3(dot(vec2(171.0, 231.0), frag_coord));
	dither.rgb = fract(dither.rgb / vec3(103.0, 71.0, 97.0));

	// Subtract 0.5 to avoid slightly brightening the whole viewport.
	return (dither.rgb - 0.5) / 255.0;
}
#endif

void main(void)
{
	vec2 uv = varTexCoord.st;
	float time = animationTimer;

#ifdef VHS_LENS_DISTORTION
	uv = uv * 2.0 - 1.0;
	uv *= 1.0 + dot(uv, uv) * 0.1;
	uv = uv * 0.85 * 0.5 + 0.5;

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}
#endif

#ifdef ENABLE_SSAA
	vec4 color = vec4(0.);
	for (float dx = 1.; dx < SSAA_SCALE; dx += 2.)
	for (float dy = 1.; dy < SSAA_SCALE; dy += 2.)
		color += texture2D(rendered, uv + texelSize0 * vec2(dx, dy)).rgba;
	color /= SSAA_SCALE * SSAA_SCALE / 4.;
#else
	vec4 color = texture2D(rendered, uv).rgba;
#endif

#if defined(VHS_SHARPNESS) || defined(VHS_CHROMA_BLUR)
	vec3 center = color.rgb;
	vec3 up    = texture2D(rendered, uv + vec2(0.0, texelSize0.y)).rgb;
	vec3 down  = texture2D(rendered, uv - vec2(0.0, texelSize0.y)).rgb;
	vec3 left  = texture2D(rendered, uv - vec2(texelSize0.x, 0.0)).rgb;
	vec3 right = texture2D(rendered, uv + vec2(texelSize0.x, 0.0)).rgb;

#ifdef VHS_SHARPNESS
	color.rgb = center * 5.0 - (up + down + left + right);
#endif

#ifdef VHS_CHROMA_BLUR
	vec3 chroma_sum = center + up + down + left + right;
	chroma_sum += texture2D(rendered, uv + vec2(texelSize0.x, texelSize0.y)).rgb;
	chroma_sum += texture2D(rendered, uv + vec2(-texelSize0.x, texelSize0.y)).rgb;
	chroma_sum += texture2D(rendered, uv + vec2(texelSize0.x, -texelSize0.y)).rgb;
	chroma_sum += texture2D(rendered, uv + vec2(-texelSize0.x, -texelSize0.y)).rgb;
	vec3 chroma_avg = chroma_sum / 9.0;

	vec3 yuv_orig = vhs_rgb2yuv(color.rgb);
	vec3 yuv_blur = vhs_rgb2yuv(chroma_avg);
	color.rgb = vhs_yuv2rgb(vec3(yuv_orig.x, yuv_blur.yz));
#endif
#endif

#ifdef VHS_COLOR_DEPTH
	color.rgb = floor(color.rgb * 256.0) / 256.0;
#endif

#if defined(VHS_LUMA_NOISE) || defined(VHS_CHROMA_NOISE)
	vec3 yuv = vhs_rgb2yuv(color.rgb);
#ifdef VHS_LUMA_NOISE
	float l_noise = vhs_rand(uv + fract(time * 5.0));
	yuv.x += (l_noise - 0.5) * 0.05;
#endif
#ifdef VHS_CHROMA_NOISE
	float noise_u = vhs_rand(uv + fract(time * 5.0) + vec2(0.1, 0.1));
	float noise_v = vhs_rand(uv + fract(time * 5.0) + vec2(0.2, 0.2));
	yuv.y += (noise_u - 0.5) * 0.2;
	yuv.z += (noise_v - 0.5) * 0.2;
#endif
	color.rgb = vhs_yuv2rgb(yuv);
#endif

	// translate to linear colorspace (approximate)
	color.rgb = pow(color.rgb, vec3(2.2));

#ifdef ENABLE_BLOOM_DEBUG
	if (uv.x > 0.5 || uv.y > 0.5)
#endif
	{
		color.rgb *= exposureParams.compensationFactor;
#ifdef ENABLE_AUTO_EXPOSURE
		color.rgb *= exposure;
#endif
	}

#ifdef ENABLE_BLOOM
	color = applyBloom(color, uv);
#endif


	color.rgb = clamp(color.rgb, vec3(0.), vec3(1.));

	// return to sRGB colorspace (approximate)
	color.rgb = pow(color.rgb, vec3(1.0 / 2.2));

#ifdef ENABLE_BLOOM_DEBUG
	if (uv.x > 0.5 || uv.y > 0.5)
#endif
	{
#if ENABLE_TONE_MAPPING
		color = applyToneMapping(color);
#endif

		color.rgb = applySaturation(color.rgb, saturation);
	}

#ifdef VHS_INTERLACING
	float interlace = mod(floor(gl_FragCoord.y), 2.0);
	float alternate = mod(floor(time * 24.0), 2.0);
	if (mod(interlace + alternate, 2.0) > 0.5) {
		color.rgb *= 0.75;
	}
#endif

#ifdef VHS_ASPECT_RATIO
	if (abs(uv.x * 2.0 - 1.0) > 0.75) {
		color.rgb = vec3(0.0);
	}
#endif

#ifdef ENABLE_DITHERING
	// Apply dithering just before quantisation
	color.rgb += screen_space_dither(gl_FragCoord.xy);
#endif

	gl_FragColor = vec4(color.rgb, 1.0); // force full alpha to avoid holes in the image.
}
