// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "cpp_api/s_htmlview.h"

#include "cpp_api/s_internal.h"

#include "util/base64.h"

static constexpr const char *HTMLVIEW_CALLBACKS_RKEY = "HTMLVIEW_CALLBACKS";
static constexpr const char *HTMLVIEW_CAPTURE_CALLBACKS_RKEY = "HTMLVIEW_CAPTURE_CALLBACKS";

void ScriptApiHTMLView::on_htmlview_message(const std::string &id, const std::string &message)
{
	SCRIPTAPI_PRECHECKHEADER

	int error_handler = PUSH_ERROR_HANDLER(L);

	lua_getfield(L, LUA_REGISTRYINDEX, HTMLVIEW_CALLBACKS_RKEY);
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		lua_remove(L, error_handler);
		return;
	}

	lua_pushlstring(L, id.c_str(), id.size());
	lua_gettable(L, -2);
	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 2);
		lua_remove(L, error_handler);
		return;
	}

	lua_pushlstring(L, message.c_str(), message.size());
	PCALL_RES(lua_pcall(L, 1, 0, error_handler));

	lua_pop(L, 1); // callback table
	lua_remove(L, error_handler);
}

void ScriptApiHTMLView::on_htmlview_capture(const std::string &id, const std::string &png_base64)
{
	SCRIPTAPI_PRECHECKHEADER

	if (!base64_is_valid(png_base64))
		return;
	std::string png = base64_decode(png_base64);

	int error_handler = PUSH_ERROR_HANDLER(L);

	lua_getfield(L, LUA_REGISTRYINDEX, HTMLVIEW_CAPTURE_CALLBACKS_RKEY);
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		lua_remove(L, error_handler);
		return;
	}

	lua_pushlstring(L, id.c_str(), id.size());
	lua_gettable(L, -2);
	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 2);
		lua_remove(L, error_handler);
		return;
	}

	lua_pushlstring(L, png.data(), png.size());
	PCALL_RES(lua_pcall(L, 1, 0, error_handler));

	lua_pop(L, 1); // callback table
	lua_remove(L, error_handler);
}
