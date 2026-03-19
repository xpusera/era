// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "lua_api/l_base.h"
#include "network/camera_control_packet.h"

class PlayerSAO;

class ModApiCameraControl : public ModApiBase
{
public:
	static void Initialize(lua_State *L, int top);

	static CameraEaseType read_ease_type(lua_State *L, int index);
	static CameraEaseSpec read_ease_spec(lua_State *L, int opts_index);
	static bool read_bool_field(lua_State *L, int table_index, const char *name, bool def);
	static f32 read_float_field(lua_State *L, int table_index, const char *name, f32 def);
	static v3f read_v3f_field(lua_State *L, int table_index, const char *name, const v3f &def);
	static u32 read_color_argb(lua_State *L, int index);
	static PlayerSAO *check_player_sao(lua_State *L, int index);
	static u8 build_flags(const CameraControlState &st, bool reset);
	static void send_state(lua_State *L, PlayerSAO *psao, bool reset, u16 field_mask);

	// Lua API functions
	static int l_set_pos(lua_State *L);
	static int l_set_rot(lua_State *L);
	static int l_set_fov(lua_State *L);
	static int l_set_tilt(lua_State *L);
	static int l_set_offset(lua_State *L);
	static int l_set_third_person(lua_State *L);
	static int l_detach(lua_State *L);
	static int l_attach(lua_State *L);
	static int l_set_orbit(lua_State *L);
	static int l_set_spectator(lua_State *L);
	static int l_shake(lua_State *L);
	static int l_fade(lua_State *L);
	static int l_lock_perspective(lua_State *L);
	static int l_reset(lua_State *L);
	static int l_get_pos(lua_State *L);
	static int l_get_rot(lua_State *L);
	static int l_get_fov(lua_State *L);
	static int l_is_detached(lua_State *L);
};
