// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "l_base.h"

class ModApiCameraControl : public ModApiBase
{
private:
	static int l_set(lua_State *L);
	static int l_clear(lua_State *L);
	static int l_shake(lua_State *L);
	static int l_fade(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
};

