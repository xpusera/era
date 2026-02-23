// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "lua_api/l_base.h"

class ModApiHTMLView : public ModApiBase
{
private:
	static int l_run(lua_State *L);
	static int l_stop(lua_State *L);
	static int l_display(lua_State *L);
	static int l_send(lua_State *L);
	static int l_navigate(lua_State *L);
	static int l_inject(lua_State *L);
	static int l_pipe(lua_State *L);
	static int l_on_message(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
};
