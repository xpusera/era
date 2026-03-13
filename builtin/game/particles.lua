local particles = {}
core.particle_defs = {}

function core.register_particle_def(name, def)
	if core.particle_defs[name] then
		core.log("warning", "Particle definition already exists: " .. name)
	end
	if def.on_spawn and def.on_collide then
		error("Particle definition '" .. name .. "': on_spawn and on_collide are mutually exclusive")
	end
	core.particle_defs[name] = def
end

local function parse_range(val, default)
	if type(val) == "number" then
		return val, val
	elseif type(val) == "table" then
		return val.min or default or 0, val.max or default or 0
	end
	return default or 0, default or 0
end

function core.spawn_particle(name, pos_or_attach, opts)
	local def = core.particle_defs[name]
	if not def then
		error("Particle definition not found: " .. name)
	end

	-- Merge opts into a copy of def
	local p = {}
	for k, v in pairs(def) do p[k] = v end
	if opts then
		for k, v in pairs(opts) do p[k] = v end
	end

	local spawner = {
		amount = p.amount or 1,
		time = p.duration or 0,
		collisiondetection = p.collision or false,
		glow = p.glow or 0,
		texture = p.texture,
		vertical = (p.face_camera == "rotate_y"),
		face_camera = p.face_camera or "rotate_xyz",
	}

	if p.loop then
		spawner.time = 0
	end

	-- Handle attached
	if type(pos_or_attach) == "table" and pos_or_attach.object then
		spawner.attached = pos_or_attach.object
		spawner.bone = pos_or_attach.bone or ""
		spawner.offset = pos_or_attach.offset or {x=0, y=0, z=0}
	else
		spawner.pos = pos_or_attach or {x=0, y=0, z=0}
	end

	-- Lifetime -> exptime
	spawner.minexptime, spawner.maxexptime = parse_range(p.lifetime, 1)

	-- Size
	if p.size_over_lifetime then
		-- In current Luanti size is just a range.
		-- We might need engine changes for size_over_lifetime if not already present.
		-- For now, use min/max from the curve as an approximation if engine doesn't support it.
		local min_s = 1000000
		local max_s = -1000000
		for _, k in ipairs(p.size_over_lifetime) do
			min_s = math.min(min_s, k.size)
			max_s = math.max(max_s, k.size)
		end
		spawner.minsize = min_s
		spawner.maxsize = max_s
	else
		spawner.minsize, spawner.maxsize = parse_range(p.size, 1)
	end

	-- Velocity
	if p.velocity then
		local speed_min, speed_max = parse_range(p.velocity.speed, 0)
		local dir = p.velocity.direction or "up"

		if dir == "up" then
			spawner.minvel = {x=0, y=speed_min, z=0}
			spawner.maxvel = {x=0, y=speed_max, z=0}
		elseif dir == "sphere" then
			spawner.minvel = {x=-speed_max, y=-speed_max, z=-speed_max}
			spawner.maxvel = {x=speed_max, y=speed_max, z=speed_max}
		elseif dir == "cone_forward" then
			-- Assume forward is Z+ for now
			spawner.minvel = {x=-speed_max*0.2, y=-speed_max*0.2, z=speed_min}
			spawner.maxvel = {x=speed_max*0.2, y=speed_max*0.2, z=speed_max}
		elseif type(dir) == "table" then
			spawner.minvel = {x=dir.x*speed_min, y=dir.y*speed_min, z=dir.z*speed_min}
			spawner.maxvel = {x=dir.x*speed_max, y=dir.y*speed_max, z=dir.z*speed_max}
		end

		if p.velocity.x then spawner.minvel.x, spawner.maxvel.x = parse_range(p.velocity.x) end
		if p.velocity.y then spawner.minvel.y, spawner.maxvel.y = parse_range(p.velocity.y) end
		if p.velocity.z then spawner.minvel.z, spawner.maxvel.z = parse_range(p.velocity.z) end
	end

	-- Acceleration
	if p.acceleration then
		spawner.minacc = p.acceleration
		spawner.maxacc = p.acceleration
	end

	-- Drag
	if p.drag then
		spawner.drag = {x=p.drag, y=p.drag, z=p.drag}
	end

	-- Spawn Shape
	if p.spawn_shape == "sphere" then
		local r = p.spawn_shape_opts and p.spawn_shape_opts.radius or 1
		local base_pos = spawner.pos or {x=0, y=0, z=0}
		spawner.minpos = base_pos
		spawner.maxpos = base_pos
		spawner.radius = {min={x=r,y=r,z=r}, max={x=r,y=r,z=r}}
	elseif p.spawn_shape == "box" then
		local o = p.spawn_shape_opts or {x=1, y=1, z=1}
		local base_pos = spawner.pos or {x=0, y=0, z=0}
		spawner.minpos = {x=base_pos.x-o.x/2, y=base_pos.y-o.y/2, z=base_pos.z-o.z/2}
		spawner.maxpos = {x=base_pos.x+o.x/2, y=base_pos.y+o.y/2, z=base_pos.z+o.z/2}
	elseif p.spawn_shape == "point" or not p.spawn_shape then
		local base_pos = spawner.pos or {x=0, y=0, z=0}
		spawner.minpos = base_pos
		spawner.maxpos = base_pos
	end

	-- Animation
	if p.texture_animation then
		spawner.animation = {
			type = "vertical_frames",
			aspect_w = p.texture_animation.frames_x or 1,
			aspect_h = p.texture_animation.frames_y or 1,
			length = (p.texture_animation.frames_x or 1) * (p.texture_animation.frames_y or 1) / (p.texture_animation.fps or 1)
		}
	end

	-- Color over lifetime
	if p.color_over_lifetime then
		spawner.color_over_lifetime = p.color_over_lifetime
	end

	-- Callbacks
	if p.on_spawn then
		spawner.on_particle_spawn = p.on_spawn
	end
	if p.on_collide then
		spawner.on_particle_collide = p.on_collide
	end

	return core.add_particlespawner(spawner)
end

function core.stop_particle(id)
	return core.delete_particlespawner(id)
end

-- Scan for particle files in mods
core.after(0, function()
	for _, modname in ipairs(core.get_modnames()) do
		local modpath = core.get_modpath(modname)
		local ppath = modpath .. "/particles"
		local files = core.get_dir_list(ppath, false)
		for _, filename in ipairs(files) do
			if filename:sub(-4) == ".lua" then
				local basename = filename:sub(1, -5)
				local def = dofile(ppath .. "/" .. filename)
				if type(def) == "table" then
					core.register_particle_def(modname .. ":" .. basename, def)
				end
			end
		end
	end
end)
