// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "fogparams.h"

#include <algorithm>
#include <cmath>

#include "network/networkpacket.h"
#include "exceptions.h"

static v3f normalize_or_default(const v3f &v, const v3f &def)
{
	if (v.getLengthSQ() < 1e-12f)
		return def;
	v3f out = v;
	out.normalize();
	if (!std::isfinite(out.X) || !std::isfinite(out.Y) || !std::isfinite(out.Z))
		return def;
	return out;
}

void fog_sanitize(FogParams &p)
{
	p.max_density = std::clamp(p.max_density, 0.0f, 1.0f);
	p.turbulence = std::clamp(p.turbulence, 0.0f, 1.0f);
	p.speed_density_scale = std::max(0.0f, p.speed_density_scale);
	p.blend_time = std::max(0.0f, p.blend_time);
	p.direction = normalize_or_default(p.direction, v3f(0.0f, 1.0f, 0.0f));

	if (p.fog_start >= 0.0f)
		p.fog_start = std::clamp(p.fog_start, 0.0f, 0.99f);
	else
		p.fog_start = -1.0f;
	if (p.fog_end >= 0.0f)
		p.fog_end = std::clamp(p.fog_end, 0.0f, 1.0f);
	else
		p.fog_end = -1.0f;
	if (p.fog_start >= 0.0f && p.fog_end >= 0.0f)
		p.fog_end = std::max(p.fog_end, p.fog_start);

	p.color_transition.speed = std::max(0.0f, p.color_transition.speed);

	if (p.layers.size() > FOG_MAX_LAYERS)
		p.layers.resize(FOG_MAX_LAYERS);
	for (auto &l : p.layers) {
		l.max_density = std::clamp(l.max_density, 0.0f, 1.0f);
		l.direction = normalize_or_default(l.direction, v3f(0.0f, 1.0f, 0.0f));
	}

	if (p.color_transition.keyframes.size() > FOG_MAX_COLOR_KEYFRAMES)
		p.color_transition.keyframes.resize(FOG_MAX_COLOR_KEYFRAMES);
	for (auto &k : p.color_transition.keyframes)
		k.time = std::clamp(k.time, 0.0f, 1.0f);
	std::sort(p.color_transition.keyframes.begin(), p.color_transition.keyframes.end(),
		[](const FogColorKeyframe &a, const FogColorKeyframe &b) { return a.time < b.time; });
}

void fog_sanitize(FogBoundaryParams &b)
{
	b.radius = std::max(0.0f, b.radius);
	fog_sanitize(b.fog);
	b.sound_gain = std::max(0.0f, b.sound_gain);
	b.sound_fade_in = std::max(0.0f, b.sound_fade_in);
}

void fog_serialize(NetworkPacket &pkt, const FogParams &p_in)
{
	FogParams p = p_in;
	fog_sanitize(p);
	static constexpr u8 VERSION = 1;
	pkt << VERSION;
	pkt << p.active;

	pkt << p.color << p.fog_start << p.fog_end << p.blend_time;
	pkt << p.max_density << p.max_density_height << p.zero_density_height;
	pkt << p.uniform << p.direction;
	pkt << p.turbulence;
	pkt << p.speed_density_scale;

	u8 layer_count = std::min<u8>(p.layers.size(), FOG_MAX_LAYERS);
	pkt << layer_count;
	for (u8 i = 0; i < layer_count; i++) {
		const FogLayer &l = p.layers[i];
		pkt << l.color << l.max_density << l.max_density_height << l.zero_density_height;
		pkt << l.uniform << l.direction;
	}

	f32 ct_speed = p.color_transition.speed;
	pkt << ct_speed;
	u8 key_count = std::min<u8>(p.color_transition.keyframes.size(), FOG_MAX_COLOR_KEYFRAMES);
	pkt << key_count;
	for (u8 i = 0; i < key_count; i++) {
		const FogColorKeyframe &k = p.color_transition.keyframes[i];
		pkt << k.time << k.color;
	}
}

void fog_deserialize(NetworkPacket &pkt, FogParams &p)
{
	u8 version = 0;
	pkt >> version;
	if (version != 1)
		throw PacketError("Unsupported fog params version");

	pkt >> p.active;

	pkt >> p.color >> p.fog_start >> p.fog_end >> p.blend_time;
	pkt >> p.max_density >> p.max_density_height >> p.zero_density_height;
	pkt >> p.uniform >> p.direction;
	pkt >> p.turbulence;
	pkt >> p.speed_density_scale;

	u8 layer_count = 0;
	pkt >> layer_count;
	p.layers.clear();
	p.layers.reserve(std::min<u8>(layer_count, FOG_MAX_LAYERS));
	for (u8 i = 0; i < layer_count; i++) {
		FogLayer l;
		pkt >> l.color >> l.max_density >> l.max_density_height >> l.zero_density_height;
		pkt >> l.uniform >> l.direction;
		if (i < FOG_MAX_LAYERS)
			p.layers.emplace_back(std::move(l));
	}

	pkt >> p.color_transition.speed;
	u8 key_count = 0;
	pkt >> key_count;
	p.color_transition.keyframes.clear();
	p.color_transition.keyframes.reserve(std::min<u8>(key_count, FOG_MAX_COLOR_KEYFRAMES));
	for (u8 i = 0; i < key_count; i++) {
		FogColorKeyframe k;
		pkt >> k.time >> k.color;
		if (i < FOG_MAX_COLOR_KEYFRAMES)
			p.color_transition.keyframes.emplace_back(std::move(k));
	}

	fog_sanitize(p);
}

void fog_boundary_serialize(NetworkPacket &pkt, const FogBoundaryParams &b_in)
{
	FogBoundaryParams b = b_in;
	fog_sanitize(b);
	static constexpr u8 VERSION = 1;
	pkt << VERSION;
	pkt << b.active;
	pkt << b.pos << b.radius;
	pkt << (u8)b.shape;
	fog_serialize(pkt, b.fog);
	pkt << b.has_sound;
	if (b.has_sound) {
		pkt << b.sound_name << b.sound_gain << b.sound_fade_in;
	}
}

void fog_boundary_deserialize(NetworkPacket &pkt, FogBoundaryParams &b)
{
	u8 version = 0;
	pkt >> version;
	if (version != 1)
		throw PacketError("Unsupported fog boundary version");

	pkt >> b.active;
	pkt >> b.pos >> b.radius;
	u8 shape = 0;
	pkt >> shape;
	b.shape = (FogBoundaryShape)shape;
	fog_deserialize(pkt, b.fog);
	pkt >> b.has_sound;
	if (b.has_sound) {
		pkt >> b.sound_name >> b.sound_gain >> b.sound_fade_in;
	} else {
		b.sound_name.clear();
		b.sound_gain = 1.0f;
		b.sound_fade_in = 0.0f;
	}

	fog_sanitize(b);
}
