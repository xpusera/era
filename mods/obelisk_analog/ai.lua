local oh = obelisk_analog

local function get_http()
	if type(minetest.request_http_api) ~= "function" then
		return nil
	end
	local ok, http = pcall(minetest.request_http_api)
	if ok then
		return http
	end
	return nil
end

local function get_setting(k)
	if minetest.settings and minetest.settings.get then
		return minetest.settings:get(k)
	end
	return nil
end

local function get_key()
	local k = get_setting("obelisk_openrouter_api_key")
	if k and k ~= "" then
		return k
	end
	return nil
end

local function safe_parse_json(s)
	if type(s) ~= "string" then
		return nil
	end
	local ok, obj = pcall(minetest.parse_json, s)
	if ok then
		return obj
	end
	return nil
end

local function extract_json(s)
	if type(s) ~= "string" then
		return nil
	end
	local a = s:find("{", 1, true)
	local b = s:match(".*()}")
	if not a or not b or b < a then
		return nil
	end
	return s:sub(a, b)
end

oh.ai_state = {
	enabled = true,
	pending = false,
	t = 0,
	interval = 18,
	last = nil,
	last_at = 0,
}

function oh.ai_enabled()
	if not oh.ai_state.enabled then
		return false
	end
	if oh.html_state and oh.html_state.ai_mode == "entities" then
		return false
	end
	return true
end

local function build_context(player, entity)
	local ppos = player and player:get_pos() or nil
	local epos = entity and entity:get_pos() or nil
	local dist = nil
	if ppos and epos then
		dist = vector.distance(ppos, epos)
	end
	local ctx = {
		timeofday = minetest.get_timeofday(),
		is_night = oh.is_night and oh.is_night() or false,
		phase = oh.current_phase or 1,
		player = {
			name = player and player:get_player_name() or "",
			pos = ppos,
			light = ppos and minetest.get_node_light(ppos, nil) or nil,
			voice_level = oh.html_state and oh.html_state.voice_level or 0,
			voice_loud = oh.html_state and oh.html_state.voice_loud or false,
		},
		entity = {
			active = oh.entity_active or false,
			pos = epos,
			distance = dist,
		},
	}
	return ctx
end

local function build_prompt(ctx)
	return {
		{
			role = "system",
			content = "You are a horror director controlling an entity in a game. Output STRICT JSON ONLY. No prose. Decide subtle actions to create tension without being unfair. Never spawn during day unless the player is in a dark cave. Prefer stalking and audio mimic over instant kills. Allowed actions: whisper, mimic, speed, ability. JSON schema: {action:string, whisper?:string, mimic?:{style:string}, speed_mult?:number, ability?:string}. action can be 'none'. ability can be one of: teleport, invisibility, speed_change, torch_destroy, light_flicker, jumpscare, window_peek, corner_watch, ceiling_hang, wall_phase.",
		},
		{
			role = "user",
			content = minetest.write_json(ctx),
		},
	}
end

local function apply_decision(player, entity, decision)
	if not decision or type(decision) ~= "table" then
		return
	end

	if decision.whisper and player then
		oh.send_whisper(player, tostring(decision.whisper))
	end

	if decision.mimic and type(decision.mimic) == "table" then
		local style = tostring(decision.mimic.style or "normal")
		local dist = nil
		if entity and player then
			local ppos = player:get_pos()
			local epos = entity:get_pos()
			if ppos and epos then
				dist = vector.distance(ppos, epos)
			end
		end
		oh.html_mimic(style, dist)
	end

	if decision.speed_mult and entity then
		local lua = entity:get_luaentity()
		if lua and lua.base_speed then
			local m = tonumber(decision.speed_mult)
			if m and m > 0.2 and m < 4.0 then
				lua.base_speed = lua.base_speed * m
				lua.current_speed = lua.base_speed
			end
		end
	end

	if decision.ability and entity and player then
		local lua = entity:get_luaentity()
		local dist = nil
		local ppos = player:get_pos()
		local epos = entity:get_pos()
		if ppos and epos then
			dist = vector.distance(ppos, epos)
		end
		if lua and dist then
			local a = tostring(decision.ability)
			local fn = lua["ability_" .. a]
			if type(fn) == "function" then
				pcall(fn, lua, player, dist)
			end
		end
	end
end

function oh.ai_step(dtime)
	if not oh.ai_enabled() then
		return
	end
	local http = get_http()
	local key = get_key()
	if not http or not key then
		return
	end

	oh.ai_state.t = oh.ai_state.t + dtime
	if oh.ai_state.pending then
		return
	end
	if oh.ai_state.t < oh.ai_state.interval then
		return
	end
	oh.ai_state.t = 0

	local player = oh.get_random_player and oh.get_random_player() or nil
	if not player then
		return
	end

	local ctx = build_context(player, oh.current_entity)
	if not ctx.is_night then
		local light = ctx.player.light or 15
		if light >= 4 then
			return
		end
	end

	local body = {
		model = get_setting("obelisk_openrouter_model") or "openrouter/free",
		messages = build_prompt(ctx),
		temperature = 0.7,
		max_tokens = 160,
	}

	oh.ai_state.pending = true
	http.fetch({
		url = get_setting("obelisk_openrouter_endpoint") or "https://openrouter.ai/api/v1/chat/completions",
		timeout = 10,
		extra_headers = {
			"Content-Type: application/json",
			"Authorization: Bearer " .. key,
			"HTTP-Referer: https://github.com/xpusera/era",
			"X-Title: Obelisk Analog",
		},
		post_data = minetest.write_json(body),
	}, function(res)
		oh.ai_state.pending = false
		if not res or not res.succeeded or type(res.data) ~= "string" then
			return
		end
		local obj = safe_parse_json(res.data)
		local content = obj and obj.choices and obj.choices[1] and obj.choices[1].message and obj.choices[1].message.content
		if type(content) ~= "string" then
			return
		end
		local js = extract_json(content) or content
		local decision = safe_parse_json(js)
		if type(decision) ~= "table" then
			return
		end
		oh.ai_state.last = decision
		oh.ai_state.last_at = minetest.get_gametime()
		apply_decision(player, oh.current_entity, decision)
	end)
end

minetest.register_chatcommand("obelisk_ai", {
	privs = {server = true},
	description = "Toggle Obelisk AI director (on/off)",
	func = function(name, param)
		param = (param or ""):lower()
		if param == "on" then
			oh.ai_state.enabled = true
			if oh.html_set_mode then
				oh.html_set_mode("ai")
			end
			return true, "AI director enabled"
		elseif param == "off" then
			oh.ai_state.enabled = false
			if oh.html_set_mode then
				oh.html_set_mode("entities")
			end
			return true, "AI director disabled"
		end
		return true, "Usage: /obelisk_ai on|off"
	end,
})
