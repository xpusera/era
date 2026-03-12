// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "irrlichttypes_bloated.h"

struct FogVariantParams
{
	video::SColor color{255, 0, 0, 0};
	float fog_start = 0.9f;
	float fog_end = 1.0f;
};

struct FogControlParams
{
	bool enabled = false;
	float blend_time = 0.0f;
	FogVariantParams base;
	bool has_weather = false;
	FogVariantParams weather;
};

