// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "l_base.h"

class ModApiFogControl : public ModApiBase
{
private:
	static int l_set_fog(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
};

