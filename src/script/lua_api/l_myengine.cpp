#include "lua_api/l_myengine.h"
#include "lua_api/l_internal.h"
#include "myengine/aliases.h"
#include "myengine/registry.h"
#include "common/c_converter.h"
#include "log.h"

/**
 * myengine.get(path) -> value
 */
int ModApiMyEngine::l_get(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string path = readParam<std::string>(L, 1);

	// Alias Layer resolution before registry lookup.
	std::string resolved_path = AliasLayer::resolve(path);

	// Simulation: For this task, we don't implement the full auto-generated
	// registry, so we just log the access.
	infostream << "[myengine] Calling myengine.get(\"" << path << "\") -> \""
			   << resolved_path << "\"" << std::endl;

	if (!Registry::path_exists(resolved_path)) {
		lua_pushnil(L);
		return 1;
	}

	// For simulation, just return a dummy value if it exists.
	lua_pushstring(L, "dummy_value");
	return 1;
}

/**
 * myengine.set(path, value)
 */
int ModApiMyEngine::l_set(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string path = readParam<std::string>(L, 1);

	// Alias Layer resolution before registry lookup.
	std::string resolved_path = AliasLayer::resolve(path);

	infostream << "[myengine] Calling myengine.set(\"" << path << "\") -> \""
			   << resolved_path << "\"" << std::endl;

	return 0;
}

/**
 * myengine.hook(path, callback)
 */
int ModApiMyEngine::l_hook(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string path = readParam<std::string>(L, 1);
	std::string resolved_path = AliasLayer::resolve(path);
	infostream << "[myengine] Calling myengine.hook(\"" << path << "\") -> \""
			   << resolved_path << "\"" << std::endl;
	return 0;
}

/**
 * myengine.watch(path, callback)
 */
int ModApiMyEngine::l_watch(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string path = readParam<std::string>(L, 1);
	std::string resolved_path = AliasLayer::resolve(path);
	infostream << "[myengine] Calling myengine.watch(\"" << path << "\") -> \""
			   << resolved_path << "\"" << std::endl;
	return 0;
}

/**
 * myengine.modify(path, callback)
 */
int ModApiMyEngine::l_modify(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string path = readParam<std::string>(L, 1);
	std::string resolved_path = AliasLayer::resolve(path);
	infostream << "[myengine] Calling myengine.modify(\"" << path << "\") -> \""
			   << resolved_path << "\"" << std::endl;
	return 0;
}

/**
 * myengine.rewrite(path, callback)
 */
int ModApiMyEngine::l_rewrite(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string path = readParam<std::string>(L, 1);
	std::string resolved_path = AliasLayer::resolve(path);
	infostream << "[myengine] Calling myengine.rewrite(\"" << path << "\") -> \""
			   << resolved_path << "\"" << std::endl;
	return 0;
}

void ModApiMyEngine::Initialize(lua_State *L, int top)
{
	lua_newtable(L);
	int tbl = lua_gettop(L);

	registerFunction(L, "get", l_get, tbl);
	registerFunction(L, "set", l_set, tbl);
	registerFunction(L, "hook", l_hook, tbl);
	registerFunction(L, "watch", l_watch, tbl);
	registerFunction(L, "modify", l_modify, tbl);
	registerFunction(L, "rewrite", l_rewrite, tbl);

	lua_pushvalue(L, tbl);
	lua_setglobal(L, "myengine");
	lua_setfield(L, top, "myengine");
}
