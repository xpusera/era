local modpath = minetest.get_modpath("obelisk_analog")
local C = dofile(modpath .. "/constants.lua")

local random, floor, abs = math.random, math.floor, math.abs
local vec_add, vec_sub, vec_mul, vec_dir, vec_dist = vector.add, vector.subtract, vector.multiply, vector.direction, vector.distance

obelisk_analog = {
    modpath = modpath,
    storage = minetest.get_mod_storage(),
    C = C,

    entity_active = false,
    current_entity = nil,
    player_data = {},
    current_phase = 1,
    day_counter = 0,
    last_day = 0,
    rare_structures = {},

    global_spawn_cooldown_until = 0,

    timers = {
        spawn = 0,
        day_check = 0,
        god_mode = 0,
        time_control = 0,
        ambient = 0,
        phase_effects = 0,
        night_empower = 0,
        special_event = 0,
        portal_particles = 0,
    },
}

local oh = obelisk_analog
local S = minetest.get_translator("obelisk_analog")
oh.S = S

oh.whisper_messages = {
    "It's coming...",
    "The world grows dark...",
    "You cannot hide...",
    "Behind you...",
    "I see you...",
    "Run...",
    "The darkness hungers...",
    "You are not alone...",
    "Do you feel it?",
    "The shadows watch...",
    "Time is running out...",
    "I am always here...",
    "You cannot escape...",
    "The void calls...",
    "Your soul belongs to me...",
}

oh.crazy_messages = {
    "RUN!",
    "TOO LATE!",
    "FOUND YOU!",
    "NO ESCAPE!",
    "MINE!",
}

local function load_persistent_data()
    local phase = oh.storage:get_int("current_phase")
    if phase > 0 then
        oh.current_phase = phase
    end

    local day_counter = oh.storage:get_int("day_counter")
    oh.day_counter = day_counter

    local last_day = oh.storage:get_int("last_day")
    oh.last_day = last_day

    local structures_json = oh.storage:get_string("rare_structures")
    if structures_json and structures_json ~= "" then
        oh.rare_structures = minetest.deserialize(structures_json) or {}
    end
end

local function save_persistent_data()
    oh.storage:set_int("current_phase", oh.current_phase)
    oh.storage:set_int("day_counter", oh.day_counter)
    oh.storage:set_int("last_day", oh.last_day)
    oh.storage:set_string("rare_structures", minetest.serialize(oh.rare_structures))
end

local function is_night()
    local time = minetest.get_timeofday()
    return time < C.NIGHT.END or time > C.NIGHT.START
end

function oh.get_dimension(pos)
    if not pos then return "overworld" end
    local y = pos.y
    if y >= C.DIMENSION.ENDLESS_HOUSE_Y - C.DIMENSION.VOID_THRESHOLD then
        return "endless_house"
    elseif y >= C.DIMENSION.CORNERS_Y - C.DIMENSION.VOID_THRESHOLD then
        return "corners"
    elseif y >= C.DIMENSION.WONDERLAND_Y - C.DIMENSION.VOID_THRESHOLD then
        return "wonderland"
    elseif y >= C.DIMENSION.SEQUENCE_Y - C.DIMENSION.VOID_THRESHOLD then
        return "sequence"
    end
    return "overworld"
end

function oh.is_in_dimension(pos)
    if not pos then return false end
    return pos.y >= C.DIMENSION.SEQUENCE_Y - C.DIMENSION.VOID_THRESHOLD
end

function oh.is_night()
    return is_night()
end

function oh.get_random_player()
    local players = minetest.get_connected_players()
    local count = #players
    if count > 0 then
        return players[random(count)]
    end
    return nil
end

function oh.player_can_see_pos(player, pos)
    if not player or not pos then return false end
    local ppos = player:get_pos()
    if not ppos then return false end
    ppos.y = ppos.y + 1.5
    local dir = player:get_look_dir()
    local to_pos = vec_dir(ppos, pos)
    return vector.dot(dir, to_pos) > 0.3
end

function oh.is_dark_enough(pos)
    if not pos then return true end
    local light = minetest.get_node_light(pos, nil)
    return not light or light < C.LIGHT.DARK_THRESHOLD
end

function oh.find_spawn_pos_behind_player(player)
    if not player then return nil end
    local ppos = player:get_pos()
    if not ppos then return nil end

    local dir = player:get_look_dir()
    local behind = vec_mul(dir, -1)
    local distance = random(C.ENTITY.SPAWN_DISTANCE_MIN, C.ENTITY.SPAWN_DISTANCE_MAX)
    local spawn_pos = vec_add(ppos, vec_mul(behind, distance))
    spawn_pos.y = ppos.y

    for i = -5, 5 do
        local test_pos = {x = spawn_pos.x, y = ppos.y + i, z = spawn_pos.z}
        local node = minetest.get_node(test_pos)
        local node_above = minetest.get_node({x = test_pos.x, y = test_pos.y + 1, z = test_pos.z})
        local node_above2 = minetest.get_node({x = test_pos.x, y = test_pos.y + 2, z = test_pos.z})

        local def = minetest.registered_nodes[node.name]
        local walkable = def and def.walkable

        if walkable and node_above.name == "air" and node_above2.name == "air" then
            return {x = test_pos.x, y = test_pos.y + 1, z = test_pos.z}
        end
    end

    return spawn_pos
end

function oh.play_sound(player, sound, gain)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end
    minetest.sound_play(sound, {
        to_player = name,
        gain = gain or 1.0,
    })
end

function oh.send_whisper(player, msg)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end
    msg = msg or oh.whisper_messages[random(#oh.whisper_messages)]
    minetest.chat_send_player(name, minetest.colorize("#8B0000", msg))
end

function oh.show_jumpscare(player, duration)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    duration = duration or 0.5
    local jumpscare_num = random(1, 4)
    local formspec = "formspec_version[4]" ..
        "size[100,100]" ..
        "position[0.5,0.5]" ..
        "anchor[0.5,0.5]" ..
        "no_prepend[]" ..
        "bgcolor[#000000FF;true;0]" ..
        "background[0,0;100,100;obelisk_analog_jumpscare" .. jumpscare_num .. ".png;true]" ..
        "image[35,30;30,40;entity_model.png]"

    minetest.show_formspec(name, "obelisk_analog:jumpscare", formspec)
    oh.play_sound(player, "obelisk_analog_random_voice", 1.5)

    minetest.after(duration, function()
        local p = minetest.get_player_by_name(name)
        if p then
            minetest.close_formspec(name, "obelisk_analog:jumpscare")
        end
    end)
end

function oh.freeze_player(player, duration)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    player:set_physics_override({speed = 0, jump = 0})

    minetest.after(duration, function()
        local p = minetest.get_player_by_name(name)
        if p then
            p:set_physics_override({speed = 1, jump = 1})
        end
    end)
end

function oh.spawn_entity_near_player(player)
    if oh.entity_active then return false end
    if not player then return false end

    local spawn_pos = oh.find_spawn_pos_behind_player(player)
    if not spawn_pos then return false end

    local entity = minetest.add_entity(spawn_pos, "obelisk_analog:entity")
    if entity then
        oh.entity_active = true
        oh.current_entity = entity
        local lua = entity:get_luaentity()
        if lua then
            lua.target_player = player:get_player_name()
        end
        return true
    end
    return false
end

function oh.get_phase_config()
    return oh.phase_configs and oh.phase_configs[oh.current_phase] or {
        name = "Unknown",
        spawn_rate = 0.1,
        entity_speed = 2,
        ability_frequency = 0.5,
        whisper_chance = 0.1,
        kill_chance = 0.1,
        night_only = true,
    }
end

function oh.create_particles(pos, texture, amount, time, opts)
    if not pos then return end
    if not texture then texture = "default_dirt.png" end
    opts = opts or {}
    local spread = opts.spread or 1
    if type(spread) == "number" then
        spread = {x = spread, y = spread, z = spread}
    end
    local spawner = {
        amount = amount or 20,
        time = time or 0.5,
        minpos = vec_sub(pos, spread),
        maxpos = vec_add(pos, spread),
        minvel = opts.minvel or {x = -1, y = -1, z = -1},
        maxvel = opts.maxvel or {x = 1, y = 1, z = 1},
        minacc = opts.minacc or {x = 0, y = 0, z = 0},
        maxacc = opts.maxacc or {x = 0, y = 0, z = 0},
        minexptime = opts.minexptime or 0.5,
        maxexptime = opts.maxexptime or 1.5,
        minsize = opts.minsize or 1,
        maxsize = opts.maxsize or 2,
        texture = texture,
        glow = opts.glow or 0,
    }
    pcall(function()
        minetest.add_particlespawner(spawner)
    end)
end

function oh.is_walkable_node(name)
    if not name or name == "air" or name == "ignore" then return false end
    local def = minetest.registered_nodes[name]
    return def and def.walkable
end

function oh.safe_set_node(pos, node)
    if not pos or not node or not node.name then return false end
    if minetest.is_protected(pos, "") then return false end
    local cur = minetest.get_node(pos)
    if cur.name ~= "air" then return false end
    minetest.set_node(pos, node)
    return true
end

function oh.place_wallmounted(node_name, pos, support_dirs)
    if not pos or not node_name or not support_dirs then return false end
    if minetest.is_protected(pos, "") then return false end
    if minetest.get_node(pos).name ~= "air" then return false end

    for _, dir in ipairs(support_dirs) do
        local sp = vector.add(pos, dir)
        local sn = minetest.get_node(sp)
        if oh.is_walkable_node(sn.name) then
            local param2 = minetest.dir_to_wallmounted(dir)
            minetest.set_node(pos, {name = node_name, param2 = param2})
            return true
        end
    end

    return false
end

local function caesar(s, shift)
    shift = shift or 3
    local out = {}
    for i = 1, #s do
        local c = s:byte(i)
        if c >= 65 and c <= 90 then
            local n = ((c - 65 + shift) % 26) + 65
            out[i] = string.char(n)
        elseif c >= 97 and c <= 122 then
            local n = ((c - 97 + shift) % 26) + 97
            out[i] = string.char(n)
        else
            out[i] = string.char(c)
        end
    end
    return table.concat(out)
end

function oh.make_note_stack(kind, seed)
    kind = kind or "note"
    seed = seed or minetest.get_gametime()

    local stack_name = (kind == "encoded") and "obelisk_analog:encoded_note" or "obelisk_analog:note"
    local st = ItemStack(stack_name)
    local meta = st:get_meta()

    local titles = {
        "Loose Page",
        "Folded Note",
        "Smudged Paper",
        "Torn Sheet",
    }

    local raw = {
        "If you hear creaking, don't open the next door.",
        "The house is bigger inside.",
        "Count the doors. If it's wrong, turn back.",
        "Don't trust the lights.",
        "If it stands still, it is closer than you think.",
        "The corners are not safe anymore.",
        "Write down the room numbers. They change.",
    }

    local title = titles[(seed % #titles) + 1]
    local text = raw[(seed % #raw) + 1]

    if kind == "encoded" then
        local shift = (seed % 19) + 3
        local encoded = caesar(text, shift)
        meta:set_string("title", "Cipher Note")
        meta:set_string("cipher", "caesar")
        meta:set_int("shift", shift)
        meta:set_string("text", encoded)
        meta:set_string("hint", "Caesar shift " .. shift .. " (A->?)")
    else
        meta:set_string("title", title)
        meta:set_string("text", text)
    end

    return st
end

dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/entity.lua")
dofile(modpath .. "/structure_validator.lua")
dofile(modpath .. "/dimensions.lua")
dofile(modpath .. "/structures.lua")
dofile(modpath .. "/portals.lua")
dofile(modpath .. "/effects.lua")
dofile(modpath .. "/phases.lua")
dofile(modpath .. "/htmlview.lua")
dofile(modpath .. "/ai.lua")

load_persistent_data()

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    oh.player_data[name] = {
        last_seen_entity = 0,
        paranoia_level = 0,
        items_stolen = 0,
        in_god_mode = false,
        dimension_spawn_pos = nil,
        current_dimension = nil,
        last_entity_spawn_at = 0,
    }

    if oh.html_start then
        oh.html_start()
    end
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    oh.player_data[name] = nil
end)

minetest.register_on_shutdown(function()
    save_persistent_data()
end)

local function update_spawn_timer(dtime)
    oh.timers.spawn = oh.timers.spawn + dtime
    if oh.timers.spawn < C.TIMERS.SPAWN_CHECK then return end
    oh.timers.spawn = 0

    if oh.entity_active then return end

    local now = minetest.get_gametime()
    if oh.global_spawn_cooldown_until and now < oh.global_spawn_cooldown_until then
        return
    end

    local player = oh.get_random_player()
    if not player then return end

    local ppos = player:get_pos()
    if not ppos then return end

    local config = oh.get_phase_config()
    local in_dimension = oh.is_in_dimension(ppos)

    local pdata = oh.player_data[player:get_player_name()]
    if pdata and pdata.last_entity_spawn_at and (now - pdata.last_entity_spawn_at) < (C.ENTITY.PER_PLAYER_SPAWN_COOLDOWN or 600) then
        return
    end

    local time = minetest.get_timeofday()
    local night = is_night()
    local dawn = (time >= (C.NIGHT.END - 0.03) and time <= (C.NIGHT.END + 0.03))
        or (time >= (C.NIGHT.START - 0.03) and time <= (C.NIGHT.START + 0.03))

    local dark_day = (not night and not dawn and not in_dimension and oh.is_dark_enough(ppos))

    if not in_dimension and not night and not dawn and not dark_day then
        return
    end

    local spawn_chance = (config.spawn_rate or 0) * 0.15
    if night then
        spawn_chance = spawn_chance * 1.0
    elseif dawn then
        spawn_chance = spawn_chance * 0.35
    elseif dark_day then
        spawn_chance = spawn_chance * 0.05
    end

    if in_dimension then
        spawn_chance = spawn_chance * 1.1
    end

    if random() < spawn_chance then
        local spawn_pos = oh.find_spawn_pos_behind_player(player)
        if spawn_pos and oh.is_dark_enough(spawn_pos) then
            local entity = minetest.add_entity(spawn_pos, "obelisk_analog:entity")
            if entity then
                oh.entity_active = true
                oh.current_entity = entity
                if pdata then
                    pdata.last_entity_spawn_at = now
                end
                oh.global_spawn_cooldown_until = now + random(C.ENTITY.RESPAWN_TIME_MIN, C.ENTITY.RESPAWN_TIME_MAX)
                local lua = entity:get_luaentity()
                if lua then
                    lua.target_player = player:get_player_name()
                end
            end
        end
    end
end

local function update_day_counter(dtime)
    oh.timers.day_check = oh.timers.day_check + dtime
    if oh.timers.day_check < C.TIMERS.DAY_CHECK then return end
    oh.timers.day_check = 0

    local current_day = minetest.get_day_count()
    if current_day ~= oh.last_day then
        oh.day_counter = oh.day_counter + 1
        oh.last_day = current_day

        if oh.day_counter >= C.PHASE.DAYS_PER_ADVANCE then
            oh.day_counter = 0
            oh.current_phase = oh.current_phase + 1
            if oh.current_phase > C.PHASE.MAX then
                oh.current_phase = C.PHASE.MIN
            end

            local config = oh.get_phase_config()
            for _, player in ipairs(minetest.get_connected_players()) do
                minetest.chat_send_player(player:get_player_name(),
                    minetest.colorize("#FF0000", "Phase " .. oh.current_phase .. ": " .. config.name))
            end

            save_persistent_data()
        end
    end
end

minetest.register_globalstep(function(dtime)
    update_spawn_timer(dtime)
    update_day_counter(dtime)

    if oh.update_god_mode then oh.update_god_mode(dtime) end
    if oh.update_time_control then oh.update_time_control(dtime) end
    if oh.update_ambient_effects then oh.update_ambient_effects(dtime) end
    if oh.update_phase_effects then oh.update_phase_effects(dtime) end
    if oh.update_night_empowerment then oh.update_night_empowerment(dtime) end
    if oh.update_special_events then oh.update_special_events(dtime) end
    if oh.update_portal_particles then oh.update_portal_particles(dtime) end
    if oh.update_blood_moon then oh.update_blood_moon(dtime) end

    if oh.html_state and oh.html_state.voice_loud and oh.entity_active and oh.current_entity then
        local now = minetest.get_gametime()
        oh.html_state.last_voice_trigger = oh.html_state.last_voice_trigger or 0
        if now - oh.html_state.last_voice_trigger > 2 then
            oh.html_state.last_voice_trigger = now
            local player = oh.get_random_player()
            if player then
                local lua = oh.current_entity:get_luaentity()
                if lua then
                    lua.target_player = player:get_player_name()
                    if lua.state ~= "chasing" then
                        lua.state = "chasing"
                        lua.state_timer = 0
                    end
                end
            end
        end
    end

    if oh.ai_step then
        oh.ai_step(dtime)
    end
end)

minetest.register_chatcommand("horror_spawn", {
    privs = {server = true},
    description = "Force spawn the horror entity",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end

        if oh.entity_active and oh.current_entity then
            local pos = oh.current_entity:get_pos()
            if pos then
                oh.current_entity:remove()
            end
            oh.entity_active = false
            oh.current_entity = nil
        end

        if oh.spawn_entity_near_player(player) then
            return true, "Entity spawned!"
        end
        return false, "Failed to spawn entity"
    end,
})

minetest.register_chatcommand("horror_tp_sequence", {
    privs = {server = true},
    description = "Teleport to The Sequence dimension",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player and oh.teleport_to_dimension then
            oh.teleport_to_dimension(player, "sequence")
            return true, "Teleported to The Sequence"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_tp_wonderland", {
    privs = {server = true},
    description = "Teleport to Wonderland dimension",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player and oh.teleport_to_dimension then
            oh.teleport_to_dimension(player, "wonderland")
            return true, "Teleported to Wonderland"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_tp_corners", {
    privs = {server = true},
    description = "Teleport to The Corners dimension",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player and oh.teleport_to_dimension then
            oh.teleport_to_dimension(player, "corners")
            return true, "Teleported to The Corners"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_tp_endless_house", {
    privs = {server = true},
    description = "Teleport to The Endless House dimension",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player and oh.teleport_to_dimension then
            oh.teleport_to_dimension(player, "endless_house")
            return true, "Teleported to The Endless House"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_tp_overworld", {
    privs = {server = true},
    description = "Teleport back to the Overworld",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player and oh.teleport_to_overworld then
            oh.teleport_to_overworld(player)
            return true, "Teleported to Overworld"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_phase", {
    privs = {server = true},
    description = "Set horror phase (1-5)",
    params = "<phase>",
    func = function(name, param)
        local phase = tonumber(param)
        if phase and phase >= C.PHASE.MIN and phase <= C.PHASE.MAX then
            oh.current_phase = phase
            save_persistent_data()
            return true, "Phase set to " .. phase
        end
        return false, "Invalid phase (1-5)"
    end,
})

minetest.register_chatcommand("horror_debug", {
    privs = {server = true},
    description = "Show debug info",
    func = function(name)
        local info = string.format(
            "Phase: %d | Entity Active: %s | Day Counter: %d",
            oh.current_phase,
            tostring(oh.entity_active),
            oh.day_counter
        )
        return true, info
    end,
})

minetest.log("action", "[obelisk_analog] init Loaded")
