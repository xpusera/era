// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>

#pragma once
#include "irrlichttypes.h"
#include "cpp_api/s_base.h"
#include "cpp_api/s_entity.h"
#include "cpp_api/s_env.h"
#include "cpp_api/s_inventory.h"
#include "cpp_api/s_modchannels.h"
#include "cpp_api/s_htmlview.h"
#include "cpp_api/s_node.h"
#include "cpp_api/s_player.h"
#include "cpp_api/s_server.h"
#include "cpp_api/s_security.h"
#include "cpp_api/s_async.h"

struct PackedValue;
struct ParticleParameters;

/*****************************************************************************/
/* Scripting <-> Server Game Interface                                       */
/*****************************************************************************/

class ServerScripting:
		virtual public ScriptApiBase,
		public ScriptApiAsync,
		public ScriptApiDetached,
		public ScriptApiEntity,
		public ScriptApiEnv,
		public ScriptApiHTMLView,
		public ScriptApiModChannels,
		public ScriptApiNode,
		public ScriptApiPlayer,
		public ScriptApiServer,
		public ScriptApiSecurity
{
public:
		ServerScripting(Server* server);

		void unrefParticleSpawnCallback(int ref);
		bool runParticleSpawnCallback(int ref, u32 index, ParticleParameters &pp,
				const std::string &origin_mod);

		void unrefParticleCollideCallback(int ref);
		bool runParticleCollideCallback(int ref, const v3f &pos, const v3f &normal,
				const std::string &origin_mod);

	void loadBuiltin();
	// use ScriptApiBase::loadMod() to load mods

	// Save globals that are copied into other Lua envs
	void saveGlobals();

	// Initialize async engine, call this AFTER loading all mods
	void initAsync() override;

protected:
	// from ScriptApiSecurity:
	bool checkPathInternal(const std::string &abs_path, bool write_required,
		bool *write_allowed) override {
		return ScriptApiSecurity::checkPathWithGamedef(getStack(),
			abs_path, write_required, write_allowed);
	}
	bool modNamesAreTrusted() override { return true; }

private:
	void InitializeModApi(lua_State *L, int top);

	static void InitializeAsync(lua_State *L, int top);
};
