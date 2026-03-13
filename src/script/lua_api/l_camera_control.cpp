// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_camera_control.h"

#include "common/c_converter.h"
#include "lua_api/l_internal.h"
#include "lua_api/l_object.h"

#include "server.h"
#include "serverenvironment.h"
#include "remoteplayer.h"
#include "server/player_sao.h"
#include "player.h"

namespace {
	u8 parseEaseType(lua_State *L, int idx)
	{
		if (!lua_istable(L, idx))
			return 0;
		lua_getfield(L, idx, "type");
		std::string t = lua_isstring(L, -1) ? std::string(lua_tostring(L, -1)) : "linear";
		lua_pop(L, 1);

		if (t == "linear")
			return 0;
		if (t == "in_cubic")
			return 1;
		if (t == "out_cubic")
			return 2;
		if (t == "in_out_cubic")
			return 3;
		if (t == "out_back")
			return 4;
		if (t == "in_back")
			return 5;
		if (t == "in_out_back")
			return 6;
		if (t == "out_elastic")
			return 7;
		return 0;
	}

	f32 parseEaseTime(lua_State *L, int idx)
	{
		if (!lua_istable(L, idx))
			return 0.0f;
		return getfloatfield_default(L, idx, "time", 0.0f);
	}

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

		u8 parsePreset(lua_State *L, int idx)
		{
			std::string p(luaL_checkstring(L, idx));
			if (p == "first_person")
				return 0;
			if (p == "third_person")
				return 1;
			if (p == "third_person_front")
				return 2;
			if (p == "free")
				return 3;
			if (p == "follow_orbit")
				return 4;
			if (p == "body_offset")
				return 5;
			if (p == "spectator")
				return 6;
			throw LuaError("core.camera: invalid preset: " + p);
		}

	bool readVecField(lua_State *L, int tableidx, const char *name, v3f *out)
	{
		lua_getfield(L, tableidx, name);
		bool ok = lua_istable(L, -1);
		if (ok)
			*out = check_v3f(L, -1);
		lua_pop(L, 1);
		return ok;
	}
}

int ModApiCameraControl::l_set(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	RemotePlayer *player = getRemotePlayer(L, 1);
	if (!player)
		return 0;

	u8 preset = parsePreset(L, 2);

	Server *server = ModApiBase::getServer(L);
	session_t peer_id = player->getPeerId();

	f32 ease_time = 0.0f;
		u8 ease_type = 0;
		bool lock_input = false;

		if (lua_istable(L, 3)) {
		lua_getfield(L, 3, "ease");
		ease_time = parseEaseTime(L, -1);
		ease_type = parseEaseType(L, -1);
		lua_pop(L, 1);
			lock_input = getboolfield_default(L, 3, "lock_input", false);

		lua_getfield(L, 3, "fov");
		if (!lua_isnil(L, -1)) {
			PlayerFovSpec s;
			s.fov = readParam<float>(L, -1);
			s.is_multiplier = false;
			s.transition_time = ease_time;
			if (player->setFov(s))
				server->SendPlayerFov(peer_id);
		}

		if (preset != 6) {
			server->setCameraSpectatorActive(peer_id, false);
		}
		lua_pop(L, 1);
	}

	if (preset == 0 || preset == 1 || preset == 2) {
		server->SendCameraControlSetPreset(peer_id, preset, ease_time, ease_type, lock_input);
		return 0;
	}

		if (preset == 3) {
		luaL_checktype(L, 3, LUA_TTABLE);
		v3f pos;
		if (!readVecField(L, 3, "pos", &pos))
			throw LuaError("core.camera.set free: opts.pos required");

		v3f facing;
		v3f rot;
		bool has_facing = readVecField(L, 3, "facing", &facing);
		bool has_rot = readVecField(L, 3, "rot", &rot);
		u8 orient_type = has_facing ? 1 : 0;
		v3f orient = has_facing ? facing : rot;
		if (!has_facing && !has_rot)
			throw LuaError("core.camera.set free: opts.facing or opts.rot required");

		server->SendCameraControlSetFree(peer_id, ease_time, ease_type, lock_input, pos, orient_type, orient);
		return 0;
	}

	if (preset == 4) {
		luaL_checktype(L, 3, LUA_TTABLE);

		u8 target_type = 0;
		v3f target_pos;
		u16 target_object_id = 0;
		lua_getfield(L, 3, "target");
		if (lua_isnil(L, -1)) {
			lua_pop(L, 1);
			throw LuaError("core.camera.set follow_orbit: opts.target required");
		}

		if (preset == 5) {
			luaL_checktype(L, 3, LUA_TTABLE);

			v3f pos_offset;
			if (!readVecField(L, 3, "pos_offset", &pos_offset))
				throw LuaError("core.camera.set body_offset: opts.pos_offset required");

			v3f look_offset;
			readVecField(L, 3, "look_offset", &look_offset);

			server->SendCameraControlSetBodyOffset(peer_id, ease_time, ease_type, lock_input,
				pos_offset, look_offset);
			return 0;
		}

		if (preset == 6) {
			luaL_checktype(L, 3, LUA_TTABLE);

			bool has_lock_input = false;
			lua_getfield(L, 3, "lock_input");
			has_lock_input = !lua_isnil(L, -1);
			lua_pop(L, 1);
			if (!has_lock_input)
				lock_input = true;

			v3f pos;
			bool has_pos = readVecField(L, 3, "pos", &pos);
			f32 speed = getfloatfield_default(L, 3, "speed", 5.0f);
			f32 sprint_multiplier = getfloatfield_default(L, 3, "sprint_multiplier", 3.0f);
			bool vertical = getboolfield_default(L, 3, "vertical", true);

			v3f init_pos = pos;
			if (!has_pos) {
				if (PlayerSAO *psao = player->getPlayerSAO())
					init_pos = psao->getEyePosition() / BS;
			}
			server->setCameraSpectatorActive(peer_id, true, &init_pos);

			server->SendCameraControlSetSpectator(peer_id, ease_time, ease_type, lock_input,
				has_pos, pos, speed, sprint_multiplier, vertical);
			return 0;
		}
		if (lua_istable(L, -1)) {
			target_type = 0;
			target_pos = check_v3f(L, -1);
		} else {
			target_type = 1;
			ObjectRef *ref = checkObject<ObjectRef>(L, -1);
			ServerActiveObject *sao = ObjectRef::getobject(ref);
			if (!sao)
				throw LuaError("core.camera.set follow_orbit: target object is invalid");
			target_object_id = sao->getId();
		}
		lua_pop(L, 1);

		f32 radius = getfloatfield_default(L, 3, "radius", 5.0f);
		f32 yaw_offset = getfloatfield_default(L, 3, "yaw_offset", 0.0f);
		f32 pitch_offset = getfloatfield_default(L, 3, "pitch_offset", 0.0f);
		v3f view_offset;
		readVecField(L, 3, "view_offset", &view_offset);

		server->SendCameraControlSetFollowOrbit(peer_id, ease_time, ease_type, lock_input,
			target_type, target_pos, target_object_id, radius, yaw_offset, pitch_offset, view_offset);
		return 0;
	}

	return 0;
}

int ModApiCameraControl::l_clear(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	RemotePlayer *player = getRemotePlayer(L, 1);
	if (!player)
		return 0;

	f32 ease_time = 0.0f;
	u8 ease_type = 0;
	if (lua_istable(L, 2)) {
		lua_getfield(L, 2, "ease");
		ease_time = parseEaseTime(L, -1);
		ease_type = parseEaseType(L, -1);
		lua_pop(L, 1);
	}

	Server *server = ModApiBase::getServer(L);
	session_t peer_id = player->getPeerId();

	PlayerFovSpec s;
	s.fov = 0.0f;
	s.is_multiplier = false;
	s.transition_time = ease_time;
	if (player->setFov(s))
		server->SendPlayerFov(peer_id);

	server->SendCameraControlClear(peer_id, ease_time, ease_type);
	server->setCameraSpectatorActive(peer_id, false);
	return 0;
}

int ModApiCameraControl::l_get_spectator_pos(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	RemotePlayer *player = getRemotePlayer(L, 1);
	if (!player) {
		lua_pushnil(L);
		return 1;
	}

	Server *server = ModApiBase::getServer(L);
	v3f pos;
	if (!server->getCameraSpectatorPos(player->getPeerId(), &pos)) {
		lua_pushnil(L);
		return 1;
	}
	push_v3f(L, pos);
	return 1;
}

int ModApiCameraControl::l_shake(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	RemotePlayer *player = getRemotePlayer(L, 1);
	if (!player)
		return 0;

	luaL_checktype(L, 2, LUA_TTABLE);
	f32 intensity = getfloatfield_default(L, 2, "intensity", 0.0f);
	f32 duration = getfloatfield_default(L, 2, "duration", 0.0f);
	bool decay = getboolfield_default(L, 2, "decay", true);

	ModApiBase::getServer(L)->SendCameraControlShake(player->getPeerId(), intensity, duration, decay);
	return 0;
}

int ModApiCameraControl::l_fade(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	RemotePlayer *player = getRemotePlayer(L, 1);
	if (!player)
		return 0;

	luaL_checktype(L, 2, LUA_TTABLE);
	video::SColor color(255, 0, 0, 0);
	lua_getfield(L, 2, "color");
	if (!read_color(L, -1, &color))
		throw LuaError("core.camera.fade: invalid color");
	lua_pop(L, 1);

	f32 fade_in = getfloatfield_default(L, 2, "fade_in", 0.0f);
	f32 hold = getfloatfield_default(L, 2, "hold", 0.0f);
	f32 fade_out = getfloatfield_default(L, 2, "fade_out", 0.0f);

	ModApiBase::getServer(L)->SendCameraControlFade(player->getPeerId(), color.color, fade_in, hold, fade_out);
	return 0;
}

void ModApiCameraControl::Initialize(lua_State *L, int top)
{
	lua_newtable(L);
	int tbl = lua_gettop(L);

	registerFunction(L, "_set", l_set, tbl);
	registerFunction(L, "_clear", l_clear, tbl);
	registerFunction(L, "_shake", l_shake, tbl);
	registerFunction(L, "_fade", l_fade, tbl);
	registerFunction(L, "_get_spectator_pos", l_get_spectator_pos, tbl);

	lua_setfield(L, top, "camera");
}
