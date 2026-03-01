minetest.register_chatcommand("pocket_enter", {
	params = "<dimension>",
	description = "Enter a pocket dimension",
	privs = {interact = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "player not found"
		end
		local ok, err = pocket.enter(player, param)
		if not ok then
			return false, err
		end
		return true, "entered " .. param
	end,
})

minetest.register_chatcommand("pocket_leave", {
	description = "Leave pocket dimension",
	privs = {interact = true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "player not found"
		end
		local ok, err = pocket.leave(player)
		if not ok then
			return false, err
		end
		return true, "left"
	end,
})
