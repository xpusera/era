local oh = obelisk_analog
local C = oh.C
local random = math.random
local vec_add, vec_sub = vector.add, vector.subtract

oh.phase_configs = {
    [1] = {
        name = "Awakening",
        spawn_rate = 0.04,
        entity_speed = 1.9,
        ability_frequency = 0.4,
        whisper_chance = 0.08,
        kill_chance = 0.03,
        night_only = true,
        description = "The entity begins to stir...",
    },
    [2] = {
        name = "Emergence",
        spawn_rate = 0.06,
        entity_speed = 2.2,
        ability_frequency = 0.55,
        whisper_chance = 0.12,
        kill_chance = 0.05,
        night_only = false,
        description = "The darkness spreads...",
    },
    [3] = {
        name = "Pursuit",
        spawn_rate = 0.08,
        entity_speed = 2.6,
        ability_frequency = 0.7,
        whisper_chance = 0.16,
        kill_chance = 0.07,
        night_only = false,
        description = "It hunts relentlessly...",
    },
    [4] = {
        name = "Terror",
        spawn_rate = 0.1,
        entity_speed = 3.0,
        ability_frequency = 0.85,
        whisper_chance = 0.22,
        kill_chance = 0.1,
        night_only = false,
        description = "Fear consumes all...",
    },
    [5] = {
        name = "Nightmare",
        spawn_rate = 0.12,
        entity_speed = 3.4,
        ability_frequency = 1.0,
        whisper_chance = 0.28,
        kill_chance = 0.14,
        night_only = false,
        description = "There is no escape...",
    },
}

function oh.set_phase(phase)
    if phase < C.PHASE.MIN or phase > C.PHASE.MAX then
        return false
    end

    oh.current_phase = phase
    local config = oh.get_phase_config()

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        minetest.chat_send_player(name, minetest.colorize("#FF0000", "Phase " .. phase .. ": " .. config.name))
        minetest.chat_send_player(name, minetest.colorize("#8B0000", config.description))
    end

    if oh.current_entity and oh.entity_active then
        local entity_pos = oh.current_entity:get_pos()
        if entity_pos then
            local entity = oh.current_entity:get_luaentity()
            if entity then
                entity.base_speed = config.entity_speed
                entity.current_speed = config.entity_speed
            end
        end
    end

    return true
end

function oh.advance_phase()
    local new_phase = oh.current_phase + 1
    if new_phase > C.PHASE.MAX then
        new_phase = C.PHASE.MIN
    end
    oh.set_phase(new_phase)
end

function oh.update_phase_effects(dtime)
    oh.timers.phase_effects = oh.timers.phase_effects + dtime
    if oh.timers.phase_effects < C.TIMERS.PHASE_EFFECTS then return end
    oh.timers.phase_effects = 0

    local config = oh.get_phase_config()

    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = player:get_pos()
        if not pos then goto continue_player end

        local is_night = oh.is_night()

        if config.night_only and not is_night then
            goto continue_player
        end

        if random() < config.whisper_chance then
            oh.send_whisper(player)
        end

        if oh.current_phase >= 3 then
            if random() < 0.1 then
                oh.play_sound(player, "obelisk_analog_random_voice", 0.2)
            end
        end

        if oh.current_phase >= 4 then
            if random() < 0.05 and oh.create_darkness_particles then
                oh.create_darkness_particles(vec_add(pos, {
                    x = random(-10, 10),
                    y = random(-2, 5),
                    z = random(-10, 10),
                }))
            end
        end

        if oh.current_phase == 5 then
            if random() < 0.1 then
                local torch_range = {x = 20, y = 20, z = 20}
                local torches = minetest.find_nodes_in_area(
                    vec_sub(pos, torch_range),
                    vec_add(pos, torch_range),
                    {"default:torch", "default:torch_wall", "default:torch_ceiling"}
                )

                if #torches > 0 then
                    local torch_pos = torches[random(#torches)]
                    local node = minetest.get_node(torch_pos)
                    local node_name = node.name
                    local param2 = node.param2

                    minetest.swap_node(torch_pos, {name = "air"})
                    minetest.after(0.3, function()
                        minetest.swap_node(torch_pos, {name = node_name, param2 = param2})
                    end)
                end
            end
        end

        ::continue_player::
    end
end

function oh.update_night_empowerment(dtime)
    oh.timers.night_empower = oh.timers.night_empower + dtime
    if oh.timers.night_empower < C.TIMERS.NIGHT_EMPOWER then return end
    oh.timers.night_empower = 0

    if not oh.current_entity or not oh.entity_active then return end

    local entity_pos = oh.current_entity:get_pos()
    if not entity_pos then return end

    local entity = oh.current_entity:get_luaentity()
    if not entity then return end

    local config = oh.get_phase_config()
    local is_night = oh.is_night()

    if is_night then
        entity.base_speed = config.entity_speed * 1.3
    else
        entity.base_speed = config.entity_speed
    end
end

oh.blood_moon_active = false
oh.blood_moon_timer = 0
oh.blood_moon_duration = 0

function oh.start_blood_moon()
    oh.blood_moon_active = true
    oh.blood_moon_duration = random(180, 360)
    oh.blood_moon_timer = 0

    minetest.set_timeofday(0)

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        minetest.chat_send_player(name, minetest.colorize("#FF0000", "THE BLOOD MOON RISES..."))

        player:set_sky({
            type = "plain",
            base_color = "#3a0000",
            clouds = true,
        })
        player:set_sun({
            visible = false,
            sunrise_visible = false,
        })
        player:set_moon({
            visible = true,
            scale = 2,
            texture = "default_dirt.png^[colorize:#FF0000:220",
        })
        player:set_stars({
            visible = true,
            count = 500,
            star_color = "#FF4444",
            scale = 1.5,
        })

        if oh.flash_screen then
            oh.flash_screen(player, "#8B0000", 1)
        end
        oh.play_sound(player, "obelisk_analog_random_voice", 1.5)
    end

    oh.current_phase = C.PHASE.MAX
end

function oh.end_blood_moon()
    oh.blood_moon_active = false
    oh.blood_moon_timer = 0
    oh.blood_moon_duration = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        minetest.chat_send_player(name, minetest.colorize("#888888", "The blood moon fades..."))

        player:set_sky({
            type = "regular",
            clouds = true,
        })
        player:set_sun({
            visible = true,
            sunrise_visible = true,
            scale = 1,
        })
        player:set_moon({
            visible = true,
            scale = 1,
            texture = "",
        })
        player:set_stars({
            visible = true,
            count = 1000,
            star_color = "#FFFFFF",
            scale = 1,
        })
    end
end

function oh.update_blood_moon(dtime)
    if not oh.blood_moon_active then return end

    oh.blood_moon_timer = oh.blood_moon_timer + dtime

    if oh.blood_moon_timer >= oh.blood_moon_duration then
        oh.end_blood_moon()
        return
    end

    local time = minetest.get_timeofday()
    if time > C.NIGHT.END and time < C.NIGHT.START then
        minetest.set_timeofday(0)
    end

    for _, player in ipairs(minetest.get_connected_players()) do
        local pdata = oh.player_data[player:get_player_name()]
        if not pdata or not pdata.current_dimension then
            player:set_sky({
                type = "plain",
                base_color = "#3a0000",
                clouds = true,
            })
        end
    end
end

minetest.register_on_joinplayer(function(player)
    if oh.blood_moon_active then
        player:set_sky({
            type = "plain",
            base_color = "#3a0000",
            clouds = true,
        })
        player:set_sun({ visible = false, sunrise_visible = false })
        player:set_moon({
            visible = true,
            scale = 2,
            texture = "default_dirt.png^[colorize:#FF0000:220",
        })
        player:set_stars({ visible = true, count = 500, star_color = "#FF4444", scale = 1.5 })
    end
end)

local special_events = {
    {
        name = "Blood Moon",
        chance = 0.003,
        min_phase = 3,
        effect = function()
            if oh.blood_moon_active then return end
            oh.start_blood_moon()
        end,
    },
    {
        name = "The Watching",
        chance = 0.005,
        min_phase = 2,
        effect = function()
            for _, player in ipairs(minetest.get_connected_players()) do
                local name = player:get_player_name()
                minetest.chat_send_player(name, minetest.colorize("#4B0082", "You feel countless eyes upon you..."))

                local ppos = player:get_pos()
                if ppos then
                    for i = 1, 5 do
                        local spawn_pos = {
                            x = ppos.x + random(-30, 30),
                            y = ppos.y,
                            z = ppos.z + random(-30, 30),
                        }
                        minetest.add_entity(spawn_pos, "obelisk_analog:clone")
                    end
                end
            end
        end,
    },
    {
        name = "Time Slip",
        chance = 0.003,
        min_phase = 4,
        effect = function()
            for _, player in ipairs(minetest.get_connected_players()) do
                local name = player:get_player_name()
                minetest.chat_send_player(name, minetest.colorize("#00FFFF", "Time bends around you..."))
                if oh.distort_player_vision then
                    oh.distort_player_vision(player, 5)
                end
            end

            for i = 1, 20 do
                minetest.after(i * 0.1, function()
                    minetest.set_timeofday(random())
                end)
            end
        end,
    },
    {
        name = "Sudden Appearance",
        chance = 0.008,
        min_phase = 2,
        effect = function()
            local player = oh.get_random_player()
            if not player then return end

            local ppos = player:get_pos()
            if not ppos then return end

            local look_dir = player:get_look_dir()
            local spawn_pos = vec_add(ppos, {
                x = look_dir.x * 3,
                y = 0,
                z = look_dir.z * 3,
            })

            if oh.entity_active and oh.current_entity then
                local entity_pos = oh.current_entity:get_pos()
                if entity_pos then
                    oh.current_entity:set_pos(spawn_pos)
                end
            else
                oh.spawn_entity_near_player(player)
                if oh.current_entity then
                    oh.current_entity:set_pos(spawn_pos)
                end
            end

            oh.play_sound(player, "obelisk_analog_random_voice", 1.2)
            oh.send_whisper(player, "BOO")
        end,
    },
    {
        name = "Dimensional Rift",
        chance = 0.004,
        min_phase = 3,
        effect = function()
            local player = oh.get_random_player()
            if not player then return end

            local name = player:get_player_name()
            local ppos = player:get_pos()
            if not ppos then return end

            oh.create_particles(ppos, "default_obsidian.png^[colorize:#4B0082:200", 60, 2, {
                spread = 3,
                minvel = {x = -1, y = 1, z = -1},
                maxvel = {x = 1, y = 3, z = 1},
                glow = 12,
            })

            minetest.chat_send_player(name, minetest.colorize("#9932CC", "A dimensional rift opens nearby..."))
            oh.play_sound(player, "obelisk_analog_random_voice", 0.8)

            local inv = player:get_inventory()
            if inv then
                local roll = random()
                if roll < 0.5 then
                    inv:add_item("main", "obelisk_analog:key_fragment " .. random(2, 5))
                    minetest.chat_send_player(name, minetest.colorize("#4B0082", "Fragments fall from the rift!"))
                elseif roll < 0.85 then
                    local keys = {
                        "obelisk_analog:portal_key_sequence",
                        "obelisk_analog:portal_key_wonderland",
                    }
                    inv:add_item("main", keys[random(#keys)])
                    minetest.chat_send_player(name, minetest.colorize("#FFD700", "A key materializes!"))
                else
                    inv:add_item("main", "obelisk_analog:portal_key_corners")
                    minetest.chat_send_player(name, minetest.colorize("#FF4500", "A crimson key falls from the void!"))
                end
            end
        end,
    },
    {
        name = "Entity Gift",
        chance = 0.002,
        min_phase = 4,
        effect = function()
            if not oh.entity_active then return end

            local player = oh.get_random_player()
            if not player then return end

            local name = player:get_player_name()
            local inv = player:get_inventory()
            if not inv then return end

            minetest.chat_send_player(name, minetest.colorize("#8B0000", "It wants you to come closer..."))
            oh.send_whisper(player, "A gift for you...")

            minetest.after(2, function()
                local p = minetest.get_player_by_name(name)
                if p then
                    local pinv = p:get_inventory()
                    if pinv then
                        local keys = {
                            "obelisk_analog:portal_key_sequence",
                            "obelisk_analog:portal_key_wonderland",
                            "obelisk_analog:portal_key_corners",
                        }
                        pinv:add_item("main", keys[random(#keys)])
                        minetest.chat_send_player(name, minetest.colorize("#FF0000", "Something cold appears in your inventory..."))
                        oh.play_sound(p, "obelisk_analog_random_voice", 0.6)
                    end
                end
            end)
        end,
    },
}

function oh.update_special_events(dtime)
    oh.timers.special_event = oh.timers.special_event + dtime
    if oh.timers.special_event < C.TIMERS.SPECIAL_EVENT then return end
    oh.timers.special_event = 0

    for _, event in ipairs(special_events) do
        if oh.current_phase >= event.min_phase then
            if random() < event.chance then
                minetest.log("action", "[obelisk_analog] Special event triggered: " .. event.name)
                event.effect()
                break
            end
        end
    end
end

minetest.register_chatcommand("horror_phase_info", {
    description = "Show current phase information",
    func = function(name)
        local config = oh.get_phase_config()
        local info = string.format(
            "Phase %d: %s\n%s\nSpawn Rate: %.0f%%\nEntity Speed: %.1f\nAbility Freq: %.1fx\nKill Chance: %.0f%%",
            oh.current_phase,
            config.name,
            config.description,
            config.spawn_rate * 100,
            config.entity_speed,
            config.ability_frequency,
            config.kill_chance * 100
        )
        return true, info
    end,
})

minetest.register_chatcommand("horror_advance_phase", {
    privs = {server = true},
    description = "Advance to the next phase",
    func = function(name)
        oh.advance_phase()
        return true, "Phase advanced to " .. oh.current_phase
    end,
})

minetest.register_chatcommand("horror_blood_moon", {
    privs = {server = true},
    description = "Trigger a blood moon event",
    func = function(name)
        if oh.blood_moon_active then
            oh.end_blood_moon()
            return true, "Blood moon ended"
        else
            oh.start_blood_moon()
            return true, "Blood moon started"
        end
    end,
})
