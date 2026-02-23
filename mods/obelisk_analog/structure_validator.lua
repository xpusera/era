local oh = obelisk_analog
local C = oh.C
local random, floor, abs = math.random, math.floor, math.abs

oh.structure_registry = {}

local function clear_area(pos, width, depth, height, margin)
    margin = margin or 3
    local min_x = pos.x - margin
    local max_x = pos.x + width + margin
    local min_z = pos.z - margin
    local max_z = pos.z + depth + margin
    local min_y = pos.y - 2
    local max_y = pos.y + height + margin

    for x = min_x, max_x do
        for z = min_z, max_z do
            for y = min_y, max_y do
                local node = minetest.get_node({x = x, y = y, z = z})
                if node.name ~= "air" and node.name ~= "ignore" then
                    local is_ground = y < pos.y
                    if is_ground then
                        minetest.set_node({x = x, y = y, z = z}, {name = "default:dirt"})
                    else
                        minetest.set_node({x = x, y = y, z = z}, {name = "air"})
                    end
                end
            end
        end
    end

    for x = min_x, max_x do
        for z = min_z, max_z do
            minetest.set_node({x = x, y = pos.y - 1, z = z}, {name = "default:dirt_with_grass"})
        end
    end
end

local function remove_nearby_trees(pos, radius, height)
    height = height or 15
    local tree_nodes = {"default:tree", "default:leaves", "default:apple"}

    for dx = -radius, radius do
        for dz = -radius, radius do
            for dy = -2, height do
                local check_pos = {x = pos.x + dx, y = pos.y + dy, z = pos.z + dz}
                local node = minetest.get_node(check_pos)

                for _, tree_node in ipairs(tree_nodes) do
                    if node.name == tree_node then
                        minetest.set_node(check_pos, {name = "air"})
                        break
                    end
                end
            end
        end
    end
end

local function validate_structure_walls(pos, width, depth, height, wall_node)
    local missing_walls = 0
    local total_walls = 0

    for y = 1, height do
        for x = 0, width do
            total_walls = total_walls + 2
            local front = minetest.get_node({x = pos.x + x, y = pos.y + y, z = pos.z})
            local back = minetest.get_node({x = pos.x + x, y = pos.y + y, z = pos.z + depth})
            if front.name == "air" then missing_walls = missing_walls + 1 end
            if back.name == "air" then missing_walls = missing_walls + 1 end
        end
        for z = 0, depth do
            total_walls = total_walls + 2
            local left = minetest.get_node({x = pos.x, y = pos.y + y, z = pos.z + z})
            local right = minetest.get_node({x = pos.x + width, y = pos.y + y, z = pos.z + z})
            if left.name == "air" then missing_walls = missing_walls + 1 end
            if right.name == "air" then missing_walls = missing_walls + 1 end
        end
    end

    if total_walls == 0 then
        return 1
    end
    local integrity = 1 - (missing_walls / total_walls)
    return integrity
end

local function repair_structure_walls(pos, width, depth, height, wall_node, integrity_target)
    integrity_target = integrity_target or 0.7

    for y = 1, height do
        for x = 0, width do
            local front_pos = {x = pos.x + x, y = pos.y + y, z = pos.z}
            local back_pos = {x = pos.x + x, y = pos.y + y, z = pos.z + depth}

            if minetest.get_node(front_pos).name == "air" and random() < integrity_target then
                minetest.set_node(front_pos, {name = wall_node})
            end
            if minetest.get_node(back_pos).name == "air" and random() < integrity_target then
                minetest.set_node(back_pos, {name = wall_node})
            end
        end
        for z = 0, depth do
            local left_pos = {x = pos.x, y = pos.y + y, z = pos.z + z}
            local right_pos = {x = pos.x + width, y = pos.y + y, z = pos.z + z}

            if minetest.get_node(left_pos).name == "air" and random() < integrity_target then
                minetest.set_node(left_pos, {name = wall_node})
            end
            if minetest.get_node(right_pos).name == "air" and random() < integrity_target then
                minetest.set_node(right_pos, {name = wall_node})
            end
        end
    end
end

local function repair_structure_floor(pos, width, depth, floor_node)
    for x = 0, width do
        for z = 0, depth do
            local floor_pos = {x = pos.x + x, y = pos.y, z = pos.z + z}
            local node = minetest.get_node(floor_pos)
            if node.name == "air" or node.name == "default:dirt" or node.name == "default:dirt_with_grass" then
                minetest.set_node(floor_pos, {name = floor_node})
            end
        end
    end
end

local function repair_structure_roof(pos, width, depth, height, roof_node, coverage)
    coverage = coverage or 0.75
    for x = 0, width do
        for z = 0, depth do
            local roof_pos = {x = pos.x + x, y = pos.y + height, z = pos.z + z}
            if minetest.get_node(roof_pos).name == "air" and random() < coverage then
                minetest.set_node(roof_pos, {name = roof_node})
            end
        end
    end
end

local function ensure_interior_clear(pos, width, depth, height)
    for x = 1, width - 1 do
        for z = 1, depth - 1 do
            for y = 1, height - 1 do
                local interior_pos = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
                local node = minetest.get_node(interior_pos)
                if node.name ~= "air" and 
                   node.name ~= "default:chest" and 
                   node.name ~= "default:torch_wall" and
                   node.name ~= "default:torch" and
                   not node.name:find("portal") then
                    minetest.set_node(interior_pos, {name = "air"})
                end
            end
        end
    end
end

function oh.register_structure(id, pos, params)
    oh.structure_registry[id] = {
        pos = pos,
        params = params,
        created_at = minetest.get_gametime(),
        repaired = false,
    }
end

function oh.validate_and_repair_structure(id)
    local struct = oh.structure_registry[id]
    if not struct then return false end

    local pos = struct.pos
    local params = struct.params

    remove_nearby_trees(pos, params.width + 5, params.height + 5)

    ensure_interior_clear(pos, params.width, params.depth, params.height)

    local integrity = validate_structure_walls(pos, params.width, params.depth, params.height, params.wall_node)

    if integrity < 0.5 then
        repair_structure_walls(pos, params.width, params.depth, params.height, params.wall_node, 0.85)
    end

    repair_structure_floor(pos, params.width, params.depth, params.floor_node)
    repair_structure_roof(pos, params.width, params.depth, params.height, params.roof_node, 0.75)

    if params.door_pos then
        minetest.set_node({x = params.door_pos.x, y = params.door_pos.y, z = params.door_pos.z}, {name = "air"})
        minetest.set_node({x = params.door_pos.x, y = params.door_pos.y + 1, z = params.door_pos.z}, {name = "air"})
        if params.door_width and params.door_width > 1 then
            minetest.set_node({x = params.door_pos.x + 1, y = params.door_pos.y, z = params.door_pos.z}, {name = "air"})
            minetest.set_node({x = params.door_pos.x + 1, y = params.door_pos.y + 1, z = params.door_pos.z}, {name = "air"})
        end
    end

    struct.repaired = true
    return true
end

function oh.schedule_structure_repair(id, delay)
    delay = delay or 2

    minetest.after(delay, function()
        oh.validate_and_repair_structure(id)
    end)

    minetest.after(delay + 3, function()
        oh.validate_and_repair_structure(id)
    end)
end

function oh.build_house_with_validation(pos, dimension)
    local width = 8
    local depth = 10
    local height = 5

    clear_area(pos, width, depth, height, 4)
    remove_nearby_trees(pos, width + 6, height + 8)

    minetest.after(0.5, function()
        local floor_y = pos.y

        for x = 0, width do
            for z = 0, depth do
                minetest.set_node({x = pos.x + x, y = floor_y, z = pos.z + z}, {name = "default:wood"})
            end
        end

        for y = 1, height do
            for x = 0, width do
                if random() > 0.15 then
                    minetest.set_node({x = pos.x + x, y = floor_y + y, z = pos.z}, {name = "default:wood"})
                end
                if random() > 0.15 then
                    minetest.set_node({x = pos.x + x, y = floor_y + y, z = pos.z + depth}, {name = "default:wood"})
                end
            end
            for z = 0, depth do
                if random() > 0.15 then
                    minetest.set_node({x = pos.x, y = floor_y + y, z = pos.z + z}, {name = "default:wood"})
                end
                if random() > 0.15 then
                    minetest.set_node({x = pos.x + width, y = floor_y + y, z = pos.z + z}, {name = "default:wood"})
                end
            end
        end

        for x = 0, width do
            for z = 0, depth do
                if random() > 0.25 then
                    minetest.set_node({x = pos.x + x, y = floor_y + height, z = pos.z + z}, {name = "default:wood"})
                end
            end
        end

        local door_x = pos.x + floor(width / 2)
        minetest.set_node({x = door_x, y = floor_y + 1, z = pos.z}, {name = "air"})
        minetest.set_node({x = door_x, y = floor_y + 2, z = pos.z}, {name = "air"})
        minetest.set_node({x = door_x + 1, y = floor_y + 1, z = pos.z}, {name = "air"})
        minetest.set_node({x = door_x + 1, y = floor_y + 2, z = pos.z}, {name = "air"})

        minetest.set_node({x = pos.x + 2, y = floor_y + 2, z = pos.z + depth}, {name = "default:glass"})
        minetest.set_node({x = pos.x + width - 2, y = floor_y + 2, z = pos.z + depth}, {name = "default:glass"})
        minetest.set_node({x = pos.x, y = floor_y + 2, z = pos.z + floor(depth/2)}, {name = "default:glass"})

        oh.place_wallmounted("default:torch_wall", {x = pos.x + 1, y = floor_y + 2, z = pos.z + 1}, {
            {x = -1, y = 0, z = 0},
            {x = 0, y = 0, z = -1},
            {x = 1, y = 0, z = 0},
            {x = 0, y = 0, z = 1},
        })
        oh.place_wallmounted("default:torch_wall", {x = pos.x + width - 1, y = floor_y + 2, z = pos.z + depth - 1}, {
            {x = 1, y = 0, z = 0},
            {x = 0, y = 0, z = 1},
            {x = -1, y = 0, z = 0},
            {x = 0, y = 0, z = -1},
        })

        if dimension == "wonderland" then
            minetest.set_node({x = pos.x + floor(width/2), y = floor_y + 1, z = pos.z + depth - 2}, {name = "obelisk_analog:portal_corners"})
        end

        local chest_pos = {x = pos.x + width - 1, y = floor_y + 1, z = pos.z + depth - 1}
        minetest.set_node(chest_pos, {name = "default:chest"})
        local meta = minetest.get_meta(chest_pos)
        local inv = meta:get_inventory()
        inv:set_size("main", 32)
        if oh.fill_loot_chest then
            oh.fill_loot_chest(inv, "dimension_chest")
        else
            inv:add_item("main", "default:torch 5")
            inv:add_item("main", "default:apple 3")
            if random() > 0.5 then
                inv:add_item("main", "default:book")
            end
        end

        local struct_id = minetest.pos_to_string(pos)
        oh.register_structure(struct_id, pos, {
            width = width,
            depth = depth,
            height = height,
            wall_node = "default:wood",
            floor_node = "default:wood",
            roof_node = "default:wood",
            door_pos = {x = door_x, y = floor_y + 1, z = pos.z},
            door_width = 2,
        })

        oh.schedule_structure_repair(struct_id, 1)
    end)
end

minetest.register_chatcommand("horror_repair_structures", {
    privs = {server = true},
    description = "Repair all registered structures",
    func = function(name)
        local count = 0
        for id, _ in pairs(oh.structure_registry) do
            oh.validate_and_repair_structure(id)
            count = count + 1
        end
        return true, "Repaired " .. count .. " structures"
    end,
})

minetest.register_chatcommand("horror_spawn_validated_house", {
    privs = {server = true},
    description = "Spawn a validated house at your position",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            local pos = player:get_pos()
            pos.y = floor(pos.y)
            oh.build_house_with_validation(pos, "overworld")
            return true, "Validated house spawned - will auto-repair"
        end
        return false, "Player not found"
    end,
})
