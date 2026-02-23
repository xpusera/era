local oh = obelisk_analog
local C = oh.C
local random, floor = math.random, math.floor

local common_loot = {
    {item = "default:torch", min = 2, max = 8, weight = 10},
    {item = "default:apple", min = 1, max = 5, weight = 8},
    {item = "default:paper", min = 1, max = 4, weight = 6},
    {item = "default:book", min = 1, max = 2, weight = 4},
    {item = "default:stick", min = 2, max = 10, weight = 8},
    {item = "default:coal_lump", min = 2, max = 8, weight = 6},
    {item = "default:flint", min = 1, max = 4, weight = 5},
}

local uncommon_loot = {
    {item = "default:pick_stone", min = 1, max = 1, weight = 5},
    {item = "default:sword_stone", min = 1, max = 1, weight = 4},
    {item = "default:axe_stone", min = 1, max = 1, weight = 5},
    {item = "default:shovel_stone", min = 1, max = 1, weight = 5},
    {item = "default:pick_steel", min = 1, max = 1, weight = 3},
    {item = "default:sword_steel", min = 1, max = 1, weight = 2},
    {item = "default:steel_ingot", min = 1, max = 4, weight = 4},
    {item = "default:gold_ingot", min = 1, max = 2, weight = 2},
    {item = "default:mese_crystal", min = 1, max = 2, weight = 2},
    {item = "default:obsidian", min = 1, max = 4, weight = 3},
    {item = "default:ladder_steel", min = 2, max = 6, weight = 3},
}

local rare_loot = {
    {item = "default:pick_mese", min = 1, max = 1, weight = 2},
    {item = "default:sword_mese", min = 1, max = 1, weight = 2},
    {item = "default:diamond", min = 1, max = 2, weight = 2},
    {item = "default:meselamp", min = 1, max = 3, weight = 3},
    {item = "obelisk_analog:portal_key_sequence", min = 1, max = 1, weight = 3},
    {item = "obelisk_analog:portal_key_wonderland", min = 1, max = 1, weight = 2},
    {item = "obelisk_analog:portal_key_corners", min = 1, max = 1, weight = 1},
    {item = "obelisk_analog:portal_key_endless_house", min = 1, max = 1, weight = 1},
}

local loot_tables = {
    abandoned_house = {
        common = {count = {2, 4}, chance = 1.0},
        uncommon = {count = {1, 2}, chance = 0.5},
        rare = {count = {0, 1}, chance = 0.15},
    },
    ruined_tower = {
        common = {count = {1, 3}, chance = 0.8},
        uncommon = {count = {1, 3}, chance = 0.7},
        rare = {count = {1, 1}, chance = 0.4},
    },
    ritual_chest = {
        common = {count = {1, 2}, chance = 0.5},
        uncommon = {count = {1, 2}, chance = 0.6},
        rare = {count = {1, 2}, chance = 0.5},
    },
    dimension_chest = {
        common = {count = {2, 5}, chance = 1.0},
        uncommon = {count = {2, 4}, chance = 0.9},
        rare = {count = {1, 2}, chance = 0.3},
    },
}

local function weighted_random(loot_list)
    local total = 0
    for _, entry in ipairs(loot_list) do
        total = total + entry.weight
    end

    local roll = random() * total
    local cumulative = 0

    for _, entry in ipairs(loot_list) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry
        end
    end

    return loot_list[1]
end

function oh.fill_loot_chest(inv, table_name)
    local table_def = loot_tables[table_name] or loot_tables.abandoned_house

    if random() <= table_def.common.chance then
        local count = random(table_def.common.count[1], table_def.common.count[2])
        for i = 1, count do
            local entry = weighted_random(common_loot)
            local amount = random(entry.min, entry.max)
            inv:add_item("main", entry.item .. " " .. amount)
        end
    end

    if random() <= table_def.uncommon.chance then
        local count = random(table_def.uncommon.count[1], table_def.uncommon.count[2])
        for i = 1, count do
            local entry = weighted_random(uncommon_loot)
            local amount = random(entry.min, entry.max)
            inv:add_item("main", entry.item .. " " .. amount)
        end
    end

    if random() <= table_def.rare.chance then
        local count = random(table_def.rare.count[1], table_def.rare.count[2])
        for i = 1, count do
            local entry = weighted_random(rare_loot)
            local amount = random(entry.min, entry.max)
            inv:add_item("main", entry.item .. " " .. amount)
        end
    end

    local phase = oh.current_phase or 1
    local note_chance = 0.12
    if table_name == "dimension_chest" then note_chance = 0.25 end
    if table_name == "ritual_chest" then note_chance = 0.2 end
    note_chance = note_chance * (1 + (phase - 1) * 0.12)

    if random() < note_chance then
        local kind = (random() < (0.25 + phase * 0.08)) and "encoded" or "note"
        local seed = minetest.get_gametime() + random(1, 999999)
        local st = oh.make_note_stack(kind == "encoded" and "encoded" or "note", seed)
        local list = inv:get_list("main")
        for i = 1, #list do
            if list[i]:is_empty() then
                inv:set_stack("main", i, st)
                break
            end
        end
    end
end

local function find_surface_pos(x, z)
    for y = 100, -20, -1 do
        local node = minetest.get_node({x = x, y = y, z = z})
        local above = minetest.get_node({x = x, y = y + 1, z = z})
        if node.name ~= "air" and node.name ~= "ignore" and above.name == "air" then
            return {x = x, y = y + 1, z = z}
        end
    end
    return nil
end

local function generate_abandoned_house(pos)
    if oh.build_house_with_validation then
        oh.build_house_with_validation(pos, "overworld")
        minetest.log("action", "[obelisk_analog] Validated house generated at " .. minetest.pos_to_string(pos))
        return
    end

    local width = random(5, 8)
    local depth = random(6, 10)
    local height = random(4, 6)
    local base_y = pos.y

    for x = pos.x, pos.x + width do
        for z = pos.z, pos.z + depth do
            minetest.set_node({x = x, y = base_y, z = z}, {name = "default:wood"})
        end
    end

    for y = base_y + 1, base_y + height do
        for x = pos.x, pos.x + width do
            if random() > 0.1 then
                minetest.set_node({x = x, y = y, z = pos.z}, {name = "default:wood"})
            end
            if random() > 0.1 then
                minetest.set_node({x = x, y = y, z = pos.z + depth}, {name = "default:wood"})
            end
        end
        for z = pos.z, pos.z + depth do
            if random() > 0.1 then
                minetest.set_node({x = pos.x, y = y, z = z}, {name = "default:wood"})
            end
            if random() > 0.1 then
                minetest.set_node({x = pos.x + width, y = y, z = z}, {name = "default:wood"})
            end
        end
    end

    for x = pos.x, pos.x + width do
        for z = pos.z, pos.z + depth do
            if random() > 0.2 then
                minetest.set_node({x = x, y = base_y + height, z = z}, {name = "default:wood"})
            end
        end
    end

    local door_x = pos.x + floor(width / 2)
    minetest.set_node({x = door_x, y = base_y + 1, z = pos.z}, {name = "air"})
    minetest.set_node({x = door_x, y = base_y + 2, z = pos.z}, {name = "air"})

    local window_y = base_y + 2
    if random() > 0.3 then
        minetest.set_node({x = pos.x + 2, y = window_y, z = pos.z + depth}, {name = "default:glass"})
    end
    if random() > 0.3 then
        minetest.set_node({x = pos.x + width - 2, y = window_y, z = pos.z + depth}, {name = "default:glass"})
    end

    local chest_pos = {x = pos.x + width - 1, y = base_y + 1, z = pos.z + depth - 1}
    minetest.set_node(chest_pos, {name = "default:chest"})
    local meta = minetest.get_meta(chest_pos)
    local inv = meta:get_inventory()
    inv:set_size("main", 32)

    oh.fill_loot_chest(inv, "abandoned_house")

    if random() > 0.5 then
        oh.place_wallmounted("default:torch_wall", {x = pos.x + 1, y = base_y + 2, z = pos.z + 1}, {
            {x = -1, y = 0, z = 0},
            {x = 0, y = 0, z = -1},
            {x = 1, y = 0, z = 0},
            {x = 0, y = 0, z = 1},
        })
    end

    minetest.log("action", "[obelisk_analog] Abandoned house generated at " .. minetest.pos_to_string(pos))
end

local function generate_creepy_shrine(pos)
    local base_y = pos.y

    for x = pos.x - 2, pos.x + 2 do
        for z = pos.z - 2, pos.z + 2 do
            minetest.set_node({x = x, y = base_y, z = z}, {name = "obelisk_analog:shrine_block"})
        end
    end

    local corners = {{-2, -2}, {2, -2}, {-2, 2}, {2, 2}}
    for _, c in ipairs(corners) do
        minetest.set_node({x = pos.x + c[1], y = base_y + 1, z = pos.z + c[2]}, {name = "obelisk_analog:shrine_block"})
        minetest.set_node({x = pos.x + c[1], y = base_y + 2, z = pos.z + c[2]}, {name = "default:torch"})
    end

    minetest.set_node({x = pos.x, y = base_y + 1, z = pos.z}, {name = "obelisk_analog:ritual_stone"})

    minetest.log("action", "[obelisk_analog] Creepy shrine generated at " .. minetest.pos_to_string(pos))
end

local function generate_warning_sign(pos)
    minetest.set_node({x = pos.x, y = pos.y, z = pos.z}, {name = "default:fence_wood"})
    minetest.set_node({x = pos.x, y = pos.y + 1, z = pos.z}, {name = "default:fence_wood"})
    minetest.set_node({x = pos.x, y = pos.y + 2, z = pos.z}, {name = "obelisk_analog:warning_sign", param2 = random(0, 3)})
end

local function generate_ritual_circle(pos)
    local base_y = pos.y
    local radius = 4

    for angle = 0, 2 * math.pi, math.pi / 8 do
        local x = pos.x + floor(math.cos(angle) * radius + 0.5)
        local z = pos.z + floor(math.sin(angle) * radius + 0.5)
        minetest.set_node({x = x, y = base_y, z = z}, {name = "obelisk_analog:ritual_stone"})
    end

    minetest.set_node({x = pos.x, y = base_y, z = pos.z}, {name = "obelisk_analog:portal_activator", param2 = 0})

    for i = 1, 4 do
        local angle = (i - 1) * math.pi / 2
        local x = pos.x + floor(math.cos(angle) * 2 + 0.5)
        local z = pos.z + floor(math.sin(angle) * 2 + 0.5)
        minetest.set_node({x = x, y = base_y + 1, z = z}, {name = "default:torch"})
    end

    minetest.log("action", "[obelisk_analog] Ritual circle generated at " .. minetest.pos_to_string(pos))
end

local function generate_grave_site(pos)
    local base_y = pos.y

    for i = 1, random(3, 6) do
        local gx = pos.x + random(-5, 5)
        local gz = pos.z + random(-5, 5)
        minetest.set_node({x = gx, y = base_y, z = gz}, {name = "default:dirt"})
        minetest.set_node({x = gx, y = base_y + 1, z = gz}, {name = "default:cobble"})
    end

    minetest.set_node({x = pos.x, y = base_y, z = pos.z}, {name = "default:dirt"})
    minetest.set_node({x = pos.x, y = base_y + 1, z = pos.z}, {name = "default:cobble"})
    minetest.set_node({x = pos.x, y = base_y + 2, z = pos.z}, {name = "default:cobble"})
end

local function generate_ruined_tower(pos)
    local base_y = pos.y
    local height = random(8, 15)
    local radius = 3

    for y = base_y, base_y + height do
        local decay = (y - base_y) / height
        for angle = 0, 2 * math.pi, math.pi / 4 do
            if random() > decay * 0.5 then
                local x = pos.x + floor(math.cos(angle) * radius + 0.5)
                local z = pos.z + floor(math.sin(angle) * radius + 0.5)
                minetest.set_node({x = x, y = y, z = z}, {name = "default:cobble"})
            end
        end
    end

    for y = base_y + 1, base_y + height - 2, 3 do
        minetest.set_node({x = pos.x + radius, y = y, z = pos.z}, {name = "air"})
    end

    if random() > 0.4 then
        local chest_y = base_y + height - 3
        minetest.set_node({x = pos.x, y = chest_y, z = pos.z}, {name = "default:chest"})
        local meta = minetest.get_meta({x = pos.x, y = chest_y, z = pos.z})
        local inv = meta:get_inventory()
        inv:set_size("main", 32)
        oh.fill_loot_chest(inv, "ruined_tower")
    end

    minetest.log("action", "[obelisk_analog] Ruined tower generated at " .. minetest.pos_to_string(pos))
end

local function generate_creepy_well(pos)
    local base_y = pos.y

    for x = pos.x - 1, pos.x + 1 do
        for z = pos.z - 1, pos.z + 1 do
            if not (x == pos.x and z == pos.z) then
                minetest.set_node({x = x, y = base_y, z = z}, {name = "default:cobble"})
                minetest.set_node({x = x, y = base_y + 1, z = z}, {name = "default:cobble"})
            end
        end
    end

    for y = base_y - 10, base_y - 1 do
        minetest.set_node({x = pos.x, y = y, z = pos.z}, {name = "air"})
    end

    minetest.set_node({x = pos.x - 1, y = base_y + 2, z = pos.z}, {name = "default:fence_wood"})
    minetest.set_node({x = pos.x + 1, y = base_y + 2, z = pos.z}, {name = "default:fence_wood"})
    minetest.set_node({x = pos.x - 1, y = base_y + 3, z = pos.z}, {name = "default:wood"})
    minetest.set_node({x = pos.x, y = base_y + 3, z = pos.z}, {name = "default:wood"})
    minetest.set_node({x = pos.x + 1, y = base_y + 3, z = pos.z}, {name = "default:wood"})
end

minetest.register_on_generated(function(minp, maxp, blockseed)
    if minp.y > 100 or maxp.y < -20 then return end
    if oh.is_in_dimension(minp) then return end

    math.randomseed(blockseed)

    local structures = {
        {chance = C.STRUCTURE.HOUSE_SPAWN_CHANCE, func = generate_abandoned_house, margin = 10},
        {chance = C.STRUCTURE.SHRINE_SPAWN_CHANCE, func = generate_creepy_shrine, margin = 5},
        {chance = C.STRUCTURE.SIGN_SPAWN_CHANCE, func = generate_warning_sign, margin = 0},
        {chance = C.STRUCTURE.RITUAL_SPAWN_CHANCE, func = generate_ritual_circle, margin = 10},
        {chance = C.STRUCTURE.GRAVE_SPAWN_CHANCE, func = generate_grave_site, margin = 5},
        {chance = C.STRUCTURE.TOWER_SPAWN_CHANCE, func = generate_ruined_tower, margin = 5},
        {chance = C.STRUCTURE.WELL_SPAWN_CHANCE, func = generate_creepy_well, margin = 3},
    }

    for _, struct in ipairs(structures) do
        if random() < struct.chance then
            local x = random(minp.x + struct.margin, maxp.x - struct.margin)
            local z = random(minp.z + struct.margin, maxp.z - struct.margin)
            local pos = find_surface_pos(x, z)
            if pos then
                struct.func(pos)
            end
        end
    end
end)

minetest.register_chatcommand("horror_spawn_house", {
    privs = {server = true},
    description = "Spawn an abandoned house at your position",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            local pos = player:get_pos()
            pos.y = floor(pos.y)
            generate_abandoned_house(pos)
            return true, "Abandoned house spawned"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_spawn_shrine", {
    privs = {server = true},
    description = "Spawn a creepy shrine at your position",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            local pos = player:get_pos()
            pos.y = floor(pos.y)
            generate_creepy_shrine(pos)
            return true, "Creepy shrine spawned"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_spawn_ritual", {
    privs = {server = true},
    description = "Spawn a ritual circle at your position",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            local pos = player:get_pos()
            pos.y = floor(pos.y)
            generate_ritual_circle(pos)
            return true, "Ritual circle spawned"
        end
        return false, "Player not found"
    end,
})

minetest.register_chatcommand("horror_spawn_tower", {
    privs = {server = true},
    description = "Spawn a ruined tower at your position",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            local pos = player:get_pos()
            pos.y = floor(pos.y)
            generate_ruined_tower(pos)
            return true, "Ruined tower spawned"
        end
        return false, "Player not found"
    end,
})
