uniform lowp vec4 fogColor;
uniform float fogDistance;
uniform float fogShadingParameter;

uniform float fogExActive;
uniform vec4 fogExParams0; // max_density, max_density_height, zero_density_height, turbulence
uniform vec4 fogExParams1; // speed_density_scale, uniform, fog_start_ratio, fog_end_ratio
uniform vec4 fogExParams2; // player_speed_nodes, fog_range_bs, inv_bs, reserved
VARYING_ highp vec3 eyeVec;

VARYING_ lowp vec4 varColor;

void main(void)
{
	vec4 col = varColor;

	float dist = length(eyeVec);
	float start_bs = fogExParams2.y * fogExParams1.z;
	float end_bs = fogExParams2.y * fogExParams1.w;
	float fogginess_dist = clamp((dist - start_bs) / max(end_bs - start_bs, 0.001) + 0.0, 0.0, 1.0);
	float fog_den = fogginess_dist;
	if (fogExActive > 0.5) {
		float sp = clamp(fogExParams2.x / 10.0, 0.0, 1.0);
		float speed_scale = 1.0 + fogExParams1.x * sp;
		fog_den = clamp(fogginess_dist * fogExParams0.x * speed_scale, 0.0, 1.0);
	}
	float clarity = clamp(1.0 - fog_den + 0.0, 0.0, 1.0);
	col.rgb = mix(fogColor.rgb, col.rgb, clarity);

	gl_FragColor = col;
}
