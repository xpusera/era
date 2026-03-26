// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_javamod.h"
#include "common/c_converter.h"
#include "lua_api/l_internal.h"

#ifdef __ANDROID__
#include "javamod_jni.h"
#endif

int ModApiJavaMod::l_load(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string dex_path = readParam<std::string>(L, 2);

#ifdef __ANDROID__
	javamod_jni_load(id, dex_path);
	return 0;
#else
	return luaL_error(L, "javamod is only available on Android");
#endif
}

int ModApiJavaMod::l_change(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string target = readParam<std::string>(L, 2);
	std::string properties_json = readParam<std::string>(L, 3);

#ifdef __ANDROID__
	javamod_jni_change(id, target, properties_json);
	return 0;
#else
	return luaL_error(L, "javamod is only available on Android");
#endif
}

int ModApiJavaMod::l_add(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string type = readParam<std::string>(L, 2);
	std::string properties_json = readParam<std::string>(L, 3);

#ifdef __ANDROID__
	javamod_jni_add(id, type, properties_json);
	return 0;
#else
	return luaL_error(L, "javamod is only available on Android");
#endif
}

int ModApiJavaMod::l_remove(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string target = readParam<std::string>(L, 2);

#ifdef __ANDROID__
	javamod_jni_remove(id, target);
	return 0;
#else
	return luaL_error(L, "javamod is only available on Android");
#endif
}

void ModApiJavaMod::Initialize(lua_State *L, int top)
{
#ifdef __ANDROID__
	lua_newtable(L);
	int tbl = lua_gettop(L);

	registerFunction(L, "load", l_load, tbl);
	registerFunction(L, "change", l_change, tbl);
	registerFunction(L, "add", l_add, tbl);
	registerFunction(L, "remove", l_remove, tbl);

	lua_pushvalue(L, tbl);
	lua_setglobal(L, "javamod");
	lua_setfield(L, top, "javamod");
#else
	(void)L;
	(void)top;
#endif
}
