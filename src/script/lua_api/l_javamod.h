// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "lua_api/l_base.h"

class ModApiJavaMod : public ModApiBase
{
private:
	static int l_load(lua_State *L);
	static int l_change(lua_State *L);
	static int l_add(lua_State *L);
	static int l_remove(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
};
