local modname = minetest.get_current_modname()

local function msg(name, text)
	minetest.chat_send_player(name, "[fork_api_demo] " .. text)
end

local function get_player(name)
	local player = minetest.get_player_by_name(name)
	if not player then
		return nil
	end
	return player
end

local function has_camera_api()
	return type(minetest.camera) == "table" and type(minetest.camera.set) == "function"
end

local function has_fog_api()
	return type(minetest.set_fog) == "function"
end

local function has_sky_keyframes_api()
	return type(minetest.set_sky_keyframes) == "function"
end

local freecam = {}

local function freecam_set_physics(player, enabled)
	if not player or not player:is_player() then
		return
	end
	if enabled then
		player:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
	else
		player:set_physics_override({ speed = 1, jump = 1, gravity = 1 })
	end
end

local function freecam_stop(player)
	if not player then
		return
	end
	local name = player:get_player_name()
	if not name then
		return
	end
	freecam[name] = nil
	freecam_set_physics(player, false)
	if has_camera_api() then
		minetest.camera.clear(player, { ease = { time = 0.20, type = "in_cubic" } })
	end
end

minetest.register_on_leaveplayer(function(player)
	freecam_stop(player)
end)

minetest.register_globalstep(function(dtime)
	if not has_camera_api() then
		return
	end
	for name, st in pairs(freecam) do
		local player = minetest.get_player_by_name(name)
		if not player then
			freecam[name] = nil
			break
		end

		local yaw = player:get_look_horizontal() or 0
		local pitch = player:get_look_vertical() or 0

		local ctrl = player:get_player_control() or {}
		local speed = 8.0
		if ctrl.aux1 then
			speed = speed * 2.5
		end

		local fwd = minetest.yaw_to_dir(yaw)
		fwd.y = 0
		fwd = vector.normalize(fwd)
		local right = vector.cross(vector.new(0, 1, 0), fwd)
		right.y = 0
		right = vector.normalize(right)

		local move = vector.new(0, 0, 0)
		if ctrl.up then
			move = vector.add(move, fwd)
		end
		if ctrl.down then
			move = vector.subtract(move, fwd)
		end
		if ctrl.right then
			move = vector.add(move, right)
		end
		if ctrl.left then
			move = vector.subtract(move, right)
		end
		if ctrl.jump then
			move.y = move.y + 1
		end
		if ctrl.sneak then
			move.y = move.y - 1
		end
		if vector.length(move) > 0 then
			st.pos = vector.add(st.pos, vector.multiply(vector.normalize(move), speed * dtime))
		end

		st.send_acc = (st.send_acc or 0) + dtime
		if st.send_acc >= 0.05 then
			st.send_acc = 0
			minetest.camera.set(player, "free", {
				pos = st.pos,
				rot = {
					x = math.deg(pitch),
					y = math.deg(yaw),
					z = 0,
				},
				lock_input = false,
			})
		end
	end
end)

local function add_muzzle_like_spawner(attached_obj)
	return minetest.add_particlespawner({
		amount = 40,
		time = 0.25,
		attached = {
			object = attached_obj,
			bone = "Arm_Right",
			offset = vector.new(0.3, 1.3, 0.2),
		},
		minpos = vector.new(0, 0, 0),
		maxpos = vector.new(0, 0, 0),
		minvel = vector.new(-0.4, 0.8, -0.4),
		maxvel = vector.new(0.4, 1.8, 0.4),
		minacc = vector.new(0, -4.0, 0),
		maxacc = vector.new(0, -8.0, 0),
		minexptime = 0.12,
		maxexptime = 0.28,
		minsize = 0.25,
		maxsize = 0.60,
		collisiondetection = false,
		glow = 8,
		texture = "smoke_puff.png",
		face_camera = "rotate_y",
		color_over_lifetime = {
			{ t = 0.0, color = "#FFFFFFAA" },
			{ t = 0.4, color = "#FFAA00AA" },
			{ t = 1.0, color = "#FF440000" },
		},
	})
end

local function add_callback_spawner(attached_obj)
	return minetest.add_particlespawner({
		amount = 80,
		time = 0.60,
		attached = attached_obj,
		minpos = vector.new(0, 1.3, 0),
		maxpos = vector.new(0, 1.3, 0),
		minvel = vector.new(0, 0, 0),
		maxvel = vector.new(0, 0, 0),
		minacc = vector.new(0, -9.8, 0),
		maxacc = vector.new(0, -9.8, 0),
		minexptime = 0.4,
		maxexptime = 0.9,
		minsize = 0.05,
		maxsize = 0.15,
		collisiondetection = false,
		glow = 0,
		texture = "smoke_puff.png",
		on_particle_spawn = function(i)
			local a = (i * 73) % 360
			local rad = math.rad(a)
			local speed = 0.8 + ((i * 17) % 100) / 100 * 1.6
			return {
				velocity = vector.new(math.cos(rad) * speed, 1.2 + speed * 0.35, math.sin(rad) * speed),
				acceleration = vector.new(0, -5.0, 0),
				size = 0.06 + ((i * 29) % 100) / 100 * 0.25,
				expirationtime = 0.35 + ((i * 41) % 100) / 100 * 0.85,
			}
		end,
	})
end

minetest.register_chatcommand("fork_api", {
	params = "cam_free | cam_clear | cam_shake | cam_fade | fog_on | fog_off | sky_on | sky_off | p_bone | p_cb",
	description = "Demo fork APIs",
	privs = { interact = true },
	func = function(name, param)
		local player = get_player(name)
		if not player then
			return false, "player not found"
		end
		param = (param or ""):trim()

		if param == "cam_free" then
			if not has_camera_api() then
				msg(name, "camera API missing")
				return true
			end
			freecam_set_physics(player, true)
			local yaw = player:get_look_horizontal() or 0
			local dir = minetest.yaw_to_dir(yaw)
			local pos = vector.add(player:get_pos(), vector.new(0, 1.5, 0))
			pos = vector.subtract(pos, vector.multiply(dir, 3.0))
			freecam[name] = { pos = pos, send_acc = 0 }
			minetest.camera.set(player, "free", {
				pos = pos,
				ease = { time = 0.35, type = "out_cubic" },
				lock_input = false,
			})
			msg(name, "freecam on (WASD + jump/sneak, look to rotate, aux1 = faster)")
			return true
		end

		if param == "cam_clear" then
			if not has_camera_api() then
				msg(name, "camera API missing")
				return true
			end
			freecam_stop(player)
			msg(name, "camera clear")
			return true
		end

		if param == "cam_shake" then
			if not has_camera_api() then
				msg(name, "camera API missing")
				return true
			end
			minetest.camera.shake(player, { intensity = 0.8, duration = 0.25, decay = true })
			msg(name, "shake")
			return true
		end

		if param == "cam_fade" then
			if not has_camera_api() then
				msg(name, "camera API missing")
				return true
			end
			minetest.camera.fade(player, {
				color = "#000000",
				fade_in = 0.15,
				hold = 0.20,
				fade_out = 0.25,
				callback = function()
					msg(name, "fade hold")
				end,
			})
			msg(name, "fade")
			return true
		end

		if param == "fog_on" then
			if not has_fog_api() then
				msg(name, "fog API missing")
				return true
			end
			minetest.set_fog(player, {
				color = "#ABD2FF",
				fog_start = 0.2,
				fog_end = 0.75,
				blend_time = 1.0,
				weather = {
					color = "#8A8A8A",
					fog_start = 0.05,
					fog_end = 0.35,
				},
			})
			msg(name, "fog on")
			return true
		end

		if param == "fog_off" then
			if not has_fog_api() then
				msg(name, "fog API missing")
				return true
			end
			minetest.set_fog(player, nil)
			msg(name, "fog off")
			return true
		end

		if param == "sky_on" then
			if not has_sky_keyframes_api() then
				msg(name, "sky keyframes API missing")
				return true
			end
			minetest.set_sky_keyframes(player, {
				{ time = 0.0, sky = "#0A0A1A", fog = "#0A0A1A", ambient = "#111133" },
				{ time = 0.25, sky = "#FF6633", fog = "#FF8855", ambient = "#FFAA77" },
				{ time = 0.5, sky = "#5599FF", fog = "#ABD2FF", ambient = "#FFFFFF" },
				{ time = 0.75, sky = "#FF4422", fog = "#FF7744", ambient = "#FFAA66" },
				{ time = 1.0, sky = "#0A0A1A", fog = "#0A0A1A", ambient = "#111133" },
				interpolation = "cubic",
			})
			msg(name, "sky keyframes on")
			return true
		end

		if param == "sky_off" then
			if not has_sky_keyframes_api() then
				msg(name, "sky keyframes API missing")
				return true
			end
			minetest.set_sky_keyframes(player, nil)
			msg(name, "sky keyframes off")
			return true
		end

		if param == "p_bone" then
			local id = add_muzzle_like_spawner(player)
			msg(name, "particles (bone attach) spawner id=" .. tostring(id))
			return true
		end

		if param == "p_cb" then
			local id = add_callback_spawner(player)
			msg(name, "particles (callback) spawner id=" .. tostring(id))
			return true
		end

		msg(name, "usage: /fork_api cam_free|cam_clear|cam_shake|cam_fade|fog_on|fog_off|sky_on|sky_off|p_bone|p_cb")
		return true
	end,
})
