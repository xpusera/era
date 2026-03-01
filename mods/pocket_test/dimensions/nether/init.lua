pocket.register("nether", {
	sky = {type = "plain", base_color = "#1a0000"},
	sun = {visible = false},
	moon = {visible = false},
	stars = {visible = false},
	physics = {gravity = 1.4, speed = 0.85, jump = 0.8},
	lighting = {saturation = 0.3},
	mapgen = {
		on_chunk = function(minp, maxp, seed, layer)
			local perlin = minetest.get_perlin({
				offset = 0,
				scale = 8,
				spread = {x = 80, y = 80, z = 80},
				seed = seed,
				octaves = 4,
			})
			for x = minp.x, maxp.x do
				for z = minp.z, maxp.z do
					local surface_y = minp.y + math.floor(perlin:get2d({x = x, y = z}) + 8)
					pocket.set_node({x = x, y = surface_y, z = z}, "default:obsidian", layer)
					for y = minp.y, surface_y - 1 do
						pocket.set_node({x = x, y = y, z = z}, "default:stone", layer)
					end
					if surface_y < minp.y + 3 then
						pocket.set_node({x = x, y = surface_y, z = z}, "default:lava_source", layer)
					end
				end
			end
		end,
	},
	on_enter = function(player)
		minetest.chat_send_player(player:get_player_name(), "You enter the Nether")
	end,
	on_leave = function(player)
		minetest.chat_send_player(player:get_player_name(), "You leave the Nether")
	end,
})
