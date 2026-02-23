local oh = obelisk_analog
local C = oh.C
local random, floor, abs = math.random, math.floor, math.abs
local vec_add, vec_sub = vector.add, vector.subtract

oh.dimensions = {
    sequence = {
        y_min = C.DIMENSION.SEQUENCE_Y,
        y_max = C.DIMENSION.SEQUENCE_Y + C.DIMENSION.HEIGHT,
        spawn_y = C.DIMENSION.SEQUENCE_Y + 2,
    },
    wonderland = {
        y_min = C.DIMENSION.WONDERLAND_Y,
        y_max = C.DIMENSION.WONDERLAND_Y + C.DIMENSION.HEIGHT,
        spawn_y = C.DIMENSION.WONDERLAND_Y + 3,
    },
    corners = {
        y_min = C.DIMENSION.CORNERS_Y,
        y_max = C.DIMENSION.CORNERS_Y + C.DIMENSION.HEIGHT,
        spawn_y = C.DIMENSION.CORNERS_Y + 3,
    },
    endless_house = {
        y_min = C.DIMENSION.ENDLESS_HOUSE_Y,
        y_max = C.DIMENSION.ENDLESS_HOUSE_Y + C.DIMENSION.HEIGHT,
        spawn_y = C.DIMENSION.ENDLESS_HOUSE_Y + 4,
    },
}

local content_ids = {}

local function get_content_id(name)
    if not content_ids[name] then
        content_ids[name] = minetest.get_content_id(name)
    end
    return content_ids[name]
end

local function init_content_ids()
    local nodes = {
        "air", "default:brick", "default:glass", "default:dirt_with_grass",
        "default:dirt", "default:tree", "default:leaves", "default:cobble",
        "default:mossycobble", "default:meselamp", "default:wood",
        "default:obsidian", "default:stonebrick", "default:furnace", "default:chest"
    }
    for _, name in ipairs(nodes) do
        get_content_id(name)
    end
end

minetest.after(0, init_content_ids)

local function is_in_dimension(y, dim_config)
    return y >= dim_config.y_min and y <= dim_config.y_max
end

local function hash_pos(x, y, z)
    return x * 73856093 + y * 19349663 + z * 83492791
end

local function seeded_random(seed, min, max)
    local rng = abs(seed) % 2147483647
    rng = (rng * 1103515245 + 12345) % 2147483647
    return min + (rng % (max - min + 1))
end

local function generate_sequence(minp, maxp, vm, area, data)
    local config = oh.dimensions.sequence
    local grid_size = C.GRID.SEQUENCE_SIZE
    local cube_height = C.GRID.SEQUENCE_CUBE_HEIGHT
    local line_width = 1

    local c_air = get_content_id("air")
    local c_brick = get_content_id("default:brick")

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local on_x_line = (x % grid_size) < line_width
            local on_z_line = (z % grid_size) < line_width
            local on_intersection = on_x_line and on_z_line

            for y = minp.y, maxp.y do
                if is_in_dimension(y, config) then
                    local vi = area:index(x, y, z)
                    local rel_y = y - config.y_min

                    local on_y_line = (rel_y % cube_height) < line_width
                    local at_vertical = on_intersection and rel_y <= cube_height * 3
                    local at_horizontal_floor = on_y_line and (on_x_line or on_z_line) and rel_y <= cube_height * 3

                    if at_vertical or at_horizontal_floor then
                        data[vi] = c_brick
                    else
                        data[vi] = c_air
                    end
                end
            end
        end
    end
end

local function generate_wonderland(minp, maxp, vm, area, data)
    local config = oh.dimensions.wonderland
    local tree_spacing = C.GRID.WONDERLAND_TREE_SPACING

    local c_air = get_content_id("air")
    local c_grass = get_content_id("default:dirt_with_grass")
    local c_dirt = get_content_id("default:dirt")
    local c_tree = get_content_id("default:tree")
    local c_leaves = get_content_id("default:leaves")

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local tree_x = floor((x + tree_spacing/2) / tree_spacing) * tree_spacing
            local tree_z = floor((z + tree_spacing/2) / tree_spacing) * tree_spacing

            local seed = hash_pos(tree_x, 0, tree_z)
            local has_tree = seeded_random(seed, 0, 4) ~= 0
            local tree_height = seeded_random(seed + 1, 5, 8)

            local dx = x - tree_x
            local dz = z - tree_z

            for y = minp.y, maxp.y do
                if is_in_dimension(y, config) then
                    local vi = area:index(x, y, z)
                    local rel_y = y - config.y_min

                    if rel_y < 1 then
                        data[vi] = c_dirt
                    elseif rel_y == 1 then
                        data[vi] = c_grass
                    elseif has_tree and dx == 0 and dz == 0 and rel_y >= 2 and rel_y <= tree_height + 1 then
                        data[vi] = c_tree
                    elseif has_tree and rel_y >= tree_height and rel_y <= tree_height + 3 then
                        local leaf_r = 3 - (rel_y - tree_height)
                        if leaf_r < 1 then leaf_r = 1 end
                        if abs(dx) <= leaf_r and abs(dz) <= leaf_r then
                            if not (dx == 0 and dz == 0 and rel_y < tree_height + 2) then
                                data[vi] = c_leaves
                            else
                                data[vi] = c_air
                            end
                        else
                            data[vi] = c_air
                        end
                    else
                        data[vi] = c_air
                    end
                end
            end
        end
    end
end

local function generate_corners(minp, maxp, vm, area, data)
    local config = oh.dimensions.corners
    local cell_size = C.GRID.CORNERS_CELL_SIZE
    local passage_width = C.GRID.CORNERS_PASSAGE_WIDTH
    local wall_height = C.GRID.CORNERS_WALL_HEIGHT
    local torch_spacing = 10
    local torch_height = 8

    local c_air = get_content_id("air")
    local c_cobble = get_content_id("default:cobble")
    local c_mossycobble = get_content_id("default:mossycobble")
    local c_meselamp = get_content_id("default:meselamp")

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local cell_x = floor(x / cell_size)
            local cell_z = floor(z / cell_size)
            local local_x = ((x % cell_size) + cell_size) % cell_size
            local local_z = ((z % cell_size) + cell_size) % cell_size

            local seed = hash_pos(cell_x, 0, cell_z)
            local has_moss = seeded_random(seed, 0, 3) == 0

            local pass_start = (cell_size - passage_width) / 2
            local pass_end = pass_start + passage_width - 1
            local in_pass_x = local_x >= pass_start and local_x <= pass_end
            local in_pass_z = local_z >= pass_start and local_z <= pass_end

            local on_wall = local_x == 0 or local_x == cell_size - 1 or local_z == 0 or local_z == cell_size - 1
            local is_passage = (local_x == 0 and in_pass_z) or (local_x == cell_size - 1 and in_pass_z) or
                              (local_z == 0 and in_pass_x) or (local_z == cell_size - 1 and in_pass_x)

            local wall_mat = has_moss and c_mossycobble or c_cobble

            local is_torch_pos = (local_x == 1 or local_x == cell_size - 2) and
                                 (local_z % torch_spacing == 0) and local_z > 0 and local_z < cell_size - 1
            local is_torch_pos_z = (local_z == 1 or local_z == cell_size - 2) and
                                   (local_x % torch_spacing == 0) and local_x > 0 and local_x < cell_size - 1

            for y = minp.y, maxp.y do
                if is_in_dimension(y, config) then
                    local vi = area:index(x, y, z)
                    local rel_y = y - config.y_min

                    if rel_y == 0 or rel_y == 1 then
                        data[vi] = c_cobble
                    elseif on_wall and not is_passage and rel_y >= 2 and rel_y <= wall_height + 1 then
                        data[vi] = wall_mat
                    elseif (is_torch_pos or is_torch_pos_z) and rel_y == torch_height then
                        data[vi] = c_meselamp
                    else
                        data[vi] = c_air
                    end
                end
            end
        end
    end
end

local function generate_endless_house(minp, maxp, vm, area, data)
    local config = oh.dimensions.endless_house

    local room_size = 16
    local wall = 1
    local interior = room_size - wall * 2
    local floor_thickness = 1
    local ceil_thickness = 1
    local room_height = 7
    local layer_size = room_height + floor_thickness + ceil_thickness

    local c_air = get_content_id("air")
    local c_wall = get_content_id("default:wood")
    local c_floor = get_content_id("default:wood")

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            for y = minp.y, maxp.y do
                if is_in_dimension(y, config) then
                    local vi = area:index(x, y, z)

                    local rel_y = y - config.y_min
                    local layer = floor(rel_y / layer_size)
                    local ly = rel_y % layer_size

                    local lx = ((x % room_size) + room_size) % room_size
                    local lz = ((z % room_size) + room_size) % room_size

                    local is_floor = ly < floor_thickness
                    local is_ceiling = ly >= (floor_thickness + room_height)

                    local on_outer_wall = (lx < wall) or (lx >= room_size - wall) or (lz < wall) or (lz >= room_size - wall)

                    local door_w = 2
                    local door_h = 3
                    local door_x0 = floor(room_size / 2) - 1
                    local door_x1 = door_x0 + door_w - 1
                    local door_z0 = floor(room_size / 2) - 1
                    local door_z1 = door_z0 + door_w - 1
                    local in_door_y = (ly >= floor_thickness) and (ly < floor_thickness + door_h)

                    local door_open = false
                    if in_door_y and on_outer_wall then
                        if lz < wall and lx >= door_x0 and lx <= door_x1 then
                            door_open = true
                        elseif lz >= room_size - wall and lx >= door_x0 and lx <= door_x1 then
                            door_open = true
                        elseif lx < wall and lz >= door_z0 and lz <= door_z1 then
                            door_open = true
                        elseif lx >= room_size - wall and lz >= door_z0 and lz <= door_z1 then
                            door_open = true
                        end
                    end

                    if is_floor then
                        data[vi] = c_floor
                    elseif is_ceiling then
                        data[vi] = c_floor
                    elseif on_outer_wall and not door_open then
                        data[vi] = c_wall
                    else
                        data[vi] = c_air
                    end
                end
            end
        end
    end
end

local function place_endless_house_room_furniture(minp, maxp)
    local config = oh.dimensions.endless_house
    if maxp.y < config.y_min or minp.y > config.y_max then return end

    local room_size = 16
    local floor_thickness = 1
    local room_height = 7
    local layer_size = room_height + floor_thickness + 1

    local function room_type_for_cell(cell_x, layer, cell_z)
        local seed = hash_pos(cell_x, layer, cell_z)
        return seeded_random(seed, 1, 12)
    end

    local function for_each_room_intersecting_chunk(fn)
        local cx0 = floor(minp.x / room_size) - 1
        local cx1 = floor(maxp.x / room_size) + 1
        local cz0 = floor(minp.z / room_size) - 1
        local cz1 = floor(maxp.z / room_size) + 1

        local ly0 = floor((minp.y - config.y_min) / layer_size) - 1
        local ly1 = floor((maxp.y - config.y_min) / layer_size) + 1

        for layer = ly0, ly1 do
            local base_y = config.y_min + layer * layer_size
            for cell_x = cx0, cx1 do
                for cell_z = cz0, cz1 do
                    local base = {x = cell_x * room_size, y = base_y, z = cell_z * room_size}
                    fn(cell_x, layer, cell_z, base)
                end
            end
        end
    end

    local function safe_set(pos, node)
        local n = minetest.get_node(pos)
        if n.name ~= "air" then return false end
        minetest.set_node(pos, node)
        return true
    end

    for_each_room_intersecting_chunk(function(cell_x, layer, cell_z, base)
        local t = room_type_for_cell(cell_x, layer, cell_z)
        local floor_y = base.y + floor_thickness

        local p1 = {x = base.x + 2, y = floor_y, z = base.z + 2}
        local p2 = {x = base.x + 2, y = floor_y + 1, z = base.z + 2}
        local p3 = {x = base.x + 3, y = floor_y, z = base.z + 2}
        local p4 = {x = base.x + 2, y = floor_y, z = base.z + 3}

        if t == 1 then
            safe_set(p1, {name = "default:furnace"})
        elseif t == 2 then
            safe_set(p1, {name = "default:chest"})
        elseif t == 3 then
            safe_set(p1, {name = "default:wood"})
            safe_set(p2, {name = "default:torch"})
        elseif t == 4 then
            safe_set(p1, {name = "default:meselamp"})
        elseif t == 5 then
            safe_set(p1, {name = "default:cobble"})
            safe_set(p3, {name = "default:cobble"})
        elseif t == 6 then
            safe_set(p1, {name = "default:obsidian"})
        elseif t == 7 then
            safe_set(p1, {name = "default:glass"})
        elseif t == 8 then
            safe_set(p1, {name = "default:wood"})
            safe_set(p4, {name = "default:wood"})
        elseif t == 9 then
            safe_set(p1, {name = "default:stonebrick"})
        elseif t == 10 then
            safe_set(p1, {name = "default:mossycobble"})
        elseif t == 11 then
            safe_set(p1, {name = "default:brick"})
        elseif t == 12 then
            safe_set(p1, {name = "default:tree"})
        end

        if cell_x == 0 and cell_z == 0 and layer == 0 then
            safe_set({x = base.x + 8, y = floor_y, z = base.z + 8}, {name = "obelisk_analog:portal_overworld"})
        end
    end)
end

minetest.register_on_generated(function(minp, maxp, blockseed)
    local dominated_by_dimension = false

    for _, config in pairs(oh.dimensions) do
        if minp.y <= config.y_max and maxp.y >= config.y_min then
            dominated_by_dimension = true
            break
        end
    end

    if not dominated_by_dimension then return end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
    local data = vm:get_data()

    local seq = oh.dimensions.sequence
    local won = oh.dimensions.wonderland
    local cor = oh.dimensions.corners
    local eh = oh.dimensions.endless_house

    if minp.y <= seq.y_max and maxp.y >= seq.y_min then
        generate_sequence(minp, maxp, vm, area, data)
    end

    if minp.y <= won.y_max and maxp.y >= won.y_min then
        generate_wonderland(minp, maxp, vm, area, data)
    end

    if minp.y <= cor.y_max and maxp.y >= cor.y_min then
        generate_corners(minp, maxp, vm, area, data)
    end

    if minp.y <= eh.y_max and maxp.y >= eh.y_min then
        generate_endless_house(minp, maxp, vm, area, data)
    end

    vm:set_data(data)
    vm:calc_lighting()
    vm:write_to_map()

    if minp.y <= eh.y_max and maxp.y >= eh.y_min then
        minetest.after(0, function()
            place_endless_house_room_furniture(minp, maxp)
        end)
    end
end)

local function find_clear_area_wonderland(base_pos, size)
    local config = oh.dimensions.wonderland
    local tree_spacing = C.GRID.WONDERLAND_TREE_SPACING
    local ground_y = config.y_min + 2

    for attempt = 0, 20 do
        local test_x = base_pos.x + (attempt % 5) * 15
        local test_z = base_pos.z + floor(attempt / 5) * 15

        local clear = true
        for check_x = -size, size do
            for check_z = -size, size do
                local cx = test_x + check_x
                local cz = test_z + check_z
                local tx = floor((cx + tree_spacing/2) / tree_spacing) * tree_spacing
                local tz = floor((cz + tree_spacing/2) / tree_spacing) * tree_spacing

                if abs(cx - tx) <= 3 and abs(cz - tz) <= 3 then
                    local seed = hash_pos(tx, 0, tz)
                    if seeded_random(seed, 0, 4) ~= 0 then
                        clear = false
                        break
                    end
                end
            end
            if not clear then break end
        end

        if clear then
            return {x = test_x, y = ground_y, z = test_z}
        end
    end

    local safe_x = floor(base_pos.x / tree_spacing) * tree_spacing + floor(tree_spacing / 2)
    local safe_z = floor(base_pos.z / tree_spacing) * tree_spacing + floor(tree_spacing / 2)
    return {x = safe_x, y = ground_y, z = safe_z}
end

local function spawn_sequence_portal_room(pos)
    for dy = -1, 4 do
        for dx = -3, 3 do
            for dz = -3, 3 do
                minetest.set_node({x = pos.x + dx, y = pos.y + dy, z = pos.z + dz}, {name = "air"})
            end
        end
    end

    for x = -3, 3 do
        for z = -3, 3 do
            minetest.set_node({x = pos.x + x, y = pos.y - 1, z = pos.z + z}, {name = "default:brick"})
        end
    end

    for y = 0, 3 do
        for x = -3, 3 do
            for z = -3, 3 do
                local on_edge = abs(x) == 3 or abs(z) == 3
                local is_entrance = z == -3 and abs(x) <= 1 and y <= 2
                if on_edge and not is_entrance then
                    minetest.set_node({x = pos.x + x, y = pos.y + y, z = pos.z + z}, {name = "default:brick"})
                end
            end
        end
    end

    for x = -3, 3 do
        for z = -3, 3 do
            minetest.set_node({x = pos.x + x, y = pos.y + 4, z = pos.z + z}, {name = "default:brick"})
        end
    end

    minetest.set_node({x = pos.x - 2, y = pos.y + 3, z = pos.z - 2}, {name = "default:meselamp"})
    minetest.set_node({x = pos.x + 2, y = pos.y + 3, z = pos.z - 2}, {name = "default:meselamp"})
    minetest.set_node({x = pos.x - 2, y = pos.y + 3, z = pos.z + 2}, {name = "default:meselamp"})
    minetest.set_node({x = pos.x + 2, y = pos.y + 3, z = pos.z + 2}, {name = "default:meselamp"})

    minetest.set_node({x = pos.x, y = pos.y, z = pos.z + 1}, {name = "obelisk_analog:portal_wonderland"})

    local chest_pos = {x = pos.x + 1, y = pos.y, z = pos.z + 1}
    minetest.set_node(chest_pos, {name = "default:chest"})
    local meta = minetest.get_meta(chest_pos)
    local inv = meta:get_inventory()
    inv:set_size("main", 32)
    if oh.fill_loot_chest then
        oh.fill_loot_chest(inv, "dimension_chest")
    else
        inv:add_item("main", "default:torch 10")
    end
    meta:set_string("infotext", "Supply Chest")
end

local function spawn_wonderland_house(pos)
    oh.build_house_with_validation(pos, "wonderland")
end

local function spawn_corners_door(pos)
    for dy = 0, 4 do
        for dx = -2, 2 do
            for dz = -2, 2 do
                minetest.set_node({x = pos.x + dx, y = pos.y + dy, z = pos.z + dz}, {name = "air"})
            end
        end
    end

    for x = -2, 2 do
        for z = -2, 2 do
            minetest.set_node({x = pos.x + x, y = pos.y, z = pos.z + z}, {name = "default:stonebrick"})
        end
    end

    for y = 1, 3 do
        minetest.set_node({x = pos.x - 2, y = pos.y + y, z = pos.z - 2}, {name = "default:stonebrick"})
        minetest.set_node({x = pos.x + 2, y = pos.y + y, z = pos.z - 2}, {name = "default:stonebrick"})
        minetest.set_node({x = pos.x - 2, y = pos.y + y, z = pos.z + 2}, {name = "default:stonebrick"})
        minetest.set_node({x = pos.x + 2, y = pos.y + y, z = pos.z + 2}, {name = "default:stonebrick"})
    end

    minetest.set_node({x = pos.x - 2, y = pos.y + 4, z = pos.z - 2}, {name = "default:meselamp"})
    minetest.set_node({x = pos.x + 2, y = pos.y + 4, z = pos.z - 2}, {name = "default:meselamp"})
    minetest.set_node({x = pos.x - 2, y = pos.y + 4, z = pos.z + 2}, {name = "default:meselamp"})
    minetest.set_node({x = pos.x + 2, y = pos.y + 4, z = pos.z + 2}, {name = "default:meselamp"})

    minetest.set_node({x = pos.x, y = pos.y + 1, z = pos.z}, {name = "obelisk_analog:portal_endless_house"})
    minetest.set_node({x = pos.x, y = pos.y + 2, z = pos.z}, {name = "default:meselamp"})
end

local function find_safe_spawn_sequence(base_y)
    return {x = 0, y = base_y + 1, z = 0}
end

function oh.teleport_to_dimension(player, dimension)
    if not player then return end

    local name = player:get_player_name()
    local config = oh.dimensions[dimension]

    if not config then return end

    local spawn_pos

    if dimension == "sequence" then
        spawn_pos = find_safe_spawn_sequence(config.y_min)
    elseif dimension == "wonderland" then
        spawn_pos = {x = 7, y = config.spawn_y, z = 7}
    elseif dimension == "corners" then
        spawn_pos = {x = 10, y = config.spawn_y, z = 10}
    elseif dimension == "endless_house" then
        spawn_pos = {x = 8, y = config.spawn_y, z = 8}
    else
        spawn_pos = {x = 10, y = config.spawn_y, z = 10}
    end

    oh.player_data[name] = oh.player_data[name] or {}
    oh.player_data[name].in_god_mode = true
    oh.player_data[name].dimension_spawn_pos = spawn_pos
    oh.player_data[name].current_dimension = dimension

    player:set_armor_groups({immortal = 1})
    player:set_pos(spawn_pos)

    oh.play_sound(player, "obelisk_analog_random_voice", 0.5)
    minetest.chat_send_player(name, minetest.colorize("#FF4500", "Entering " .. dimension:gsub("^%l", string.upper) .. "..."))

    local key = name .. "_" .. dimension
    if not oh.rare_structures[key] then
        minetest.after(5, function()
            local p = minetest.get_player_by_name(name)
            if not p then return end

            local ppos = p:get_pos()
            if not ppos then return end

            local struct_pos

            if dimension == "sequence" then
                local grid_size = C.GRID.SEQUENCE_SIZE
                local room_x = floor(ppos.x / grid_size) * grid_size + floor(grid_size / 2)
                local room_z = floor(ppos.z / grid_size) * grid_size + grid_size + floor(grid_size / 2)
                struct_pos = {x = room_x, y = config.y_min + 1, z = room_z}
                spawn_sequence_portal_room(struct_pos)
            elseif dimension == "wonderland" then
                local base_pos = {x = ppos.x + 20, y = config.y_min + 2, z = ppos.z + 20}
                struct_pos = find_clear_area_wonderland(base_pos, 5)
                spawn_wonderland_house(struct_pos)
            elseif dimension == "corners" then
                local cell_size = C.GRID.CORNERS_CELL_SIZE
                struct_pos = {
                    x = floor(ppos.x / cell_size) * cell_size + floor(cell_size / 2),
                    y = config.y_min + 2,
                    z = floor(ppos.z / cell_size) * cell_size + cell_size * 2 + floor(cell_size / 2)
                }
                spawn_corners_door(struct_pos)
            end

            if struct_pos then
                oh.rare_structures[key] = struct_pos
                minetest.chat_send_player(name, minetest.colorize("#888800", "You sense something nearby..."))
            end
        end)
    end
end

function oh.teleport_to_overworld(player)
    if not player then return end

    local name = player:get_player_name()
    local spawn_pos = minetest.settings:get_pos("static_spawnpoint") or {x = 0, y = 10, z = 0}

    player:set_pos(spawn_pos)
    player:set_armor_groups({immortal = 0, fleshy = 100})

    if oh.player_data[name] then
        oh.player_data[name].in_god_mode = false
        oh.player_data[name].dimension_spawn_pos = nil
        oh.player_data[name].current_dimension = nil
    end

    minetest.chat_send_player(name, minetest.colorize("#00FF00", "Returned to the Overworld"))
end

function oh.update_god_mode(dtime)
    oh.timers.god_mode = oh.timers.god_mode + dtime
    if oh.timers.god_mode < C.TIMERS.GOD_MODE_CHECK then return end
    oh.timers.god_mode = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local pdata = oh.player_data[name]

        if pdata and pdata.in_god_mode then
            local pos = player:get_pos()
            local vel = player:get_velocity()

            if vel and abs(vel.y) < 0.5 then
                local below = minetest.get_node({x = floor(pos.x), y = floor(pos.y) - 1, z = floor(pos.z)})
                if below.name ~= "air" and below.name ~= "ignore" then
                    pdata.in_god_mode = false
                    player:set_armor_groups({immortal = 0, fleshy = 100})
                    minetest.chat_send_player(name, minetest.colorize("#FFFF00", "God mode disabled - landed safely"))
                end
            end
        end

        if pdata and pdata.dimension_spawn_pos and pdata.current_dimension then
            local pos = player:get_pos()
            local config = oh.dimensions[pdata.current_dimension]

            if config and pos.y < config.y_min - 10 then
                local safe_pos
                if pdata.current_dimension == "sequence" then
                    safe_pos = find_safe_spawn_sequence(config.y_min)
                else
                    safe_pos = pdata.dimension_spawn_pos
                end
                player:set_pos(safe_pos)
                player:set_armor_groups({immortal = 1})
                pdata.in_god_mode = true
                pdata.dimension_spawn_pos = safe_pos
                minetest.chat_send_player(name, minetest.colorize("#FF0000", "You fell into the void... Teleported to safety"))
            end
        end
    end
end

function oh.update_time_control(dtime)
    oh.timers.time_control = oh.timers.time_control + dtime
    if oh.timers.time_control < C.TIMERS.TIME_CONTROL then return end
    oh.timers.time_control = 0

    local dimension_priority = nil
    for _, player in ipairs(minetest.get_connected_players()) do
        local pdata = oh.player_data[player:get_player_name()]
        if pdata and pdata.current_dimension then
            if pdata.current_dimension == "corners" then
                dimension_priority = "corners"
                break
            elseif pdata.current_dimension == "sequence" and dimension_priority ~= "corners" then
                dimension_priority = "sequence"
            elseif pdata.current_dimension == "wonderland" and not dimension_priority then
                dimension_priority = "wonderland"
            end
        end
    end

    if not dimension_priority then return end

    local current_time = minetest.get_timeofday()
    local is_day = current_time >= C.NIGHT.END and current_time <= C.NIGHT.START

    if dimension_priority == "corners" then
        if current_time >= 0.2 and current_time <= 0.8 then
            minetest.set_timeofday(0.0)
        end
    elseif dimension_priority == "sequence" then
        local new_time = current_time + 0.0002
        if new_time > 1 then new_time = new_time - 1 end
        minetest.set_timeofday(new_time)
    elseif dimension_priority == "wonderland" then
        local speed = is_day and 0.002 or 0.0003
        local new_time = current_time + speed
        if new_time > 1 then new_time = new_time - 1 end
        minetest.set_timeofday(new_time)
    end
end

minetest.register_on_dieplayer(function(player, reason)
    local name = player:get_player_name()
    local pdata = oh.player_data[name]

    if pdata and pdata.dimension_spawn_pos then
        minetest.after(0.1, function()
            local p = minetest.get_player_by_name(name)
            if p and pdata.dimension_spawn_pos then
                p:set_pos(pdata.dimension_spawn_pos)
                pdata.in_god_mode = true
                p:set_armor_groups({immortal = 1})
            end
        end)
    end
end)
