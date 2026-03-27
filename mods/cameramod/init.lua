-- cameramod init.lua

-- Load the compiled dex
local dex_path = minetest.get_modpath("cameramod") .. "/CameraMod.dex"
-- We use a fixed ID for the mod instance.
-- Based on JavaModManager.java, if the ID contains ':', the part after it is the class name.
local mod_id = "cameramod:net.minetest.mods.CameraMod"

if javamod then
    javamod.load(mod_id, dex_path)
else
    minetest.log("error", "[cameramod] javamod API not available (not on Android?)")
end

-- Start orbit on command
minetest.register_chatcommand("orbit", {
    func = function(name, param)
        if javamod then
            javamod.change(mod_id, "player", '{"active":true,"radius":4,"speed":45,"height":2}')
            return true, "Camera orbit started"
        end
        return false, "javamod not available"
    end
})

-- Stop orbit on command
minetest.register_chatcommand("orbit_stop", {
    func = function(name, param)
        if javamod then
            javamod.change(mod_id, "player", '{"active":false}')
            return true, "Camera orbit stopped"
        end
        return false, "javamod not available"
    end
})

-- Every frame pass player position to the Java class
minetest.register_globalstep(function(dtime)
    if not javamod then return end

    local player = minetest.get_player_by_name("singleplayer")
    if player then
        local pos = player:get_pos()
        local props = string.format(
            '{"dtime":%.4f,"player_x":%.2f,"player_y":%.2f,"player_z":%.2f}',
            dtime, pos.x, pos.y, pos.z
        )
        -- Since javamod.update is not exposed to Lua but change() is,
        -- we use change() with a specific target "update" to pass per-frame data.
        javamod.change(mod_id, "update", props)
    end
end)
