// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_fog_control.h"

#include "common/c_converter.h"
#include "lua_api/l_internal.h"
#include "lua_api/l_object.h"

#include "fogparams.h"
#include "remoteplayer.h"
#include "server.h"
#include "serverenvironment.h"
#include "server/player_sao.h"

#include "util/numeric.h"

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

	FogVariantParams readVariant(lua_State *L, int idx)
	{
		FogVariantParams out;
		lua_getfield(L, idx, "color");
		video::SColor c(255, 0, 0, 0);
		if (!read_color(L, -1, &c))
			throw LuaError("set_fog: missing/invalid 'color'");
		out.color = c;
		lua_pop(L, 1);
		out.fog_start = getfloatfield_default(L, idx, "fog_start", out.fog_start);
		out.fog_end = getfloatfield_default(L, idx, "fog_end", out.fog_end);
		out.fog_start = rangelim(out.fog_start, 0.0f, 1.0f);
		out.fog_end = rangelim(out.fog_end, 0.0f, 1.0f);
		if (out.fog_end < out.fog_start)
			out.fog_end = out.fog_start;
		return out;
	}
}

int ModApiFogControl::l_set_fog(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	RemotePlayer *player = getRemotePlayer(L, 1);
	if (!player)
		return 0;

	FogControlParams params;
	params.enabled = false;
	params.blend_time = 0.0f;

	if (lua_isnoneornil(L, 2)) {
		params.enabled = false;
	} else {
		luaL_checktype(L, 2, LUA_TTABLE);
		params.enabled = true;
		params.base = readVariant(L, 2);
		params.blend_time = getfloatfield_default(L, 2, "blend_time", 0.0f);
		params.blend_time = std::max(0.0f, params.blend_time);

		lua_getfield(L, 2, "weather");
		if (lua_istable(L, -1)) {
			params.has_weather = true;
			params.weather = readVariant(L, -1);
		}
		lua_pop(L, 1);
	}

	Server *server = ModApiBase::getServer(L);
	server->setPlayerFogManualOverride(player->getPeerId(), params.enabled);
	server->setFog(player, params);
	return 0;
}

void ModApiFogControl::Initialize(lua_State *L, int top)
{
	API_FCT(set_fog);
}
