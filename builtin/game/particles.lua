local particles = {}
core.particle_defs = {}

function core.register_particle_def(name, def)
	if core.particle_defs[name] then
		core.log("warning", "Particle definition already exists: " .. name)
	end
	if def.on_spawn and def.on_collide then
		error("Particle definition '" .. name .. "': on_spawn and on_collide are mutually exclusive")
	end
	if def.on_spawn and def.spawn_shape and def.spawn_shape ~= "point" then
		error("Particle definition '" .. name .. "': on_spawn is incompatible with native spawn shapes (cone, sphere, ring, box)")
	end
	core.particle_defs[name] = def
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
		spawn_shape = p.spawn_shape or "point",
		spawn_shape_opts = p.spawn_shape_opts or {},
		initial_rotation = p.initial_rotation,
		rotation_speed = p.rotation_speed,
		size_over_lifetime = p.size_over_lifetime,
		drag = p.drag or 0,
	}

	if p.loop then
		spawner.time = 0
	end

	-- Handle attached
	if type(pos_or_attach) == "table" and pos_or_attach.object then
		spawner.attached = {
			object = pos_or_attach.object,
			bone = pos_or_attach.bone or "",
			offset = pos_or_attach.offset or {x=0, y=0, z=0}
		}
	else
		spawner.pos = pos_or_attach or {x=0, y=0, z=0}
	end

	-- Luanti add_particlespawner parameters
	if p.lifetime then
		if type(p.lifetime) == "number" then
			spawner.minexptime = p.lifetime
			spawner.maxexptime = p.lifetime
		else
			spawner.minexptime = p.lifetime.min or 1
			spawner.maxexptime = p.lifetime.max or 1
		end
	end

	if p.size then
		if type(p.size) == "number" then
			spawner.minsize = p.size
			spawner.maxsize = p.size
		else
			spawner.minsize = p.size.min or 1
			spawner.maxsize = p.size.max or 1
		end
	end

	if p.velocity then
		spawner.velocity = p.velocity
		if type(p.velocity.speed) == "number" then
			spawner.minvel = {x=p.velocity.speed, y=p.velocity.speed, z=p.velocity.speed}
			spawner.maxvel = {x=p.velocity.speed, y=p.velocity.speed, z=p.velocity.speed}
		elseif type(p.velocity.speed) == "table" then
			spawner.minvel = {x=p.velocity.speed.min or 0, y=p.velocity.speed.min or 0, z=p.velocity.speed.min or 0}
			spawner.maxvel = {x=p.velocity.speed.max or 0, y=p.velocity.speed.max or 0, z=p.velocity.speed.max or 0}
		end
	end

	if p.acceleration then
		spawner.minacc = p.acceleration
		spawner.maxacc = p.acceleration
	end

	if p.texture_animation then
		spawner.animation = {
			type = "sheet_2d",
			frames_w = p.texture_animation.frames_x or 1,
			frames_h = p.texture_animation.frames_y or 1,
			frame_length = 1 / (p.texture_animation.fps or 1)
		}
	end

	if p.color_over_lifetime then
		spawner.color_over_lifetime = p.color_over_lifetime
	end

	if p.on_spawn then
		if spawner.spawn_shape ~= "point" then
			error("Particle definition: on_spawn is incompatible with native spawn shapes (cone, sphere, ring, box)")
		end
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
