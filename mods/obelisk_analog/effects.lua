local oh = obelisk_analog
local C = oh.C
local random = math.random
local vec_add, vec_sub = vector.add, vector.subtract

local screen_effects = {}

function oh.apply_screen_tear(player, duration)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    duration = duration or 2

    local formspec = "formspec_version[4]" ..
        "size[100,100]" ..
        "position[0.5,0.5]" ..
        "anchor[0.5,0.5]" ..
        "no_prepend[]" ..
        "bgcolor[#00000000;false]" ..
        "box[0,10;100,3;#FF0000]" ..
        "box[0,30;100,2;#00FF00]" ..
        "box[0,55;100,3;#0000FF]" ..
        "box[0,80;100,2;#FF00FF]"

    minetest.show_formspec(name, "obelisk_analog:screen_tear", formspec)

    minetest.after(duration, function()
        local p = minetest.get_player_by_name(name)
        if p then
            minetest.close_formspec(name, "obelisk_analog:screen_tear")
        end
    end)
end

function oh.apply_desaturation(player, duration)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    duration = duration or 5

    local formspec = "formspec_version[4]" ..
        "size[100,100]" ..
        "position[0.5,0.5]" ..
        "anchor[0.5,0.5]" ..
        "no_prepend[]" ..
        "bgcolor[#808080A0;true]"

    minetest.show_formspec(name, "obelisk_analog:desaturation", formspec)

    minetest.after(duration, function()
        local p = minetest.get_player_by_name(name)
        if p then
            minetest.close_formspec(name, "obelisk_analog:desaturation")
        end
    end)
end

function oh.apply_vignette(player, intensity)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    intensity = intensity or 150

    local alpha = string.format("%02X", intensity)
    local formspec = "formspec_version[4]" ..
        "size[100,100]" ..
        "position[0.5,0.5]" ..
        "anchor[0.5,0.5]" ..
        "no_prepend[]" ..
        "bgcolor[#00000000;false]" ..
        "box[0,0;100,15;#000000" .. alpha .. "]" ..
        "box[0,85;100,15;#000000" .. alpha .. "]" ..
        "box[0,0;15,100;#000000" .. alpha .. "]" ..
        "box[85,0;15,100;#000000" .. alpha .. "]"

    screen_effects[name] = formspec
end

function oh.clear_vignette(player)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    screen_effects[name] = nil
    minetest.close_formspec(name, "obelisk_analog:vignette")
end

function oh.flash_screen(player, color, duration)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    color = color or "#FFFFFF"
    duration = duration or 0.2

    local formspec = "formspec_version[4]" ..
        "size[100,100]" ..
        "position[0.5,0.5]" ..
        "anchor[0.5,0.5]" ..
        "no_prepend[]" ..
        "bgcolor[" .. color .. "FF;true]"

    minetest.show_formspec(name, "obelisk_analog:flash", formspec)

    minetest.after(duration, function()
        local p = minetest.get_player_by_name(name)
        if p then
            minetest.close_formspec(name, "obelisk_analog:flash")
        end
    end)
end

function oh.create_fog_particles(pos, radius, duration)
    if not pos then return end

    radius = radius or 10
    duration = duration or 10

    local spread = {x = radius, y = radius, z = radius}
    minetest.add_particlespawner({
        amount = 200,
        time = duration,
        minpos = vec_sub(pos, spread),
        maxpos = vec_add(pos, spread),
        minvel = {x = -0.3, y = 0, z = -0.3},
        maxvel = {x = 0.3, y = 0.1, z = 0.3},
        minacc = {x = 0, y = 0, z = 0},
        maxacc = {x = 0, y = 0.05, z = 0},
        minexptime = 3,
        maxexptime = 6,
        minsize = 8,
        maxsize = 15,
        texture = "default_cloud.png^[colorize:#888888:180",
        glow = 1,
    })
end

function oh.create_darkness_particles(pos)
    if not pos then return end

    local spread = {x = 2, y = 2, z = 2}
    minetest.add_particlespawner({
        amount = 50,
        time = 2,
        minpos = vec_sub(pos, spread),
        maxpos = vec_add(pos, spread),
        minvel = {x = -1, y = -0.5, z = -1},
        maxvel = {x = 1, y = 0.5, z = 1},
        minexptime = 1,
        maxexptime = 2,
        minsize = 2,
        maxsize = 4,
        texture = "default_obsidian.png^[colorize:#000000:200",
        glow = 0,
    })
end

function oh.create_blood_particles(pos)
    if not pos then return end

    minetest.add_particlespawner({
        amount = 30,
        time = 0.5,
        minpos = pos,
        maxpos = vec_add(pos, {x = 0, y = 0.5, z = 0}),
        minvel = {x = -2, y = 1, z = -2},
        maxvel = {x = 2, y = 3, z = 2},
        minacc = {x = 0, y = -10, z = 0},
        maxacc = {x = 0, y = -10, z = 0},
        minexptime = 0.5,
        maxexptime = 1,
        minsize = 0.5,
        maxsize = 1.5,
        texture = "default_dirt.png^[colorize:#8B0000:255",
    })
end

function oh.create_teleport_particles(pos, color)
    if not pos then return end
    color = color or "#4B0082"

    local spread = {x = 1, y = 1, z = 1}
    minetest.add_particlespawner({
        amount = 100,
        time = 1,
        minpos = vec_sub(pos, spread),
        maxpos = vec_add(pos, spread),
        minvel = {x = 0, y = -2, z = 0},
        maxvel = {x = 0, y = 2, z = 0},
        minacc = {x = 0, y = 0, z = 0},
        maxacc = {x = 0, y = 0, z = 0},
        minexptime = 0.5,
        maxexptime = 1.5,
        minsize = 1,
        maxsize = 3,
        texture = "default_obsidian.png^[colorize:" .. color .. ":200",
        glow = 10,
    })
end

local ambient_sounds = {
    "obelisk_analog_endless_house_creaking",
    "obelisk_analog_random_voice",
    "obelisk_analog_silence",
}

function oh.update_ambient_effects(dtime)
    oh.timers.ambient = oh.timers.ambient + dtime
    if oh.timers.ambient < C.TIMERS.AMBIENT then return end
    oh.timers.ambient = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = player:get_pos()
        if not pos then goto continue end

        local is_night = oh.is_night()
        local in_dimension = oh.is_in_dimension(pos)

        if is_night or in_dimension then
            if random() < 0.3 * oh.current_phase then
                local sound = ambient_sounds[random(#ambient_sounds)]
                oh.play_sound(player, sound, 0.3)
            end
        end

        if in_dimension then
            local dimension = oh.get_dimension(pos)

            if dimension == "wonderland" then
                oh.create_fog_particles(pos, 20, 30)
            end
        end

        ::continue::
    end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname:find("obelisk_analog:") then
        return true
    end
    return false
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if name then
        screen_effects[name] = nil
    end
end)

function oh.play_heartbeat(player, duration)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    duration = duration or 10
    local beats = math.floor(duration / 0.8)

    for i = 0, beats do
        minetest.after(i * 0.8, function()
            local p = minetest.get_player_by_name(name)
            if p then
                minetest.sound_play("obelisk_analog_crack_sound", {
                    to_player = name,
                    gain = 0.5,
                })
            end
        end)
    end
end

function oh.distort_player_vision(player, duration)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    duration = duration or 3

    for i = 0, duration * 10 do
        minetest.after(i * 0.1, function()
            local p = minetest.get_player_by_name(name)
            if p then
                local fov_mod = 1 + math.sin(i * 0.5) * 0.2
                p:set_fov(fov_mod, false, 0.1)
            end
        end)
    end

    minetest.after(duration, function()
        local p = minetest.get_player_by_name(name)
        if p then
            p:set_fov(0, false, 0.5)
        end
    end)
end

function oh.shake_player_view(player, intensity, duration)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    intensity = intensity or 1
    duration = duration or 1

    local steps = math.floor(duration * 20)

    for i = 0, steps do
        minetest.after(i * 0.05, function()
            local p = minetest.get_player_by_name(name)
            if p then
                local current_look = p:get_look_horizontal()
                local offset = (random() - 0.5) * 0.1 * intensity
                p:set_look_horizontal(current_look + offset)
            end
        end)
    end
end

minetest.register_chatcommand("horror_test_jumpscare", {
    privs = {server = true},
    description = "Test the jumpscare effect",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            oh.show_jumpscare(player, 1)
            return true, "Jumpscare triggered"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_test_fog", {
    privs = {server = true},
    description = "Test the fog effect",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            oh.create_fog_particles(player:get_pos(), 15, 30)
            return true, "Fog created"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_test_flash", {
    privs = {server = true},
    description = "Test the screen flash effect",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            oh.flash_screen(player, "#FF0000", 0.5)
            return true, "Screen flashed"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_test_shake", {
    privs = {server = true},
    description = "Test the screen shake effect",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            oh.shake_player_view(player, 2, 2)
            return true, "Screen shaking"
        end
        return false, "Player not found"
    end,
})
