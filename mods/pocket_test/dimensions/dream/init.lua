pocket.register("dream", {
	sky = {type = "plain", base_color = "#ffd6f5"},
	physics = {gravity = 0.3, speed = 0.6, jump = 1.8},
	lighting = {saturation = 1.0},
	mapgen = {
		on_chunk = function(minp, maxp, seed, layer)
			local perlin = minetest.get_perlin({
				offset = 0,
				scale = 1,
				spread = {x = 40, y = 40, z = 40},
				seed = seed + 999,
				octaves = 2,
			})
			for x = minp.x, maxp.x, 8 do
				for z = minp.z, maxp.z, 8 do
					local v = perlin:get2d({x = x, y = z})
					if v > 0.6 then
						local island_y = minp.y + math.floor((v - 0.6) * 30) + 10
						for dx = -3, 3 do
							for dz = -3, 3 do
								if dx * dx + dz * dz <= 9 then
									pocket.set_node({x = x + dx, y = island_y, z = z + dz}, "default:glass", layer)
								end
							end
						end
					end
				end
			end
		end,
	},
	on_enter = function(player)
		minetest.chat_send_player(player:get_player_name(), "You enter the Dream")
	end,
	on_leave = function(player)
		minetest.chat_send_player(player:get_player_name(), "You leave the Dream")
	end,
})
