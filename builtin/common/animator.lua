local M = {}
core.animator = M

M._event_listeners = {}

M._end_watchers = {}

function M.register_on_event(cb)
	assert(type(cb) == "function")
	table.insert(M._event_listeners, cb)
end

function M.unregister_on_event(cb)
	for i, f in ipairs(M._event_listeners) do
		if f == cb then
			table.remove(M._event_listeners, i)
			return true
		end
	end
	return false
end

local function anim_sig(obj)
	local range, speed, blend, loop, clip = obj:get_animation()
	local rx = range and (range.x or range[1]) or 0
	local ry = range and (range.y or range[2]) or 0
	return table.concat({tostring(rx), tostring(ry), tostring(speed), tostring(blend), tostring(loop), tostring(clip)}, ":")
end

function M.on_animation_end(obj, cb)
	assert(obj and obj.is_valid and obj:is_valid())
	assert(type(cb) == "function")
	local now = core.get_us_time and core.get_us_time() or 0
	M._end_watchers[obj] = {
		cb = cb,
		sig = anim_sig(obj),
		start_us = now,
		end_us = nil,
	}
	return obj
end

function M.cancel_on_animation_end(obj)
	M._end_watchers[obj] = nil
end

if not core.on_animation_end then
	core.on_animation_end = M.on_animation_end
end

local RAD = math.rad
local DEG = math.deg

local function v3(x, y, z)
	return {x = x, y = y, z = z}
end

local function v3eq(a, b, eps)
	eps = eps or 0
	return math.abs(a.x - b.x) <= eps and math.abs(a.y - b.y) <= eps and math.abs(a.z - b.z) <= eps
end

local function v2(x, y)
	return {x = x, y = y}
end

local function to_v2(r)
	if not r then
		return v2(0, 0)
	end
	return v2(r.x or r[1] or 0, r.y or r[2] or 0)
end

local function clamp01(x)
	if x <= 0 then
		return 0
	end
	if x >= 1 then
		return 1
	end
	return x
end

local function quat(x, y, z, w)
	return {x = x, y = y, z = z, w = w}
end

local function quat_id()
	return quat(0, 0, 0, 1)
end

local function quat_dot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
end

local function quat_norm(a)
	local l = math.sqrt(quat_dot(a, a))
	if l == 0 then
		return quat_id()
	end
	return quat(a.x / l, a.y / l, a.z / l, a.w / l)
end

local function quat_mul(a, b)
	return quat(
		a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
		a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
		a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
		a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
	)
end

local function quat_from_euler_rad(e)
	local cx = math.cos(e.x * 0.5)
	local sx = math.sin(e.x * 0.5)
	local cy = math.cos(e.y * 0.5)
	local sy = math.sin(e.y * 0.5)
	local cz = math.cos(e.z * 0.5)
	local sz = math.sin(e.z * 0.5)
	return quat(
		sx * cy * cz - cx * sy * sz,
		cx * sy * cz + sx * cy * sz,
		cx * cy * sz - sx * sy * cz,
		cx * cy * cz + sx * sy * sz
	)
end

local function quat_to_euler_rad(q)
	q = quat_norm(q)
	local sinr_cosp = 2 * (q.w * q.x + q.y * q.z)
	local cosr_cosp = 1 - 2 * (q.x * q.x + q.y * q.y)
	local x = math.atan2(sinr_cosp, cosr_cosp)

	local sinp = 2 * (q.w * q.y - q.z * q.x)
	local y
	if math.abs(sinp) >= 1 then
		y = (sinp >= 0 and 1 or -1) * (math.pi / 2)
	else
		y = math.asin(sinp)
	end

	local siny_cosp = 2 * (q.w * q.z + q.x * q.y)
	local cosy_cosp = 1 - 2 * (q.y * q.y + q.z * q.z)
	local z = math.atan2(siny_cosp, cosy_cosp)
	return v3(x, y, z)
end

local function quat_slerp(a, b, t)
	t = clamp01(t)
	local cosom = quat_dot(a, b)
	local bx, by, bz, bw = b.x, b.y, b.z, b.w
	if cosom < 0 then
		cosom = -cosom
		bx, by, bz, bw = -bx, -by, -bz, -bw
	end

	local scale0
	local scale1
	if (1 - cosom) > 1e-6 then
		local omega = math.acos(cosom)
		local sinom = math.sin(omega)
		scale0 = math.sin((1 - t) * omega) / sinom
		scale1 = math.sin(t * omega) / sinom
	else
		scale0 = 1 - t
		scale1 = t
	end

	return quat(
		scale0 * a.x + scale1 * bx,
		scale0 * a.y + scale1 * by,
		scale0 * a.z + scale1 * bz,
		scale0 * a.w + scale1 * bw
	)
end

local function ensure_sorted_events(state)
	if state._events_sorted then
		return
	end
	local events = state.events
	if type(events) == "table" then
		table.sort(events, function(a, b)
			return (a.frame or 0) < (b.frame or 0)
		end)
	end
	state._events_sorted = true
end

local function crossed(prev_frame, cur_frame, marker_frame, loop, range_start, range_end, dir)
	local len = range_end - range_start
	if len <= 0 then
		return false
	end

	if not loop then
		if dir >= 0 then
			return prev_frame < marker_frame and marker_frame <= cur_frame
		end
		return cur_frame <= marker_frame and marker_frame < prev_frame
	end

	if dir >= 0 then
		if cur_frame >= prev_frame then
			return prev_frame < marker_frame and marker_frame <= cur_frame
		end
		return marker_frame > prev_frame or marker_frame <= cur_frame
	end

	if cur_frame <= prev_frame then
		return cur_frame <= marker_frame and marker_frame < prev_frame
	end
	return marker_frame < prev_frame or marker_frame >= cur_frame
end

local Animator = {}
Animator.__index = Animator

function Animator:new(object, def)
	assert(object and type(def) == "table")
	local o = {
		object = object,
		def = def,
		states = def.states or {},
		transitions = def.transitions or {},
		current = nil,
		time_in_state = 0,
		prev_frame = nil,
		layers = {},
		layer_order = {},
		_last_bone_rot = {},
		_last_anim_sig = nil,
	}
	return setmetatable(o, self)
end

function Animator:is_valid()
	return self.object and self.object:is_valid()
end

function Animator:_apply_animation(state, blend)
	local obj = self.object
	local range = to_v2(state.range)
	local speed = state.speed or 15
	local loop = state.loop
	if loop == nil then
		loop = true
	end
	blend = blend or state.blend or 0

	local clip = state.clip
	local sig = table.concat({tostring(clip), range.x, range.y, speed, tostring(blend), tostring(loop)}, ":")
	if sig == self._last_anim_sig then
		return
	end
	self._last_anim_sig = sig

	if clip == nil then
		obj:set_animation(range, speed, blend, loop)
	else
		obj:set_animation_clip(clip, range, speed, blend, loop)
	end
end

function Animator:set_state(name, opts)
	local state = self.states[name]
	assert(state, "unknown state: " .. tostring(name))
	opts = opts or {}

	local blend = opts.blend
	self.current = name
	self.time_in_state = 0
	self.prev_frame = nil
	ensure_sorted_events(state)
	self:_apply_animation(state, blend)
end

function Animator:_get_context(dtime)
	local f = self.def.get_context
	if type(f) == "function" then
		return f(self, self.object, dtime) or {}
	end

	local obj = self.object
	local vel = obj:get_velocity() or v3(0, 0, 0)
	local hspeed = math.sqrt((vel.x or 0) * (vel.x or 0) + (vel.z or 0) * (vel.z or 0))
	return {
		vel = vel,
		hs = hspeed,
		moving = hspeed > 0.01,
	}
end

function Animator:_eval_transitions(ctx)
	local cur = self.current
	if not cur then
		return nil
	end

	local best
	local best_prio = -math.huge
	for _, tr in ipairs(self.transitions) do
		local from = tr.from
		if from == "*" or from == cur then
			local cond = tr.condition
			if type(cond) == "function" and cond(ctx, self, self.object) then
				local prio = tr.priority or 0
				if prio > best_prio then
					best_prio = prio
					best = tr
				end
			end
		end
	end
	return best
end

function Animator:_step_events(dtime, ctx)
	local cur = self.current
	if not cur then
		return
	end
	local state = self.states[cur]
	local events = state.events
	if type(events) ~= "table" or #events == 0 then
		return
	end

	local range = to_v2(state.range)
	local speed = state.speed or 15
	local loop = state.loop
	if loop == nil then
		loop = true
	end

	local dir = speed >= 0 and 1 or -1
	local start = range.x
	local endf = range.y
	local len = endf - start
	if len <= 0 then
		return
	end

	local prev = self.prev_frame
	local cur_frame = start + self.time_in_state * speed
	if loop then
		if dir >= 0 then
			if cur_frame > endf then
				cur_frame = start + (cur_frame - start) % len
			end
		else
			if cur_frame < start then
				cur_frame = endf - (endf - cur_frame) % len
			end
		end
	else
		if dir >= 0 then
			if cur_frame > endf then
				cur_frame = endf
			end
		else
			if cur_frame < start then
				cur_frame = start
			end
		end
	end

	if prev == nil then
		self.prev_frame = cur_frame
		return
	end

	local cb = self.def.on_event
	for _, ev in ipairs(events) do
		local f = ev.frame
		if type(f) == "number" then
			if crossed(prev, cur_frame, f, loop, start, endf, dir) then
				local payload = {
					name = ev.name,
					state = cur,
					clip = state.clip,
					frame = f,
					time = self.time_in_state,
					ctx = ctx,
					data = ev.data,
				}
					if type(ev.callback) == "function" then
						ev.callback(self, self.object, payload)
					end
					if type(cb) == "function" then
						cb(self, self.object, payload)
					end
					for _, gcb in ipairs(M._event_listeners) do
						if type(gcb) == "function" then
							gcb(self, self.object, payload)
						end
					end
				end
			end
		end

	self.prev_frame = cur_frame
end

function Animator:set_additive_layer(name, layer)
	assert(type(name) == "string" and type(layer) == "table")
	if not self.layers[name] then
		table.insert(self.layer_order, name)
	end
	self.layers[name] = layer
end

function Animator:clear_additive_layer(name)
	self.layers[name] = nil
	for i, n in ipairs(self.layer_order) do
		if n == name then
			table.remove(self.layer_order, i)
			break
		end
	end
end

function Animator:_apply_additive_layers()
	local obj = self.object
	local combined = {}
	local interp_by_bone = {}

	for _, lname in ipairs(self.layer_order) do
		local layer = self.layers[lname]
		if layer then
			local w = layer.weight
			if w == nil then
				w = 1
			end
			w = clamp01(w)
			local bones = layer.bones
			local layer_interp = layer.interpolation
			if layer_interp == nil then
				layer_interp = 0
			end
			if w > 0 and type(bones) == "table" then
				for bone, spec in pairs(bones) do
					local rot = spec.rotation
					if rot then
						local rdeg = v3(rot.x or rot[1] or 0, rot.y or rot[2] or 0, rot.z or rot[3] or 0)
						local rrad = v3(RAD(rdeg.x), RAD(rdeg.y), RAD(rdeg.z))
						local q = quat_from_euler_rad(rrad)
						local ql = quat_slerp(quat_id(), q, w)
						combined[bone] = combined[bone] and quat_mul(combined[bone], ql) or ql
						local bi = spec.interpolation
						if bi == nil then
							bi = layer_interp
						end
						if bi and bi > (interp_by_bone[bone] or 0) then
							interp_by_bone[bone] = bi
						end
					end
				end
			end
		end
	end

	for bone, q in pairs(combined) do
		local e = quat_to_euler_rad(q)
		local last = self._last_bone_rot[bone]
		if not last or not v3eq(last, e, 1e-5) then
			obj:set_bone_override(bone, {
				rotation = {vec = e, absolute = false, interpolation = interp_by_bone[bone] or 0},
			})
			self._last_bone_rot[bone] = e
		end
	end

	for bone, _ in pairs(self._last_bone_rot) do
		if not combined[bone] then
			obj:set_bone_override(bone, {})
			self._last_bone_rot[bone] = nil
		end
	end
end

function Animator:update(dtime)
	if not self:is_valid() then
		return false
	end

	local ctx = self:_get_context(dtime)
	self.time_in_state = self.time_in_state + dtime

	local tr = self:_eval_transitions(ctx)
	if tr then
		local to = tr.to
		local blend = tr.blend
		if self.current ~= to then
			self:set_state(to, {blend = blend})
		end
	end

	self:_step_events(dtime, ctx)
	self:_apply_additive_layers()

	local cb = self.def.on_step
	if type(cb) == "function" then
		cb(self, self.object, dtime, ctx)
	end

	return true
end

M.Animator = Animator

local registry = {}

function M.register(anim)
	assert(type(anim) == "table" and type(anim.update) == "function")
	registry[anim] = true
	return anim
end

function M.unregister(anim)
	registry[anim] = nil
end

if INIT == "game" and core.register_globalstep then
	core.register_globalstep(function(dtime)
		local now = core.get_us_time and core.get_us_time() or 0
		for obj, w in pairs(M._end_watchers) do
			if not obj or not obj.is_valid or not obj:is_valid() then
				M._end_watchers[obj] = nil
			else
				local sig = anim_sig(obj)
				if sig ~= w.sig then
					w.sig = sig
					w.start_us = now
					w.end_us = nil
				end
				if w.end_us == nil then
					local range, speed, _, loop = obj:get_animation()
					local rx = range and (range.x or range[1]) or 0
					local ry = range and (range.y or range[2]) or 0
					local sp = speed or 0
					if loop == false and sp ~= 0 and ry > rx then
						local dur = (ry - rx) / math.abs(sp)
						w.end_us = w.start_us + math.floor(dur * 1000000)
					end
				end
				if w.end_us and now >= w.end_us then
					local cb = w.cb
					M._end_watchers[obj] = nil
					if type(cb) == "function" then
						cb(obj)
					end
				end
			end
		end
		for anim, _ in pairs(registry) do
			if not anim:is_valid() then
				registry[anim] = nil
			else
				anim:update(dtime)
			end
		end
	end)
end

function M.create(object, def)
	local anim = Animator:new(object, def)
	if def and def.initial then
		anim:set_state(def.initial, {blend = def.initial_blend or 0})
	else
		local first
		for k, _ in pairs(anim.states) do
			first = k
			break
		end
		if first then
			anim:set_state(first, {blend = 0})
		end
	end
	return anim
end

function M.humanoid(object, clips, opts)
	opts = opts or {}
	clips = clips or {}
	local walk_th = opts.walk_threshold or 0.05
	local run_th = opts.run_threshold or 2.5

	local function mk_state(v, fallback_loop)
		if type(v) == "table" then
			return {
				clip = v.clip,
				range = v.range,
				speed = v.speed,
				loop = v.loop,
				blend = v.blend,
				events = v.events,
			}
		end
		if v == nil then
			return {clip = nil, range = {x = 0, y = 0}, speed = 15, loop = fallback_loop, blend = 0}
		end
		return {clip = v, range = {x = 0, y = 0}, speed = 15, loop = fallback_loop, blend = 0}
	end

	local states = {
		idle = mk_state(clips.idle, true),
		walk = mk_state(clips.walk, true),
		run = mk_state(clips.run, true),
		jump = mk_state(clips.jump, false),
		attack = mk_state(clips.attack, false),
	}

	local transitions = {
		{ from = "*", to = "attack", priority = 100, condition = function(ctx)
			return ctx and ctx.attack
		end },
		{ from = "*", to = "jump", priority = 90, condition = function(ctx)
			return ctx and ctx.jumping
		end },
		{ from = "*", to = "run", priority = 10, condition = function(ctx)
			return ctx and not ctx.attack and not ctx.jumping and (ctx.hs or 0) >= run_th
		end },
		{ from = "*", to = "walk", priority = 5, condition = function(ctx)
			local hs = ctx and (ctx.hs or 0) or 0
			return ctx and not ctx.attack and not ctx.jumping and hs >= walk_th and hs < run_th
		end },
		{ from = "*", to = "idle", priority = 0, condition = function(ctx)
			return ctx and not ctx.attack and not ctx.jumping and (ctx.hs or 0) < walk_th
		end },
	}

	local def = {
		states = states,
		transitions = transitions,
		initial = opts.initial or "idle",
		get_context = opts.get_context,
		on_event = opts.on_event,
		on_step = opts.on_step,
		initial_blend = opts.initial_blend,
	}

	return M.create(object, def)
end
