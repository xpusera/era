// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "l_base.h"

class ModApiBiomeAtmosphereControl : public ModApiBase
{
private:
	static int l_register_biome_atmosphere(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
};
