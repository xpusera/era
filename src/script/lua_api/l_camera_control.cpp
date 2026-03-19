// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_camera_control.h"

#include "lua_api/l_internal.h"
#include "lua_api/l_object.h"
#include "common/c_converter.h"

#include "remoteplayer.h"
#include "server.h"
#include "server/player_sao.h"
#include "server/serveractiveobject.h"

extern "C" {
#include <lauxlib.h>
}

static constexpr u8 CAMFLAG_RESET = 1 << 0;
static constexpr u8 CAMFLAG_LOCK_PERSPECTIVE = 1 << 1;
static constexpr u8 CAMFLAG_LOCK_INPUT = 1 << 2;
static constexpr u8 CAMFLAG_DETACHED = 1 << 3;
static constexpr u8 CAMFLAG_ORBIT = 1 << 4;
static constexpr u8 CAMFLAG_SPECTATOR = 1 << 5;

CameraEaseType ModApiCameraControl::read_ease_type(lua_State *L, int index)
{
	if (lua_isnil(L, index))
		return CameraEaseType::Linear;
	const char *s = luaL_checkstring(L, index);
	if (!s)
		return CameraEaseType::Linear;
	std::string_view v(s);
	if (v == "linear") return CameraEaseType::Linear;
	if (v == "in_cubic") return CameraEaseType::InCubic;
	if (v == "out_cubic") return CameraEaseType::OutCubic;
	if (v == "in_out_cubic") return CameraEaseType::InOutCubic;
	if (v == "out_back") return CameraEaseType::OutBack;
	if (v == "in_back") return CameraEaseType::InBack;
	if (v == "out_elastic") return CameraEaseType::OutElastic;
	if (v == "in_out_back") return CameraEaseType::InOutBack;
	return CameraEaseType::Linear;
}

CameraEaseSpec ModApiCameraControl::read_ease_spec(lua_State *L, int opts_index)
{
	CameraEaseSpec e;
	if (opts_index <= 0 || lua_isnil(L, opts_index) || !lua_istable(L, opts_index))
		return e;

	lua_getfield(L, opts_index, "ease");
	if (lua_istable(L, -1)) {
		lua_getfield(L, -1, "time");
		e.time = (f32)readParam<float>(L, -1, 0.0f);
		lua_pop(L, 1);
		lua_getfield(L, -1, "type");
		e.type = read_ease_type(L, -1);
		lua_pop(L, 1);
	}
	lua_pop(L, 1);
	if (e.time < 0.0f)
		e.time = 0.0f;
	return e;
}

bool ModApiCameraControl::read_bool_field(lua_State *L, int table_index, const char *name, bool def)
{
	if (table_index <= 0 || lua_isnil(L, table_index) || !lua_istable(L, table_index))
		return def;
	lua_getfield(L, table_index, name);
	bool v = lua_isnil(L, -1) ? def : readParam<bool>(L, -1, def);
	lua_pop(L, 1);
	return v;
}

f32 ModApiCameraControl::read_float_field(lua_State *L, int table_index, const char *name, f32 def)
{
	if (table_index <= 0 || lua_isnil(L, table_index) || !lua_istable(L, table_index))
		return def;
	lua_getfield(L, table_index, name);
	f32 v = lua_isnil(L, -1) ? def : (f32)readParam<float>(L, -1, def);
	lua_pop(L, 1);
	return v;
}

v3f ModApiCameraControl::read_v3f_field(lua_State *L, int table_index, const char *name, const v3f &def)
{
	if (table_index <= 0 || lua_isnil(L, table_index) || !lua_istable(L, table_index))
		return def;
	lua_getfield(L, table_index, name);
	v3f v = lua_istable(L, -1) ? check_v3f(L, -1) : def;
	lua_pop(L, 1);
	return v;
}

u32 ModApiCameraControl::read_color_argb(lua_State *L, int index)
{
	if (lua_isnumber(L, index))
		return (u32)lua_tointeger(L, index);
	if (!lua_istable(L, index))
		return 0xFF000000;
	lua_getfield(L, index, "a");
	u32 a = (u32)readParam<int>(L, -1, 255);
	lua_pop(L, 1);
	lua_getfield(L, index, "r");
	u32 r = (u32)readParam<int>(L, -1, 0);
	lua_pop(L, 1);
	lua_getfield(L, index, "g");
	u32 g = (u32)readParam<int>(L, -1, 0);
	lua_pop(L, 1);
	lua_getfield(L, index, "b");
	u32 b = (u32)readParam<int>(L, -1, 0);
	lua_pop(L, 1);
	a &= 0xFF; r &= 0xFF; g &= 0xFF; b &= 0xFF;
	return (a << 24) | (r << 16) | (g << 8) | b;
}

PlayerSAO *ModApiCameraControl::check_player_sao(lua_State *L, int index)
{
	luaL_checktype(L, index, LUA_TUSERDATA);
	ObjectRef *ref = (ObjectRef *)luaL_checkudata(L, index, "ObjectRef");
	ServerActiveObject *sao = ObjectRef::getobject(ref);
	if (!sao)
		luaL_error(L, "Invalid player");
	PlayerSAO *psao = dynamic_cast<PlayerSAO *>(sao);
	if (!psao)
		luaL_error(L, "Object is not a player");
	return psao;
}

u8 ModApiCameraControl::build_flags(const CameraControlState &st, bool reset)
{
	u8 flags = 0;
	if (reset) flags |= CAMFLAG_RESET;
	if (st.lock_perspective) flags |= CAMFLAG_LOCK_PERSPECTIVE;
	if (st.lock_input) flags |= CAMFLAG_LOCK_INPUT;
	if (st.detached) flags |= CAMFLAG_DETACHED;
	if (st.orbit) flags |= CAMFLAG_ORBIT;
	if (st.spectator) flags |= CAMFLAG_SPECTATOR;
	return flags;
}

void ModApiCameraControl::send_state(lua_State *L, PlayerSAO *psao, bool reset, u16 field_mask)
{
	Server *srv = getServer(L);
	RemotePlayer *rp = psao->getPlayer();
	if (!rp)
		return;
	u8 flags = build_flags(rp->camera_control, reset);
	srv->SendCameraControl(psao->getPeerID(), rp->camera_control, flags, field_mask);
}

// core.camera.set_pos(player, pos, opts)
int ModApiCameraControl::l_set_pos(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	v3f pos = check_v3f(L, 2);
	int opts = 3;
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.detached = true;
	st.has_pos = true;
	st.pos = pos;
	st.pos_ease = read_ease_spec(L, opts);
	st.lock_input = read_bool_field(L, opts, "lock_input", st.lock_input);
	send_state(L, psao, false, CAMCTRL_POS);
	return 0;
}

// core.camera.set_rot(player, rot, opts)
int ModApiCameraControl::l_set_rot(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	v3f rot = check_v3f(L, 2);
	int opts = 3;
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.has_rot = true;
	st.rot_deg = rot;
	st.rot_ease = read_ease_spec(L, opts);
	send_state(L, psao, false, CAMCTRL_ROT);
	return 0;
}

// core.camera.set_fov(player, fov, opts)
int ModApiCameraControl::l_set_fov(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	f32 fov = (f32)luaL_checknumber(L, 2);
	int opts = 3;
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.has_fov = true;
	st.fov_deg = fov;
	st.fov_ease = read_ease_spec(L, opts);
	send_state(L, psao, false, CAMCTRL_FOV);
	return 0;
}

// core.camera.set_tilt(player, tilt, opts)
int ModApiCameraControl::l_set_tilt(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	f32 tilt = (f32)luaL_checknumber(L, 2);
	int opts = 3;
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.has_tilt = true;
	st.tilt_deg = tilt;
	st.tilt_ease = read_ease_spec(L, opts);
	st.tilt_auto_return = read_bool_field(L, opts, "auto_return", false);
	send_state(L, psao, false, CAMCTRL_TILT);
	return 0;
}

// core.camera.set_offset(player, pos_offset, rot_offset, opts)
int ModApiCameraControl::l_set_offset(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	v3f pos_offset = check_v3f(L, 2);
	v3f rot_offset = check_v3f(L, 3);
	int opts = 4;
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.has_offset = true;
	st.pos_offset = pos_offset;
	st.rot_offset_deg = rot_offset;
	st.offset_ease = read_ease_spec(L, opts);
	send_state(L, psao, false, CAMCTRL_OFFSET);
	return 0;
}

// core.camera.set_third_person(player, distance, opts)
int ModApiCameraControl::l_set_third_person(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	f32 dist = (f32)luaL_checknumber(L, 2);
	int opts = 3;
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.has_third_person = true;
	st.third_person_distance = std::min(dist, 100.0f);
	st.third_person_ease = read_ease_spec(L, opts);
	send_state(L, psao, false, CAMCTRL_THIRD_PERSON);
	return 0;
}

// core.camera.detach(player, opts)
int ModApiCameraControl::l_detach(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.detached = true;
	st.orbit = false;
	st.spectator = false;
	send_state(L, psao, false, 0);
	return 0;
}

// core.camera.attach(player, opts)
int ModApiCameraControl::l_attach(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	int opts = 2;
	CameraEaseSpec e = read_ease_spec(L, opts);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.detached = false;
	st.orbit = false;
	st.spectator = false;
	st.lock_input = false;
	st.has_pos = false;
	st.pos_ease = e;
	st.has_rot = false;
	st.rot_ease = e;
	send_state(L, psao, false, CAMCTRL_POS | CAMCTRL_ROT);
	return 0;
}

// core.camera.set_orbit(player, opts)
int ModApiCameraControl::l_set_orbit(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.orbit = true;
	st.detached = false;
	st.spectator = false;

	CameraOrbitParams p;
	p.active = true;

	lua_getfield(L, 2, "target");
	if (lua_isnil(L, -1)) {
		p.target_type = 0;
	} else if (lua_istable(L, -1)) {
		p.target_type = 2;
		p.target_pos = check_v3f(L, -1);
	} else if (lua_isuserdata(L, -1)) {
		ObjectRef *tref = (ObjectRef *)luaL_checkudata(L, -1, "ObjectRef");
		ServerActiveObject *sao = ObjectRef::getobject(tref);
		if (sao && sao->getType() == ACTIVEOBJECT_TYPE_PLAYER) {
			p.target_type = 0;
		} else if (sao) {
			p.target_type = 1;
			p.target_object_id = sao->getId();
		}
	}
	lua_pop(L, 1);

	p.radius = read_float_field(L, 2, "radius", 0.0f);
	p.yaw_offset = read_float_field(L, 2, "yaw_offset", 0.0f);
	p.pitch_offset = read_float_field(L, 2, "pitch_offset", 0.0f);
	p.view_offset = read_v3f_field(L, 2, "view_offset", v3f());
	p.independent_look = read_bool_field(L, 2, "independent_look", false);

	st.orbit_params = p;
	send_state(L, psao, false, CAMCTRL_ORBIT);
	return 0;
}

// core.camera.set_spectator(player, opts)
int ModApiCameraControl::l_set_spectator(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st.spectator = true;
	st.detached = false;
	st.orbit = false;

	CameraSpectatorParams p;
	p.active = true;
	p.speed = read_float_field(L, 2, "speed", 10.0f);
	p.sprint_multiplier = read_float_field(L, 2, "sprint_multiplier", 2.0f);
	p.vertical = read_bool_field(L, 2, "vertical", true);
	st.spectator_params = p;

	send_state(L, psao, false, CAMCTRL_SPECTATOR);
	return 0;
}

// core.camera.shake(player, opts)
int ModApiCameraControl::l_shake(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;

	CameraShakeParams p;
	p.active = true;
	p.intensity = read_float_field(L, 2, "intensity", 0.0f);
	p.duration = read_float_field(L, 2, "duration", 0.0f);
	p.decay = read_bool_field(L, 2, "decay", true);

	u8 mask = 0;
	lua_getfield(L, 2, "axes");
	if (lua_istable(L, -1)) {
		lua_getfield(L, -1, "pitch"); if (readParam<bool>(L, -1, true)) mask |= 0x01; lua_pop(L, 1);
		lua_getfield(L, -1, "yaw"); if (readParam<bool>(L, -1, true)) mask |= 0x02; lua_pop(L, 1);
		lua_getfield(L, -1, "roll"); if (readParam<bool>(L, -1, true)) mask |= 0x04; lua_pop(L, 1);
	} else {
		mask = 0x07;
	}
	lua_pop(L, 1);
	p.axes_mask = mask;

	st.shake = p;
	send_state(L, psao, false, CAMCTRL_SHAKE);
	return 0;
}

// core.camera.fade(player, opts)
int ModApiCameraControl::l_fade(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;

	CameraFadeParams p;
	p.active = true;

	lua_getfield(L, 2, "color");
	p.color_argb = read_color_argb(L, -1);
	lua_pop(L, 1);
	p.fade_in = read_float_field(L, 2, "fade_in", 0.0f);
	p.hold = read_float_field(L, 2, "hold", 0.0f);
	p.fade_out = read_float_field(L, 2, "fade_out", 0.0f);

	st.fade = p;
	send_state(L, psao, false, CAMCTRL_FADE);

	// callback fired when hold phase starts (end of fade_in)
	lua_getfield(L, 2, "callback");
	if (lua_isfunction(L, -1) && p.fade_in > 0.0f) {
		lua_getglobal(L, "core");
		lua_getfield(L, -1, "after");
		lua_pushnumber(L, p.fade_in);
		lua_pushvalue(L, -4); // callback
		lua_call(L, 2, 0);
		lua_pop(L, 1); // core
	}
	lua_pop(L, 1); // callback
	return 0;
}

// core.camera.lock_perspective(player, bool)
int ModApiCameraControl::l_lock_perspective(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	bool v = readParam<bool>(L, 2);
	RemotePlayer *rp = psao->getPlayer();
	rp->camera_control.lock_perspective = v;
	send_state(L, psao, false, 0);
	return 0;
}

// core.camera.reset(player, opts)
int ModApiCameraControl::l_reset(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	int opts = 2;
	CameraEaseSpec e = read_ease_spec(L, opts);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	st = CameraControlState();
	st.pos_ease = e;
	st.rot_ease = e;
	st.fov_ease = e;
	st.tilt_ease = e;
	st.offset_ease = e;
	st.third_person_ease = e;

	send_state(L, psao, true,
		CAMCTRL_POS | CAMCTRL_ROT | CAMCTRL_FOV | CAMCTRL_TILT | CAMCTRL_OFFSET | CAMCTRL_THIRD_PERSON |
		CAMCTRL_ORBIT | CAMCTRL_SPECTATOR | CAMCTRL_SHAKE | CAMCTRL_FADE);
	return 0;
}

// core.camera.get_pos(player)
int ModApiCameraControl::l_get_pos(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	if (st.detached && st.has_pos) {
		push_v3f(L, st.pos);
		return 1;
	}
	push_v3f(L, psao->getBasePosition() / BS);
	return 1;
}

// core.camera.get_rot(player)
int ModApiCameraControl::l_get_rot(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	if (st.has_rot) {
		push_v3f(L, st.rot_deg);
		return 1;
	}
	push_v3f(L, v3f(psao->getLookPitch(), psao->getRotation().Y, 0.0f));
	return 1;
}

// core.camera.get_fov(player)
int ModApiCameraControl::l_get_fov(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	if (!st.has_fov)
		return 0;
	lua_pushnumber(L, st.fov_deg);
	return 1;
}

// core.camera.is_detached(player)
int ModApiCameraControl::l_is_detached(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	PlayerSAO *psao = check_player_sao(L, 1);
	RemotePlayer *rp = psao->getPlayer();
	CameraControlState &st = rp->camera_control;
	lua_pushboolean(L, st.detached || st.orbit || st.spectator);
	return 1;
}

static const luaL_Reg camera_funcs[] = {
	{"set_pos", ModApiCameraControl::l_set_pos},
	{"set_rot", ModApiCameraControl::l_set_rot},
	{"set_fov", ModApiCameraControl::l_set_fov},
	{"set_tilt", ModApiCameraControl::l_set_tilt},
	{"set_offset", ModApiCameraControl::l_set_offset},
	{"set_third_person", ModApiCameraControl::l_set_third_person},
	{"detach", ModApiCameraControl::l_detach},
	{"attach", ModApiCameraControl::l_attach},
	{"set_orbit", ModApiCameraControl::l_set_orbit},
	{"set_spectator", ModApiCameraControl::l_set_spectator},
	{"shake", ModApiCameraControl::l_shake},
	{"fade", ModApiCameraControl::l_fade},
	{"lock_perspective", ModApiCameraControl::l_lock_perspective},
	{"reset", ModApiCameraControl::l_reset},
	{"get_pos", ModApiCameraControl::l_get_pos},
	{"get_rot", ModApiCameraControl::l_get_rot},
	{"get_fov", ModApiCameraControl::l_get_fov},
	{"is_detached", ModApiCameraControl::l_is_detached},
	{nullptr, nullptr}
};

void ModApiCameraControl::Initialize(lua_State *L, int top)
{
	lua_getfield(L, top, "camera");
	if (lua_istable(L, -1)) {
		lua_pop(L, 1);
		return;
	}
	lua_pop(L, 1);

	lua_newtable(L);
	for (const auto *f = camera_funcs; f->name; f++) {
		lua_pushcfunction(L, f->func);
		lua_setfield(L, -2, f->name);
	}
	lua_setfield(L, top, "camera");
}
