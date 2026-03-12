local cam = rawget(core, "camera")
if type(cam) ~= "table" then
	return
end

if type(cam._set) ~= "function" or type(cam._clear) ~= "function" or
		type(cam._shake) ~= "function" or type(cam._fade) ~= "function" then
	return
end

local raw_set = cam._set
local raw_clear = cam._clear
local raw_shake = cam._shake
local raw_fade = cam._fade

function cam.set(player, preset, opts)
	return raw_set(player, preset, opts)
end

function cam.clear(player, opts)
	return raw_clear(player, opts)
end

function cam.shake(player, opts)
	return raw_shake(player, opts)
end

function cam.fade(player, opts)
	if type(opts) ~= "table" then
		return raw_fade(player, opts)
	end

	local cb = opts.callback
	local fade_in = tonumber(opts.fade_in) or 0

	if type(cb) == "function" then
		local pname = player
		if type(player) ~= "string" and player and player.get_player_name then
			pname = player:get_player_name()
		end
		core.after(fade_in, function()
			if type(pname) == "string" and pname ~= "" and core.get_player_by_name(pname) == nil then
				return
			end
			cb()
		end)
	end

	if opts.callback ~= nil then
		local t = {}
		for k, v in pairs(opts) do
			if k ~= "callback" then
				t[k] = v
			end
		end
		return raw_fade(player, t)
	end

	return raw_fade(player, opts)
end

