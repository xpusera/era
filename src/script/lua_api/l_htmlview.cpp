// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_htmlview.h"

#include "common/c_converter.h"
#include "lua_api/l_internal.h"
#include "cpp_api/s_security.h"

#ifdef __ANDROID__
#include "htmlview_jni.h"
#include <cctype>
#include <limits>
#endif

static constexpr const char *HTMLVIEW_CALLBACKS_RKEY = "HTMLVIEW_CALLBACKS";

#ifdef __ANDROID__
static constexpr int CENTER_SENTINEL = std::numeric_limits<int>::min();

static bool isStringEqCI(lua_State *L, int idx, const char *s)
{
	if (!lua_isstring(L, idx))
		return false;
	const char *vv = lua_tostring(L, idx);
	if (!vv)
		return false;
	std::string v(vv);
	for (auto &c : v)
		c = (char)std::tolower((unsigned char)c);
	std::string ss(s);
	for (auto &c : ss)
		c = (char)std::tolower((unsigned char)c);
	return v == ss;
}
#endif

int ModApiHTMLView::l_run(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string html = readParam<std::string>(L, 2);

#ifdef __ANDROID__
	htmlview_jni_run(id, html);
	return 0;
#else
	return luaL_error(L, "htmlview is only available on Android");
#endif
}

int ModApiHTMLView::l_run_external(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string root_dir = readParam<std::string>(L, 2);
	std::string entry = "index.html";
	if (!lua_isnoneornil(L, 3))
		entry = readParam<std::string>(L, 3);

#ifdef __ANDROID__
	CHECK_SECURE_PATH(L, root_dir.c_str(), false);
	htmlview_jni_run_external(id, root_dir, entry);
	return 0;
#else
	return luaL_error(L, "htmlview is only available on Android");
#endif
}

int ModApiHTMLView::l_stop(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);

#ifdef __ANDROID__
	htmlview_jni_stop(id);
	return 0;
#else
	return luaL_error(L, "htmlview is only available on Android");
#endif
}

int ModApiHTMLView::l_display(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);

#ifdef __ANDROID__
	bool visible = getboolfield_default(L, 2, "visible", true);
	bool safe_area = getboolfield_default(L, 2, "safe_area", true);
	bool fullscreen = getboolfield_default(L, 2, "fullscreen", false);
	bool drag_embed = getboolfield_default(L, 2, "drag_embed", false);
	if (!drag_embed)
		drag_embed = getboolfield_default(L, 2, "draggable", false);
	float border_radius = getfloatfield_default(L, 2, "border_radius", 0.0f);
	if (border_radius < 0.0f)
		border_radius = 0.0f;

	int x = 0;
	int y = 0;
	int w = 1;
	int h = 1;

	lua_getfield(L, 2, "x");
	if (lua_isnumber(L, -1))
		x = (int)lua_tointeger(L, -1);
	else if (isStringEqCI(L, -1, "center"))
		x = CENTER_SENTINEL;
	lua_pop(L, 1);

	lua_getfield(L, 2, "y");
	if (lua_isnumber(L, -1))
		y = (int)lua_tointeger(L, -1);
	else if (isStringEqCI(L, -1, "center"))
		y = CENTER_SENTINEL;
	lua_pop(L, 1);

	lua_getfield(L, 2, "width");
	if (lua_isnumber(L, -1))
		w = (int)lua_tointeger(L, -1);
	else if (isStringEqCI(L, -1, "fullscreen"))
		fullscreen = true;
	lua_pop(L, 1);

	lua_getfield(L, 2, "height");
	if (lua_isnumber(L, -1))
		h = (int)lua_tointeger(L, -1);
	else if (isStringEqCI(L, -1, "fullscreen"))
		fullscreen = true;
	lua_pop(L, 1);

	htmlview_jni_display(id, x, y, w, h, visible, fullscreen, safe_area,
		drag_embed, border_radius);
	return 0;
#else
	return luaL_error(L, "htmlview is only available on Android");
#endif
}

int ModApiHTMLView::l_send(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string message = readParam<std::string>(L, 2);

#ifdef __ANDROID__
	htmlview_jni_send(id, message);
	return 0;
#else
	return luaL_error(L, "htmlview is only available on Android");
#endif
}

int ModApiHTMLView::l_navigate(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string url = readParam<std::string>(L, 2);

#ifdef __ANDROID__
	htmlview_jni_navigate(id, url);
	return 0;
#else
	return luaL_error(L, "htmlview is only available on Android");
#endif
}

int ModApiHTMLView::l_inject(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	std::string js = readParam<std::string>(L, 2);

#ifdef __ANDROID__
	htmlview_jni_inject(id, js);
	return 0;
#else
	return luaL_error(L, "htmlview is only available on Android");
#endif
}

int ModApiHTMLView::l_pipe(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string from_id = readParam<std::string>(L, 1);
	std::string to_id = readParam<std::string>(L, 2);

#ifdef __ANDROID__
	htmlview_jni_pipe(from_id, to_id);
	return 0;
#else
	return luaL_error(L, "htmlview is only available on Android");
#endif
}

int ModApiHTMLView::l_on_message(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string id = readParam<std::string>(L, 1);
	bool clear = lua_isnil(L, 2);
	if (!clear)
		luaL_checktype(L, 2, LUA_TFUNCTION);

	lua_getfield(L, LUA_REGISTRYINDEX, HTMLVIEW_CALLBACKS_RKEY);
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		lua_newtable(L);
		lua_pushvalue(L, -1);
		lua_setfield(L, LUA_REGISTRYINDEX, HTMLVIEW_CALLBACKS_RKEY);
	}

	lua_pushlstring(L, id.c_str(), id.size());
	if (clear)
		lua_pushnil(L);
	else
		lua_pushvalue(L, 2);
	lua_settable(L, -3);

	lua_pop(L, 1);
	return 0;
}

void ModApiHTMLView::Initialize(lua_State *L, int top)
{
#ifdef __ANDROID__
	lua_newtable(L);
	int tbl = lua_gettop(L);

	registerFunction(L, "run", l_run, tbl);
	registerFunction(L, "run_external", l_run_external, tbl);
	registerFunction(L, "stop", l_stop, tbl);
	registerFunction(L, "display", l_display, tbl);
	registerFunction(L, "send", l_send, tbl);
	registerFunction(L, "navigate", l_navigate, tbl);
	registerFunction(L, "inject", l_inject, tbl);
	registerFunction(L, "pipe", l_pipe, tbl);
	registerFunction(L, "on_message", l_on_message, tbl);

	lua_pushvalue(L, tbl);
	lua_setglobal(L, "htmlview");
	lua_setfield(L, top, "htmlview");
#else
	(void)L;
	(void)top;
#endif
}
