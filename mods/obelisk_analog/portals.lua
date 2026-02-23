local oh = obelisk_analog
local C = oh.C
local random = math.random
local vec_add, vec_sub = vector.add, vector.subtract

minetest.register_node("obelisk_analog:portal_activator", {
    description = "Portal Activator",
    tiles = {
        "default_obsidian.png^[colorize:#4B0082:100",
        "default_obsidian.png^[colorize:#4B0082:100",
        "default_obsidian.png^[colorize:#4B0082:100",
        "default_obsidian.png^[colorize:#4B0082:100",
        "default_obsidian.png^[colorize:#4B0082:100",
        "default_obsidian.png^[colorize:#8B0000:150",
    },
    paramtype2 = "facedir",
    groups = {cracky = 1},
    sounds = default.node_sound_stone_defaults(),
    light_source = C.LIGHT.RITUAL_GLOW,

    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        if not player then return itemstack end
        local item_name = itemstack:get_name()
        local name = player:get_player_name()

        local portals = {
            ["obelisk_analog:portal_key_sequence"] = {dim = "sequence", color = "#0000FF"},
            ["obelisk_analog:portal_key_wonderland"] = {dim = "wonderland", color = "#00FF00"},
            ["obelisk_analog:portal_key_corners"] = {dim = "corners", color = "#FF0000"},
            ["obelisk_analog:portal_key_endless_house"] = {dim = "endless_house", color = "#FFD700"},
        }

        local portal_data = portals[item_name]
        if portal_data then
            itemstack:take_item()
            oh.teleport_to_dimension(player, portal_data.dim)

            local spread = {x = 1, y = 1, z = 1}
            minetest.add_particlespawner({
                amount = 100,
                time = 1,
                minpos = vec_sub(pos, spread),
                maxpos = vec_add(pos, spread),
                minvel = {x = -2, y = 0, z = -2},
                maxvel = {x = 2, y = 3, z = 2},
                texture = "default_obsidian.png^[colorize:" .. portal_data.color .. ":200",
            })

            return itemstack
        else
            minetest.chat_send_player(name, minetest.colorize("#8B0000", "You need a portal key to activate this..."))
        end

        return itemstack
    end,

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Portal Activator\nUse a Portal Key to travel to dimensions")
    end,
})

minetest.register_craft({
    output = "obelisk_analog:portal_activator",
    recipe = {
        {"default:obsidian", "default:mese_crystal", "default:obsidian"},
        {"default:obsidian", "default:diamond", "default:obsidian"},
        {"default:obsidian", "default:obsidian", "default:obsidian"},
    },
})

minetest.register_craft({
    output = "obelisk_analog:portal_key_sequence",
    recipe = {
        {"", "default:mese_crystal", ""},
        {"default:steel_ingot", "default:diamond", "default:steel_ingot"},
        {"", "default:obsidian", ""},
    },
})

minetest.register_craft({
    output = "obelisk_analog:portal_key_wonderland",
    recipe = {
        {"", "default:mese_crystal", ""},
        {"default:gold_ingot", "default:diamond", "default:gold_ingot"},
        {"", "default:obsidian", ""},
    },
})

minetest.register_craft({
    output = "obelisk_analog:portal_key_corners",
    recipe = {
        {"", "default:mese_crystal", ""},
        {"default:bronze_ingot", "default:diamond", "default:bronze_ingot"},
        {"", "default:obsidian", ""},
    },
})

minetest.register_craft({
    output = "obelisk_analog:portal_key_endless_house",
    recipe = {
        {"", "default:mese_crystal", ""},
        {"default:gold_ingot", "default:diamond", "default:gold_ingot"},
        {"", "default:obsidian", ""},
    },
})

local portal_colors = {
    ["obelisk_analog:portal_sequence"] = "#0000FF",
    ["obelisk_analog:portal_wonderland"] = "#00FF00",
    ["obelisk_analog:portal_corners"] = "#FF0000",
    ["obelisk_analog:portal_endless_house"] = "#FFD700",
    ["obelisk_analog:portal_overworld"] = "#FFFFFF",
    ["obelisk_analog:portal_activator"] = "#4B0082",
}

function oh.update_portal_particles(dtime)
    oh.timers.portal_particles = oh.timers.portal_particles + dtime
    if oh.timers.portal_particles < C.TIMERS.PORTAL_PARTICLES then return end
    oh.timers.portal_particles = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local ppos = player:get_pos()
        if not ppos then goto continue end

        local portal_range = {x = 20, y = 20, z = 20}
        local portals = minetest.find_nodes_in_area(
            vec_sub(ppos, portal_range),
            vec_add(ppos, portal_range),
            {
                "obelisk_analog:portal_sequence",
                "obelisk_analog:portal_wonderland",
                "obelisk_analog:portal_corners",
                "obelisk_analog:portal_endless_house",
                "obelisk_analog:portal_overworld",
                "obelisk_analog:portal_activator",
            }
        )

        for _, portal_pos in ipairs(portals) do
            local node = minetest.get_node(portal_pos)
            local color = portal_colors[node.name] or "#4B0082"

            local p_spread = {x = 0.5, y = 0.5, z = 0.5}
            minetest.add_particlespawner({
                amount = 10,
                time = 2,
                minpos = vec_sub(portal_pos, p_spread),
                maxpos = vec_add(portal_pos, p_spread),
                minvel = {x = 0, y = 0.5, z = 0},
                maxvel = {x = 0, y = 1.5, z = 0},
                minexptime = 1,
                maxexptime = 2,
                minsize = 0.5,
                maxsize = 1.5,
                texture = "default_obsidian.png^[colorize:" .. color .. ":200",
                glow = 10,
            })
        end

        ::continue::
    end
end

function oh.create_portal_effect(pos, color)
    if not pos then return end
    color = color or "#4B0082"

    local spread = {x = 1, y = 1, z = 1}
    minetest.add_particlespawner({
        amount = 50,
        time = 1,
        minpos = vec_sub(pos, spread),
        maxpos = vec_add(pos, spread),
        minvel = {x = -1, y = -1, z = -1},
        maxvel = {x = 1, y = 3, z = 1},
        minacc = {x = 0, y = 0.5, z = 0},
        maxacc = {x = 0, y = 1, z = 0},
        minexptime = 1,
        maxexptime = 2,
        minsize = 1,
        maxsize = 3,
        texture = "default_obsidian.png^[colorize:" .. color .. ":200",
        glow = 14,
    })

    minetest.sound_play("obelisk_analog_random_voice", {pos = pos, gain = 0.5, max_hear_distance = 20})
end
