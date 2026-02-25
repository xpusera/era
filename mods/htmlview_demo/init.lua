local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

local function is_android_htmlview()
	return type(htmlview) == "table" and type(htmlview.run) == "function"
end

local function msg(name, text)
	minetest.chat_send_player(name, "[htmlview_demo] " .. text)
end

local ids = {
	overlay = modname .. ":overlay",
	external = modname .. ":external",
	pipe_a = modname .. ":pipe_a",
	pipe_b = modname .. ":pipe_b",
	screen = modname .. ":screen",
}

local function get_ui_root()
	return minetest.get_modpath(modname) .. "/ui"
end

local screen_texname
if is_android_htmlview() and type(htmlview.texture_name) == "function" then
	screen_texname = htmlview.texture_name(ids.screen)
else
	screen_texname = "unknown.png"
end

minetest.register_node(modname .. ":screen", {
	description = S("HTMLView Screen (node texture)"),
	tiles = { screen_texname },
	drawtype = "nodebox",
	paramtype = "light",
	light_source = 4,
	groups = { cracky = 2, oddly_breakable_by_hand = 2 },
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5,  0.48,  0.5,  0.5,  0.5},
		},
	},
})

local overlay_html = [[
<!doctype html>
<html>
<body style="margin:0; font-family:sans-serif; background:rgba(0,0,0,0.35); color:white;">
  <div style="padding:12px; display:flex; flex-direction:column; gap:10px;">
    <div style="font-size:18px; font-weight:800;">HTMLView internal</div>
    <button style="padding:12px; font-size:16px;" onclick="luanti.send('overlay:flash')">flash external</button>
    <button style="padding:12px; font-size:16px;" onclick="luanti.send('overlay:capture')">capture external</button>
    <button style="padding:12px; font-size:16px;" onclick="luanti.send('overlay:hide')">hide</button>
  </div>
</body>
</html>
]]

local function start_overlay(name)
	htmlview.run(ids.overlay, overlay_html)
	htmlview.display(ids.overlay, {
		visible = true,
		x = 30,
		y = 80,
		width = 420,
		height = 240,
		safe_area = true,
		drag_embed = true,
		border_radius = 20,
	})
	msg(name, "overlay started")
end

local function start_external(name)
	local root = get_ui_root()
	htmlview.run_external(ids.external, root, "index.html")
	htmlview.display(ids.external, {
		visible = true,
		x = "center",
		y = "center",
		width = 740,
		height = 520,
		safe_area = true,
		drag_embed = true,
		border_radius = 24,
	})
	msg(name, "external started (" .. root .. ")")
end

local function start_pipe(name)
	local html_a = [[
<!doctype html><html><body style="margin:0;background:rgba(30,30,30,.55);display:flex;align-items:center;justify-content:center;height:100%;">
<button style="padding:14px;font-size:16px;" onclick="luanti.send('pipe:color')">send to view B</button>
</body></html>
]]
	local html_b = [[
<!doctype html><html><body id="b" style="margin:0;background:rgba(0,0,0,.35);display:flex;align-items:center;justify-content:center;height:100%;color:white;font-family:sans-serif;">
<div>view B (wait msg)</div>
<script>
luanti.on_message(function(m){
  if(m==='pipe:color'){
    document.getElementById('b').style.background = 'rgba(0,140,255,.25)';
  }
});
</script>
</body></html>
]]
	htmlview.run(ids.pipe_a, html_a)
	htmlview.run(ids.pipe_b, html_b)
	htmlview.pipe(ids.pipe_a, ids.pipe_b)
	htmlview.display(ids.pipe_a, { visible=true, x=30, y=350, width=260, height=120, safe_area=true, drag_embed=true, border_radius=16 })
	htmlview.display(ids.pipe_b, { visible=true, x=310, y=350, width=260, height=120, safe_area=true, drag_embed=true, border_radius=16 })
	msg(name, "pipe demo started")
end

local function start_node_texture(name)
	start_external(name)
	if type(htmlview.bind_texture) ~= "function" then
		msg(name, "bind_texture not available")
		return
	end
	htmlview.bind_texture(ids.external, screen_texname, { width = 256, height = 256, fps = 10 })
	msg(name, "node texture binding started: " .. screen_texname .. " (place node " .. modname .. ":screen)")
end

local function stop_all(name)
	for _, id in pairs(ids) do
		pcall(function() htmlview.stop(id) end)
		pcall(function() htmlview.unbind_texture(id) end)
	end
	msg(name, "stopped")
end

local hud_by_player = {}

if is_android_htmlview() and type(htmlview.on_capture) == "function" then
	htmlview.on_capture(ids.external, function(png)
		for _, player in ipairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			local filename = modname .. "_capture_" .. pname .. ".png"
			minetest.dynamic_add_media({
				filename = filename,
				filedata = png,
				to_player = pname,
				ephemeral = true,
				client_cache = false,
			}, function()
				local hudid = hud_by_player[pname]
				if hudid then
					player:hud_change(hudid, "text", filename)
				else
					hud_by_player[pname] = player:hud_add({
						hud_elem_type = "image",
						text = filename,
						position = {x=0.02, y=0.20},
						offset = {x=0, y=0},
						scale = {x=2, y=2},
						alignment = {x=1, y=1},
					})
				end
				msg(pname, "capture received -> hud image updated")
			end)
		end
	end)
end

if is_android_htmlview() and type(htmlview.on_message) == "function" then
	htmlview.on_message(ids.overlay, function(m)
		if m == "overlay:hide" then
			htmlview.display(ids.overlay, { visible = false, x=0, y=0, width=1, height=1 })
			return
		end
		if m == "overlay:flash" then
			htmlview.send(ids.external, "flash")
			return
		end
		if m == "overlay:capture" then
			htmlview.capture(ids.external, { width = 256, height = 256 })
			return
		end
	end)

	htmlview.on_message(ids.external, function(m)
		if m == "ping" then
			htmlview.send(ids.external, "pong from lua")
			return
		end
		if m == "capture" then
			htmlview.capture(ids.external, { width = 256, height = 256 })
			return
		end
		if m == "other:hi" then
			minetest.chat_send_all("[htmlview_demo] external navigated other page says hi")
			return
		end
		minetest.chat_send_all("[htmlview_demo] msg: " .. m)
	end)
end

minetest.register_chatcommand("htmlview_demo", {
	params = "overlay | external | pipe | node | stop",
	description = "HTMLView demo commands",
	privs = { interact = true },
	func = function(name, param)
		if not is_android_htmlview() then
			msg(name, "htmlview is Android-only")
			return
		end
		param = (param or ""):trim()
		if param == "overlay" then
			start_overlay(name)
			return
		end
		if param == "external" then
			start_external(name)
			return
		end
		if param == "pipe" then
			start_pipe(name)
			return
		end
		if param == "node" then
			start_node_texture(name)
			return
		end
		if param == "stop" then
			stop_all(name)
			return
		end
		msg(name, "usage: /htmlview_demo overlay|external|pipe|node|stop")
	end,
})
