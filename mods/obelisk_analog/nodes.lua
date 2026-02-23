local oh = obelisk_analog
local C = oh.C

minetest.register_node("obelisk_analog:ritual_stone", {
    description = "Ritual Stone",
    tiles = {"default_obsidian.png"},
    groups = {cracky = 1, not_in_creative_inventory = 1},
    sounds = default.node_sound_stone_defaults(),
    light_source = 3,
})

minetest.register_node("obelisk_analog:warning_sign", {
    description = "Warning Sign",
    tiles = {"default_wood.png"},
    groups = {choppy = 2, not_in_creative_inventory = 1},
    sounds = default.node_sound_wood_defaults(),
    paramtype2 = "facedir",
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "DANGER - DO NOT ENTER")
    end,
})

minetest.register_node("obelisk_analog:shrine_block", {
    description = "Shrine Block",
    tiles = {"default_stone_brick.png"},
    groups = {cracky = 2, not_in_creative_inventory = 1},
    sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("obelisk_analog:portal_sequence", {
    description = "Portal to The Sequence",
    tiles = {"default_obsidian.png^[colorize:#0000FF:80"},
    drawtype = "glasslike",
    paramtype = "light",
    light_source = C.LIGHT.PORTAL_GLOW,
    groups = {cracky = 1, not_in_creative_inventory = 1},
    sounds = default.node_sound_glass_defaults(),
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        if player and oh.teleport_to_dimension then
            oh.teleport_to_dimension(player, "sequence")
        end
    end,
})

minetest.register_node("obelisk_analog:portal_wonderland", {
    description = "Portal to Wonderland",
    tiles = {"default_obsidian.png^[colorize:#00FF00:80"},
    drawtype = "glasslike",
    paramtype = "light",
    light_source = C.LIGHT.PORTAL_GLOW,
    groups = {cracky = 1, not_in_creative_inventory = 1},
    sounds = default.node_sound_glass_defaults(),
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        if player and oh.teleport_to_dimension then
            oh.teleport_to_dimension(player, "wonderland")
        end
    end,
})

minetest.register_node("obelisk_analog:portal_corners", {
    description = "Portal to The Corners",
    tiles = {"default_obsidian.png^[colorize:#FF0000:80"},
    drawtype = "glasslike",
    paramtype = "light",
    light_source = C.LIGHT.PORTAL_GLOW,
    groups = {cracky = 1, not_in_creative_inventory = 1},
    sounds = default.node_sound_glass_defaults(),
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        if player and oh.teleport_to_dimension then
            oh.teleport_to_dimension(player, "corners")
        end
    end,
})

minetest.register_node("obelisk_analog:portal_overworld", {
    description = "Portal to Overworld",
    tiles = {"default_obsidian.png^[colorize:#FFFFFF:80"},
    drawtype = "glasslike",
    paramtype = "light",
    light_source = 14,
    groups = {cracky = 1, not_in_creative_inventory = 1},
    sounds = default.node_sound_glass_defaults(),
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        if player and oh.teleport_to_overworld then
            oh.teleport_to_overworld(player)
        end
    end,
})

minetest.register_node("obelisk_analog:portal_endless_house", {
    description = "Portal to The Endless House",
    tiles = {"default_obsidian.png^[colorize:#FFD700:80"},
    drawtype = "glasslike",
    paramtype = "light",
    light_source = C.LIGHT.PORTAL_GLOW,
    groups = {cracky = 1, not_in_creative_inventory = 1},
    sounds = default.node_sound_glass_defaults(),
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        if player and oh.teleport_to_dimension then
            oh.teleport_to_dimension(player, "endless_house")
        end
    end,
})

minetest.register_node("obelisk_analog:dead_leaves", {
    description = "Dead Leaves",
    drawtype = "allfaces_optional",
    tiles = {"default_dry_shrub.png"},
    paramtype = "light",
    groups = {snappy = 3, not_in_creative_inventory = 1},
    sounds = default.node_sound_leaves_defaults(),
})

minetest.register_craftitem("obelisk_analog:portal_key_sequence", {
    description = "Key to The Sequence",
    inventory_image = "default_key.png^[colorize:#0000FF:100",
    stack_max = 1,
    groups = {not_in_creative_inventory = 1},
})

minetest.register_craftitem("obelisk_analog:portal_key_wonderland", {
    description = "Key to Wonderland",
    inventory_image = "default_key.png^[colorize:#00FF00:100",
    stack_max = 1,
    groups = {not_in_creative_inventory = 1},
})

minetest.register_craftitem("obelisk_analog:portal_key_corners", {
    description = "Key to The Corners",
    inventory_image = "default_key.png^[colorize:#FF0000:100",
    stack_max = 1,
    groups = {not_in_creative_inventory = 1},
})

minetest.register_craftitem("obelisk_analog:portal_key_endless_house", {
    description = "Key to The Endless House",
    inventory_image = "default_key.png^[colorize:#FFD700:120",
    stack_max = 1,
    groups = {not_in_creative_inventory = 1},
})

minetest.register_craftitem("obelisk_analog:key_fragment", {
    description = "Mysterious Key Fragment",
    inventory_image = "default_flint.png^[colorize:#4B0082:150",
    stack_max = 99,
})

minetest.register_craft({
    output = "obelisk_analog:portal_key_sequence",
    recipe = {
        {"obelisk_analog:key_fragment", "obelisk_analog:key_fragment", "obelisk_analog:key_fragment"},
        {"obelisk_analog:key_fragment", "default:mese_crystal", "obelisk_analog:key_fragment"},
        {"", "default:obsidian", ""},
    },
})

minetest.register_craft({
    output = "obelisk_analog:portal_key_wonderland",
    recipe = {
        {"obelisk_analog:key_fragment", "obelisk_analog:key_fragment", "obelisk_analog:key_fragment"},
        {"obelisk_analog:key_fragment", "default:diamond", "obelisk_analog:key_fragment"},
        {"obelisk_analog:key_fragment", "default:obsidian", "obelisk_analog:key_fragment"},
    },
})

minetest.register_craft({
    output = "obelisk_analog:portal_key_corners",
    recipe = {
        {"obelisk_analog:key_fragment", "obelisk_analog:key_fragment", "obelisk_analog:key_fragment"},
        {"obelisk_analog:key_fragment", "default:mese_crystal", "obelisk_analog:key_fragment"},
        {"obelisk_analog:key_fragment", "default:diamond", "obelisk_analog:key_fragment"},
    },
})

minetest.register_craft({
    output = "obelisk_analog:portal_key_endless_house",
    recipe = {
        {"obelisk_analog:key_fragment", "obelisk_analog:key_fragment", "obelisk_analog:key_fragment"},
        {"obelisk_analog:key_fragment", "default:gold_ingot", "obelisk_analog:key_fragment"},
        {"", "default:obsidian", ""},
    },
})

local key_drop_nodes = {
    "default:stone_with_coal",
    "default:stone_with_iron",
    "default:stone_with_copper",
    "default:stone_with_gold",
    "default:stone_with_mese",
    "default:stone_with_diamond",
    "default:obsidian",
    "default:mese",
}

for _, node_name in ipairs(key_drop_nodes) do
    local original_def = minetest.registered_nodes[node_name]
    if original_def then
        local original_after_dig = original_def.after_dig_node

        minetest.override_item(node_name, {
            after_dig_node = function(pos, oldnode, oldmetadata, digger)
                if original_after_dig then
                    original_after_dig(pos, oldnode, oldmetadata, digger)
                end

                if not digger or not digger:is_player() then return end

                local drop_chance = 0.005
                if node_name:find("mese") then drop_chance = 0.02 end
                if node_name:find("diamond") then drop_chance = 0.03 end
                if node_name == "default:obsidian" then drop_chance = 0.015 end

                if oh.current_phase then
                    drop_chance = drop_chance * (1 + oh.current_phase * 0.1)
                end

                if math.random() < drop_chance then
                    local inv = digger:get_inventory()
                    if inv then
                        local roll = math.random()
                        if roll < 0.7 then
                            inv:add_item("main", "obelisk_analog:key_fragment")
                            minetest.chat_send_player(digger:get_player_name(),
                                minetest.colorize("#4B0082", "You found a mysterious fragment..."))
                        elseif roll < 0.9 then
                            inv:add_item("main", "obelisk_analog:key_fragment 2")
                            minetest.chat_send_player(digger:get_player_name(),
                                minetest.colorize("#4B0082", "Strange fragments tumble from the rock..."))
                        else
                            local keys = {
                                "obelisk_analog:portal_key_sequence",
                                "obelisk_analog:portal_key_wonderland",
                                "obelisk_analog:portal_key_corners",
                            }
                            local key = keys[math.random(#keys)]
                            inv:add_item("main", key)
                            minetest.chat_send_player(digger:get_player_name(),
                                minetest.colorize("#FF4500", "A complete key materializes from the darkness!"))
                            if oh.play_sound then
                                oh.play_sound(digger, "obelisk_analog_random_voice", 0.5)
                            end
                        end

                        oh.create_particles(pos, "default_obsidian.png^[colorize:#4B0082:150", 15, 0.5, {
                            minvel = {x = -1, y = 0.5, z = -1},
                            maxvel = {x = 1, y = 2, z = 1},
                            glow = 5,
                        })
                    end
                end
            end,
        })
    end
end

minetest.register_node("obelisk_analog:mysterious_ore", {
    description = "Mysterious Ore",
    tiles = {"default_stone.png^[colorize:#2a0050:100"},
    paramtype = "light",
    light_source = 3,
    groups = {cracky = 2},
    drop = {
        max_items = 2,
        items = {
            {items = {"obelisk_analog:key_fragment 3"}, rarity = 1},
            {items = {"obelisk_analog:key_fragment 2"}, rarity = 2},
            {items = {"obelisk_analog:portal_key_sequence"}, rarity = 15},
            {items = {"obelisk_analog:portal_key_wonderland"}, rarity = 20},
            {items = {"obelisk_analog:portal_key_corners"}, rarity = 30},
        },
    },
    sounds = default.node_sound_stone_defaults(),
})

minetest.register_ore({
    ore_type = "scatter",
    ore = "obelisk_analog:mysterious_ore",
    wherein = "default:stone",
    clust_scarcity = 20 * 20 * 20,
    clust_num_ores = 2,
    clust_size = 3,
    y_max = -64,
    y_min = -31000,
})

local function show_note_formspec(player, title, text, hint)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    local esc = minetest.formspec_escape
    local body = esc(text or "")
    local head = esc(title or "Note")
    local sub = hint and ("\n\n" .. esc(hint)) or ""

    local formspec = "formspec_version[4]" ..
        "size[12,9]" ..
        "label[0.6,0.4;" .. head .. "]" ..
        "textarea[0.6,1.2;11.0,7.0;text;;" .. body .. sub .. "]" ..
        "button_exit[4.5,8.2;3,0.8;ok;Close]"

    minetest.show_formspec(name, "obelisk_analog:note", formspec)
end

minetest.register_craftitem("obelisk_analog:note", {
    description = "Note",
    inventory_image = "default_paper.png",
    stack_max = 1,
    on_use = function(itemstack, user, pointed_thing)
        local meta = itemstack:get_meta()
        show_note_formspec(user, meta:get_string("title"), meta:get_string("text"), nil)
        return itemstack
    end,
})

minetest.register_craftitem("obelisk_analog:encoded_note", {
    description = "Encoded Note",
    inventory_image = "default_paper.png^[colorize:#4B0082:80",
    stack_max = 1,
    on_use = function(itemstack, user, pointed_thing)
        local meta = itemstack:get_meta()
        show_note_formspec(user, meta:get_string("title"), meta:get_string("text"), meta:get_string("hint"))
        return itemstack
    end,
})
