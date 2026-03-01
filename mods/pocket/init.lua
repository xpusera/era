local pocket = {}

local registered_dimensions = {}
local saved_states = {}
local ambient_handles = {}

local function file_exists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

local function get_pname(player)
	return player and player:get_player_name()
end

function pocket.register(name, def)
	if type(name) ~= "string" or name == "" then
		error("pocket.register: name must be a non-empty string")
	end
	if name == "main" then
		error("pocket.register: name must not be 'main'")
	end
	if type(def) ~= "table" then
		error("pocket.register: def must be a table")
	end
	if registered_dimensions[name] then
		error("pocket.register: dimension already registered: " .. name)
	end
	registered_dimensions[name] = def
end

function pocket.get_def(name)
	return registered_dimensions[name]
end

function pocket.get_dimensions()
	local out = {}
	for name in pairs(registered_dimensions) do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

function pocket.get_layer(player)
	if not player then
		return "main"
	end
	local layer = player:get_layer()
	if type(layer) ~= "string" or layer == "" then
		return "main"
	end
	return layer
end

function pocket.is_in_pocket(player)
	return pocket.get_layer(player) ~= "main"
end

function pocket.get_players(layer)
	local out = {}
	for _, player in ipairs(minetest.get_connected_players()) do
		if pocket.get_layer(player) == layer then
			table.insert(out, player)
		end
	end
	return out
end

function pocket.broadcast(layer, message)
	for _, player in ipairs(pocket.get_players(layer)) do
		minetest.chat_send_player(player:get_player_name(), message)
	end
end

function pocket.set_node(pos, node, layer)
	return minetest.layer_set_node(pos, node, layer)
end

function pocket.get_node(pos, layer)
	return minetest.layer_get_node(pos, layer)
end

function pocket.remove_node(pos, layer)
	return minetest.layer_remove_node(pos, layer)
end

local function stop_ambient(pname)
	local handle = ambient_handles[pname]
	if handle then
		minetest.sound_stop(handle)
		ambient_handles[pname] = nil
	end
end

function pocket.enter(player, dimension_name)
	local def = registered_dimensions[dimension_name]
	if not def then
		return false, "dimension not found"
	end

	local pname = get_pname(player)
	if not pname then
		return false, "invalid player"
	end

	local state = {
		layer = pocket.get_layer(player),
		sky = player:get_sky(true),
		sun = player:get_sun(),
		moon = player:get_moon(),
		stars = player:get_stars(),
		physics = player:get_physics_override(),
		lighting = player:get_lighting(),
		pos = player:get_pos(),
	}
	saved_states[pname] = state

	stop_ambient(pname)

	player:set_layer(dimension_name)

	if def.sky then player:set_sky(def.sky) end
	if def.sun then player:set_sun(def.sun) end
	if def.moon then player:set_moon(def.moon) end
	if def.stars then player:set_stars(def.stars) end
	if def.physics then player:set_physics_override(def.physics) end
	if def.lighting then player:set_lighting(def.lighting) end

	if def.sounds and def.sounds.enter then
		minetest.sound_play(def.sounds.enter, {to_player = pname})
	end
	if def.sounds and def.sounds.ambient then
		ambient_handles[pname] = minetest.sound_play(def.sounds.ambient, {
			to_player = pname,
			loop = true,
			gain = 0.5,
		})
	end

	if type(def.on_enter) == "function" then
		def.on_enter(player)
	end

	return true
end

function pocket.leave(player)
	local pname = get_pname(player)
	if not pname then
		return false, "invalid player"
	end

	local old_layer = pocket.get_layer(player)
	local old_def = registered_dimensions[old_layer]
	local state = saved_states[pname]

	stop_ambient(pname)

	player:set_layer("main")

	if state and type(state.sky) == "table" then
		player:set_sky(state.sky)
	else
		player:set_sky()
	end

	if state and type(state.sun) == "table" then player:set_sun(state.sun) else player:set_sun() end
	if state and type(state.moon) == "table" then player:set_moon(state.moon) else player:set_moon() end
	if state and type(state.stars) == "table" then player:set_stars(state.stars) else player:set_stars() end
	if state and type(state.physics) == "table" then player:set_physics_override(state.physics) else player:set_physics_override({gravity = 1, speed = 1, jump = 1}) end
	if state and type(state.lighting) == "table" then player:set_lighting(state.lighting) else player:set_lighting({}) end

	saved_states[pname] = nil

	if old_def and type(old_def.on_leave) == "function" then
		old_def.on_leave(player)
	end

	return true
end

minetest.register_on_leaveplayer(function(player)
	local pname = get_pname(player)
	if not pname then
		return
	end
	stop_ambient(pname)
	saved_states[pname] = nil
end)

minetest.register_on_joinplayer(function(player)
	local pname = get_pname(player)
	if not pname then
		return
	end
	stop_ambient(pname)
	saved_states[pname] = nil
	player:set_layer("main")
end)

minetest.register_on_generated(function(minp, maxp, blockseed)
	for dim_name, def in pairs(registered_dimensions) do
		local mg = def.mapgen
		if mg and type(mg.on_chunk) == "function" then
			mg.on_chunk(minp, maxp, blockseed, dim_name)
		end
	end
end)

minetest.after(0, function()
	for _, modname in ipairs(minetest.get_modnames()) do
		local mod_path = minetest.get_modpath(modname)
		if mod_path then
			local dims_root = mod_path .. "/dimensions"
			local dims = minetest.get_dir_list(dims_root, true)
			if type(dims) == "table" then
				table.sort(dims)
				for _, dimname in ipairs(dims) do
					local init = dims_root .. "/" .. dimname .. "/init.lua"
					if file_exists(init) then
						minetest.log("action", "[pocket] loading: " .. modname .. ":" .. dimname)
						dofile(init)
					end
				end
			end
		end
	end
end)

_G.pocket = pocket
