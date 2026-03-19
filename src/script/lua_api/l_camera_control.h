// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "lua_api/l_base.h"

class ModApiCameraControl : public ModApiBase
{
public:
	static void Initialize(lua_State *L, int top);
};
