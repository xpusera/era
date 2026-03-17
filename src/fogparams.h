// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <string>
#include <vector>

#include "irrlichttypes_bloated.h"
#include "SColor.h"

static constexpr u8 FOG_MAX_LAYERS = 4;
static constexpr u8 FOG_MAX_COLOR_KEYFRAMES = 8;

enum class FogBoundaryShape : u8 {
	Sphere = 0,
	Box = 1,
	Cylinder = 2,
};

struct FogColorKeyframe
{
	f32 time = 0.0f; // [0..1]
	video::SColor color {0};
};

struct FogColorTransition
{
	f32 speed = 0.0f;
	std::vector<FogColorKeyframe> keyframes;

	bool active() const { return speed > 0.0f && keyframes.size() >= 2; }
};

struct FogLayer
{
	video::SColor color {0, 255, 255, 255};
	f32 max_density = 1.0f;
	f32 max_density_height = 0.0f;
	f32 zero_density_height = 0.0f;
	bool uniform = false;
	v3f direction {0.0f, 1.0f, 0.0f};
};

struct FogParams
{
	bool active = false;

	// Existing fields (kept stable):
	video::SColor color {0, 255, 255, 255};
	f32 fog_start = -1.0f; // [0..0.99], fraction of viewing range (-1 = default)
	f32 fog_end = -1.0f;   // [0..1], fraction of viewing range (-1 = default)
	f32 blend_time = 0.0f; // seconds

	// New fields:
	f32 max_density = 1.0f;
	f32 max_density_height = 0.0f; // node-space, interpreted along `direction`
	f32 zero_density_height = 0.0f; // node-space, interpreted along `direction`
	bool uniform = false;
	v3f direction {0.0f, 1.0f, 0.0f};
	f32 turbulence = 0.0f;
	std::vector<FogLayer> layers;
	FogColorTransition color_transition;
	f32 speed_density_scale = 0.0f;
};

struct FogBoundaryParams
{
	bool active = false;
	v3f pos {0.0f, 0.0f, 0.0f}; // node-space
	f32 radius = 0.0f; // node-space
	FogBoundaryShape shape = FogBoundaryShape::Sphere;
	FogParams fog;

	bool has_sound = false;
	std::string sound_name;
	f32 sound_gain = 1.0f;
	f32 sound_fade_in = 0.0f;
};

void fog_sanitize(FogParams &p);
void fog_sanitize(FogBoundaryParams &b);

class NetworkPacket;
void fog_serialize(NetworkPacket &pkt, const FogParams &p);
void fog_deserialize(NetworkPacket &pkt, FogParams &p);
void fog_boundary_serialize(NetworkPacket &pkt, const FogBoundaryParams &b);
void fog_boundary_deserialize(NetworkPacket &pkt, FogBoundaryParams &b);
