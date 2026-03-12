// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <vector>
#include "SColor.h"

struct SkyKeyframe
{
	float time = 0.0f; // normalized day fraction [0..1]
	video::SColor sky = video::SColor(255, 255, 255, 255);
	video::SColor fog = video::SColor(255, 255, 255, 255);
	video::SColor ambient = video::SColor(255, 0, 0, 0);
};

enum class SkyKeyframeInterpolation : u8
{
	Linear = 0,
	Cubic = 1,
};

struct SkyKeyframesParams
{
	bool enabled = false;
	SkyKeyframeInterpolation interpolation = SkyKeyframeInterpolation::Linear;
	std::vector<SkyKeyframe> keyframes;
};

