// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_sky_keyframes_control.h"

#include "common/c_converter.h"
#include "lua_api/l_internal.h"
#include "lua_api/l_object.h"

#include "remoteplayer.h"
#include "server.h"
#include "serverenvironment.h"
#include "server/player_sao.h"

#include "skykeyframesparams.h"

#include <algorithm>

namespace {
	RemotePlayer *getRemotePlayer(lua_State *L, int idx)
	{
		Server *server = ModApiBase::getServer(L);
		if (lua_isstring(L, idx)) {
			std::string name(lua_tostring(L, idx));
			return server->getEnv().getPlayer(name.c_str());
		}
		ObjectRef *ref = ModApiBase::checkObject<ObjectRef>(L, idx);
		ServerActiveObject *sao = ObjectRef::getobject(ref);
		PlayerSAO *psao = sao ? dynamic_cast<PlayerSAO *>(sao) : nullptr;
		return psao ? psao->getPlayer() : nullptr;
	}

	static video::SColor readRequiredColor(lua_State *L, int tableidx, const char *field)
	{
		lua_getfield(L, tableidx, field);
		video::SColor c(255, 255, 255, 255);
		if (!read_color(L, -1, &c))
			throw LuaError(std::string("set_sky_keyframes: missing/invalid '") + field + "'");
		lua_pop(L, 1);
		return c;
	}

	static video::SColor readOptionalColor(lua_State *L, int tableidx, const char *field, video::SColor fallback)
	{
		lua_getfield(L, tableidx, field);
		video::SColor c = fallback;
		if (!lua_isnil(L, -1)) {
			if (!read_color(L, -1, &c))
				throw LuaError(std::string("set_sky_keyframes: invalid '") + field + "'");
		}
		lua_pop(L, 1);
		return c;
	}
}

int ModApiSkyKeyframesControl::l_set_sky_keyframes(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	RemotePlayer *player = getRemotePlayer(L, 1);
	if (!player)
		return 0;

	SkyKeyframesParams params;
	params.enabled = false;

	if (lua_isnoneornil(L, 2)) {
		params.enabled = false;
	} else {
		luaL_checktype(L, 2, LUA_TTABLE);
		params.enabled = true;

		std::string interp = getstringfield_default(L, 2, "interpolation", "linear");
		if (interp == "cubic")
			params.interpolation = SkyKeyframeInterpolation::Cubic;
		else
			params.interpolation = SkyKeyframeInterpolation::Linear;

		size_t n = lua_objlen(L, 2);
		params.keyframes.clear();
		params.keyframes.reserve(n);
		for (size_t i = 0; i < n; i++) {
			lua_pushinteger(L, i + 1);
			lua_gettable(L, 2);
			luaL_checktype(L, -1, LUA_TTABLE);

			SkyKeyframe k;
			k.time = getfloatfield_default(L, -1, "time", 0.0f);
			k.time = rangelim(k.time, 0.0f, 1.0f);
			k.sky = readRequiredColor(L, -1, "sky");
			k.fog = readOptionalColor(L, -1, "fog", k.sky);
			k.ambient = readOptionalColor(L, -1, "ambient", video::SColor(255, 0, 0, 0));
			params.keyframes.push_back(k);

			lua_pop(L, 1);
		}

		std::sort(params.keyframes.begin(), params.keyframes.end(),
				[](const auto &a, const auto &b) { return a.time < b.time; });
	}

	Server *server = ModApiBase::getServer(L);
	server->setSkyKeyframes(player, params);
	return 0;
}

void ModApiSkyKeyframesControl::Initialize(lua_State *L, int top)
{
	API_FCT(set_sky_keyframes);
}
