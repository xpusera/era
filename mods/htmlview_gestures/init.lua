local modname = minetest.get_current_modname()
local ids = {
	overlay = modname .. ":overlay",
}

local function is_android_htmlview()
	return type(htmlview) == "table" and type(htmlview.run_external) == "function"
end

local function ui_root()
	return minetest.get_modpath(modname) .. "/ui"
end

local function start_overlay(name)
	htmlview.run_external(ids.overlay, ui_root(), "overlay.html")
	htmlview.display(ids.overlay, {
		visible = true,
		fullscreen = true,
		safe_area = false,
		drag_embed = false,
		border_radius = 0,
	})
	minetest.chat_send_player(name, "[htmlview_gestures] overlay enabled")
end

local function stop_overlay(name)
	pcall(function() htmlview.stop(ids.overlay) end)
	minetest.chat_send_player(name, "[htmlview_gestures] overlay disabled")
end

if is_android_htmlview() then
	htmlview.on_message(ids.overlay, function(msg)
		local t = minetest.parse_json(msg)
		if type(t) ~= "table" or type(t.type) ~= "string" then
			return
		end
		if t.type == "pinch" then
			minetest.chat_send_all("[gesture] pinch scale=" .. tostring(t.scale))
			return
		end
		if t.type == "swipe3" then
			minetest.chat_send_all("[gesture] 3-finger swipe dx=" .. tostring(t.dx) .. " dy=" .. tostring(t.dy))
			return
		end
	end)
end

minetest.register_chatcommand("gestures", {
	params = "on | off",
	description = "Toggle transparent gesture overlay (Android)",
	privs = { interact = true },
	func = function(name, param)
		if not is_android_htmlview() then
			return false, "htmlview is Android-only"
		end
		param = (param or ""):trim()
		if param == "on" then
			start_overlay(name)
			return true
		end
		if param == "off" then
			stop_overlay(name)
			return true
		end
		return false, "Usage: /gestures on|off"
	end,
})
