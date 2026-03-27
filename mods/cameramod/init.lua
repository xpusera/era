local dex_path = minetest.get_modpath("cameramod") .. "/CameraMod.dex"
javamod.load("cameramod:camera", dex_path)

minetest.register_chatcommand("orbit", {
    description = "Start orbiting camera",
    func = function(name, param)
        javamod.change("cameramod:camera", "player",
            '{"active":true,"radius":4,"speed":45,"height":2}')
        return true, "Camera orbit started"
    end
})

minetest.register_chatcommand("orbit_stop", {
    description = "Reset camera to normal",
    func = function(name, param)
        javamod.remove("cameramod:camera", "player")
        return true, "Camera reset"
    end
})

minetest.register_globalstep(function(dtime)
    local player = minetest.get_player_by_name("singleplayer")
    if player then
        local pos = player:get_pos()
        local props = string.format(
            '{"dtime":%.4f,"player_x":%.2f,"player_y":%.2f,"player_z":%.2f}',
            dtime, pos.x, pos.y, pos.z
        )
        javamod.update("cameramod:camera", "player", props)
    end
end)
