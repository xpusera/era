#pragma once

#include "lua_api/l_base.h"

class ModApiMyEngine : public ModApiBase {
private:
	static int l_get(lua_State *L);
	static int l_set(lua_State *L);
	static int l_hook(lua_State *L);
	static int l_watch(lua_State *L);
	static int l_modify(lua_State *L);
	static int l_rewrite(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
};
