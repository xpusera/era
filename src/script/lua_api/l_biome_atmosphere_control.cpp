// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_biome_atmosphere_control.h"

#include "common/c_converter.h"
#include "lua_api/l_internal.h"

#include "server.h"
#include "emerge.h"
#include "mapgen/mg_biome.h"

#include <algorithm>

int ModApiBiomeAtmosphereControl::l_register_biome_atmosphere(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	std::string biome_name = luaL_checkstring(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);

	Server *server = ModApiBase::getServer(L);
	EmergeManager *emerge = server ? server->getEmergeManager() : nullptr;
	const BiomeManager *bmgr = emerge ? emerge->getBiomeManager() : nullptr;
	if (!bmgr)
		throw LuaError("register_biome_atmosphere: biome manager not available");

	ObjDef *obj = bmgr->getByName(biome_name);
	if (!obj)
		throw LuaError("register_biome_atmosphere: unknown biome: " + biome_name);

	Server::BiomeAtmosphereDef def;

	lua_getfield(L, 2, "fog");
	if (lua_istable(L, -1)) {
		def.fog_enabled = true;
		video::SColor c(255, 0, 0, 0);
		lua_getfield(L, -1, "color");
		if (!read_color(L, -1, &c)) {
			lua_pop(L, 2);
			throw LuaError("register_biome_atmosphere: fog.color missing/invalid");
		}
		lua_pop(L, 1);
		def.fog_color = c.color;
		def.fog_start = getfloatfield_default(L, -1, "fog_start", def.fog_start);
		def.fog_end = getfloatfield_default(L, -1, "fog_end", def.fog_end);
		def.fog_blend_time = getfloatfield_default(L, -1, "blend_time", def.fog_blend_time);
		def.fog_blend_time = std::max(0.0f, def.fog_blend_time);
	}
	lua_pop(L, 1);

	lua_getfield(L, 2, "sky");
	if (lua_istable(L, -1)) {
		def.sky_enabled = true;
		video::SColor c(255, 255, 255, 255);
		lua_getfield(L, -1, "color");
		if (!read_color(L, -1, &c)) {
			lua_pop(L, 2);
			throw LuaError("register_biome_atmosphere: sky.color missing/invalid");
		}
		lua_pop(L, 1);
		def.sky_color = c.color;
	}
	lua_pop(L, 1);

	server->setBiomeAtmosphere(obj->index, def);
	return 0;
}

void ModApiBiomeAtmosphereControl::Initialize(lua_State *L, int top)
{
	API_FCT(register_biome_atmosphere);
}
