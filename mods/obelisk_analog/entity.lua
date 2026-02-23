local oh = obelisk_analog
local C = oh.C
local random, floor, abs = math.random, math.floor, math.abs
local vec_add, vec_sub, vec_mul, vec_dir, vec_dist = vector.add, vector.subtract, vector.multiply, vector.direction, vector.distance

local STATE = {
    IDLE = "idle",
    STALKING = "stalking",
    CHASING = "chasing",
    WINDOW_PEEK = "window_peeking",
    CORNER_WATCH = "corner_watching",
    CEILING_HANG = "ceiling_hanging",
    FLOOR_EMERGE = "floor_emerging",
    WALL_PHASE = "wall_phasing",
    NO_ESCAPE = "no_escape",
}

local function create_ability_cooldowns()
    local cooldowns = {}
    for ability, _ in pairs(C.ABILITY_COOLDOWNS) do
        cooldowns[ability] = 0
    end
    return cooldowns
end

local function is_valid_entity(self)
    return self and self.object and self.object:get_pos()
end

local function get_target_player(self)
    if not self.target_player then return nil end
    return minetest.get_player_by_name(self.target_player)
end

local entity_def = {
    initial_properties = {
        physical = true,
        collisionbox = C.ENTITY.COLLISION_BOX,
        visual = "upright_sprite",
        textures = {"entity_model.png", "entity_model.png"},
        visual_size = C.ENTITY.VISUAL_SIZE,
        spritediv = {x = 1, y = 1},
        makes_footstep_sound = false,
        static_save = false,
        glow = 0,
    },

    target_player = nil,
    state = STATE.IDLE,
    state_timer = 0,
    ability_timer = 0,
    ability_cooldowns = nil,

    chases_this_spawn = 0,
    stalk_time_total = 0,

    crazy_mode = false,
    crazy_mode_v2 = false,
    no_escape_mode = false,

    invisible = false,
    invisible_timer = 0,
    blinky = false,
    blink_timer = 0,

    current_speed = C.ENTITY.BASE_SPEED,
    base_speed = C.ENTITY.BASE_SPEED,

    is_upside_down = false,
    is_emerging = false,
    emerge_progress = 0,
    size_multiplier = 1,
    pixelated = false,
    frame_skip = false,
    frame_skip_counter = 0,
    clone_mode = false,

    stuck_timer = 0,
    last_pos = nil,
    hit_count = 0,
    hits_to_escape = 0,
    no_escape_hits = 0,

    vanish_timer = 0,
    vanish_duration = 0,
    is_vanished = false,
    abilities_used_this_spawn = 0,
    max_abilities_per_spawn = 5,
    last_ability_time = 0,
    ability_delay = 8,

    on_activate = function(self, staticdata, dtime_s)
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = -10, z = 0})

        self.last_pos = self.object:get_pos()
        self.hit_count = 0
        self.hits_to_escape = random(C.ENTITY.HITS_TO_ESCAPE_MIN, C.ENTITY.HITS_TO_ESCAPE_MAX)
        self.ability_cooldowns = create_ability_cooldowns()

        local config = oh.get_phase_config()
        self.base_speed = config.entity_speed or C.ENTITY.BASE_SPEED
        self.current_speed = self.base_speed

        if oh.is_night() then
            self.base_speed = self.base_speed * 1.2
        end

        if random() < 0.2 then
            self:start_floor_emerge()
        end

        if random() < 0.02 * oh.current_phase then
            self.no_escape_mode = true
            self.no_escape_hits = random(15, 25)
        end

        self.abilities_used_this_spawn = 0
        self.max_abilities_per_spawn = random(2, 4 + floor(oh.current_phase / 2))
        self.vanish_timer = random(40, 110)
        self.is_vanished = false
        self.last_ability_time = 0
        self.ability_delay = random(8, 14)

        self.chases_this_spawn = 0
        self.stalk_time_total = 0
    end,

    start_floor_emerge = function(self)
        if not is_valid_entity(self) then return end

        self.is_emerging = true
        self.emerge_progress = 0
        self.state = STATE.FLOOR_EMERGE

        local pos = self.object:get_pos()
        self.object:set_pos({x = pos.x, y = pos.y - 2, z = pos.z})

        oh.create_particles(pos, "default_dirt.png", 30, 2, {
            minvel = {x = -0.5, y = 1, z = -0.5},
            maxvel = {x = 0.5, y = 2, z = 0.5},
            minacc = {x = 0, y = -2, z = 0},
            maxacc = {x = 0, y = -2, z = 0},
        })
    end,

    on_step = function(self, dtime)
        if not oh.entity_active then
            self:remove_entity()
            return
        end

        if not is_valid_entity(self) then
            self:remove_entity()
            return
        end

        self.state_timer = self.state_timer + dtime
        self.ability_timer = self.ability_timer + dtime
        self:update_cooldowns(dtime)

        if self.state == STATE.FLOOR_EMERGE then
            self:do_floor_emerge(dtime)
            return
        end

        self:update_invisibility(dtime)
        self:update_blink(dtime)

        if self.frame_skip then
            self.frame_skip_counter = self.frame_skip_counter + 1
            if self.frame_skip_counter % 3 ~= 0 then
                return
            end
        end

        local pos = self.object:get_pos()
        if not pos then return end

        self:check_void_fall(pos)
        self:check_stuck(pos, dtime)

        local target = get_target_player(self)
        if not target then
            target = oh.get_random_player()
            if target then
                self.target_player = target:get_player_name()
            else
                self:remove_entity()
                return
            end
        end

        local tpos = target:get_pos()
        if not tpos then return end

        local distance = vec_dist(pos, tpos)

        self:face_player(target)

        if self.crazy_mode then
            self:do_crazy_movement(dtime)
        end

        self.last_ability_time = self.last_ability_time + dtime
        self.vanish_timer = self.vanish_timer - dtime

        if self.state == STATE.STALKING then
            self.stalk_time_total = self.stalk_time_total + dtime
        end

        if self.vanish_timer <= 0 and not self.is_vanished then
            self:vanish_temporarily(target)
            return
        end

        if self.ability_timer >= C.TIMERS.ABILITY_CHECK and self.last_ability_time >= self.ability_delay then
            self.ability_timer = 0
            if self.abilities_used_this_spawn < self.max_abilities_per_spawn then
                self:try_random_ability(target, distance)
            end
        end

        self:run_state_behavior(target, distance, dtime)
        self:check_visibility_transition(target, pos)
    end,

    update_cooldowns = function(self, dtime)
        if not self.ability_cooldowns then return end
        for ability, remaining in pairs(self.ability_cooldowns) do
            if remaining > 0 then
                self.ability_cooldowns[ability] = remaining - dtime
            end
        end
    end,

    is_ability_ready = function(self, ability)
        if not self.ability_cooldowns then return true end
        return (self.ability_cooldowns[ability] or 0) <= 0
    end,

    set_ability_cooldown = function(self, ability)
        if not self.ability_cooldowns then return end
        self.ability_cooldowns[ability] = C.ABILITY_COOLDOWNS[ability] or 10
    end,

    do_floor_emerge = function(self, dtime)
        if not is_valid_entity(self) then return end

        self.emerge_progress = self.emerge_progress + dtime * 0.5
        local pos = self.object:get_pos()
        self.object:set_pos({x = pos.x, y = pos.y + dtime * 0.5, z = pos.z})

        if self.emerge_progress >= 2 then
            self.is_emerging = false
            self.state = STATE.IDLE
            self.state_timer = 0
        end
    end,

    update_invisibility = function(self, dtime)
        if self.invisible_timer > 0 then
            self.invisible_timer = self.invisible_timer - dtime
            if self.invisible_timer <= 0 then
                self.invisible = false
                self.blinky = false
                self:update_visuals()
            end
        end
    end,

    update_blink = function(self, dtime)
        if not self.blinky then return end
        if not is_valid_entity(self) then return end

        self.blink_timer = self.blink_timer + dtime
        if self.blink_timer >= 0.2 then
            self.blink_timer = 0
            local props = self.object:get_properties()
            if props.visual_size.x > 0 then
                self.object:set_properties({visual_size = {x = 0, y = 0, z = 0}})
            else
                local size = self.size_multiplier
                self.object:set_properties({
                    visual_size = {x = 2 * size, y = 3 * size, z = 2 * size}
                })
            end
        end
    end,

    check_void_fall = function(self, pos)
        if not is_valid_entity(self) then return end

        local in_dim = oh.is_in_dimension(pos)
        local min_y = in_dim and (C.DIMENSION.SEQUENCE_Y - 100) or -100

        if pos.y < min_y then
            local target = get_target_player(self)
            if target then
                local spawn_pos = oh.find_spawn_pos_behind_player(target)
                if spawn_pos then
                    self.object:set_pos(spawn_pos)
                end
            else
                self:remove_entity()
            end
        end
    end,

    check_stuck = function(self, pos, dtime)
        if not self.last_pos then
            self.last_pos = pos
            return
        end

        local dist = vec_dist(pos, self.last_pos)
        if dist < 0.1 then
            self.stuck_timer = self.stuck_timer + dtime
            if self.stuck_timer > C.ENTITY.STUCK_THRESHOLD then
                self.stuck_timer = 0
                local target = get_target_player(self)
                if target then
                    local spawn_pos = oh.find_spawn_pos_behind_player(target)
                    if spawn_pos then
                        self.object:set_pos(spawn_pos)
                    end
                end
            end
        else
            self.stuck_timer = 0
        end
        self.last_pos = pos
    end,

    face_player = function(self, player)
        if not is_valid_entity(self) or not player then return end

        local pos = self.object:get_pos()
        local ppos = player:get_pos()
        if not pos or not ppos then return end

        local dir = vec_dir(pos, ppos)
        local yaw = math.atan2(dir.z, dir.x) - math.pi/2

        if self.is_upside_down then
            self.object:set_rotation({x = math.pi, y = yaw, z = 0})
        else
            self.object:set_yaw(yaw)
        end
    end,

    run_state_behavior = function(self, target, distance, dtime)
        local handlers = {
            [STATE.IDLE] = self.do_idle,
            [STATE.STALKING] = self.do_stalking,
            [STATE.CHASING] = self.do_chasing,
            [STATE.WINDOW_PEEK] = self.do_window_peeking,
            [STATE.CORNER_WATCH] = self.do_corner_watching,
            [STATE.CEILING_HANG] = self.do_ceiling_hanging,
            [STATE.WALL_PHASE] = self.do_wall_phasing,
            [STATE.NO_ESCAPE] = self.do_no_escape,
        }

        local handler = handlers[self.state]
        if handler then
            handler(self, target, distance, dtime)
        end
    end,

    do_idle = function(self, target, distance, dtime)
        if self.state_timer > 5 then
            self.state = STATE.STALKING
            self.state_timer = 0
        end
    end,

    do_stalking = function(self, target, distance, dtime)
        if not is_valid_entity(self) or not target then return end

        local pos = self.object:get_pos()
        local tpos = target:get_pos()
        if not pos or not tpos then return end

        if distance > C.ENTITY.STALK_DISTANCE then
            local dir = vec_dir(pos, tpos)
            local speed = self.current_speed * 0.5
            self.object:set_velocity({x = dir.x * speed, y = 0, z = dir.z * speed})
        else
            self.object:set_velocity({x = 0, y = 0, z = 0})
        end
    end,

    do_chasing = function(self, target, distance, dtime)
        if not is_valid_entity(self) or not target then return end

        local pos = self.object:get_pos()
        local tpos = target:get_pos()
        if not pos or not tpos then return end

        local dir = vec_dir(pos, tpos)
        local speed = self.current_speed * 1.5

        if self.crazy_mode then speed = speed * 1.3 end
        if self.crazy_mode_v2 then
            speed = speed * 1.5
            self:break_blocks_in_path(dir)
        end

        self.object:set_velocity({x = dir.x * speed, y = 0, z = dir.z * speed})

        if distance < C.ENTITY.KILL_DISTANCE then
            local config = oh.get_phase_config()
            if random() < config.kill_chance * 0.5 then
                self:kill_player(target)
            elseif random() < 0.55 then
                self:vanish_temporarily(target)
            else
                self:disappear_and_respawn(target)
                oh.send_whisper(target, "So close...")
            end
        end

        if self.state_timer > C.ENTITY.CHASE_TIMEOUT then
            self.state = STATE.STALKING
            self.state_timer = 0
            self.crazy_mode = false
            self.crazy_mode_v2 = false
            self:update_visuals()
        end
    end,

    do_no_escape = function(self, target, distance, dtime)
        if not is_valid_entity(self) or not target then return end

        local pos = self.object:get_pos()
        local tpos = target:get_pos()
        if not pos or not tpos then return end

        local dir = vec_dir(pos, tpos)
        local speed = self.current_speed * 2

        self.object:set_velocity({x = dir.x * speed, y = 0, z = dir.z * speed})

        if distance < C.ENTITY.KILL_DISTANCE then
            if random() < 0.6 then
                self:kill_player(target)
            else
                self:disappear_and_respawn(target)
                oh.send_whisper(target, "Next time...")
            end
        end

        if self.state_timer % 5 < 0.1 then
            oh.send_whisper(target, "NO ESCAPE")
        end
    end,

    do_window_peeking = function(self, target, distance, dtime)
        if not is_valid_entity(self) then return end
        self.object:set_velocity({x = 0, y = 0, z = 0})

        if self.state_timer > 5 then
            self:disappear_and_respawn(target)
        end
    end,

    do_corner_watching = function(self, target, distance, dtime)
        if not is_valid_entity(self) then return end
        self.object:set_velocity({x = 0, y = 0, z = 0})

        if self.state_timer > 8 then
            if random() < 0.3 then
                self.state = STATE.CHASING
                self:enter_crazy_mode()
            else
                self:disappear_and_respawn(target)
            end
        end
    end,

    do_ceiling_hanging = function(self, target, distance, dtime)
        if not is_valid_entity(self) then return end

        self.object:set_velocity({x = 0, y = 0, z = 0})
        self.object:set_acceleration({x = 0, y = 0, z = 0})

        if self.state_timer > 6 then
            self.is_upside_down = false
            self.object:set_rotation({x = 0, y = self.object:get_yaw(), z = 0})
            self.object:set_acceleration({x = 0, y = -10, z = 0})
            self.state = STATE.STALKING
            self.state_timer = 0
        end
    end,

    do_wall_phasing = function(self, target, distance, dtime)
        if not is_valid_entity(self) then return end
        self.object:set_velocity({x = 0, y = 0, z = 0})

        if self.state_timer > 3 then
            self.state = STATE.STALKING
            self.state_timer = 0
        end
    end,

    do_crazy_movement = function(self, dtime)
        if not is_valid_entity(self) then return end

        local pos = self.object:get_pos()
        local offset = {
            x = (random() - 0.5) * 0.3,
            y = (random() - 0.5) * 0.1,
            z = (random() - 0.5) * 0.3,
        }
        self.object:set_pos(vec_add(pos, offset))

        local yaw = self.object:get_yaw()
        self.object:set_yaw(yaw + (random() - 0.5) * 0.5)
    end,

    check_visibility_transition = function(self, target, pos)
        if not target or not pos then return end

        local player_sees = oh.player_can_see_pos(target, pos)

        if not player_sees then
            if self.state == STATE.STALKING and random() < 0.01 then
                self:disappear_and_respawn(target)
            end
        else
            if self.state == STATE.STALKING and self.stalk_time_total >= (C.ENTITY.MIN_STALK_TIME_BEFORE_CHASE or 20) and random() < 0.02 then
                if self.chases_this_spawn < (C.ENTITY.MAX_CHASES_PER_SPAWN or 1) and random() < 0.45 then
                    self.state = STATE.CHASING
                    self.state_timer = 0
                    self.chases_this_spawn = self.chases_this_spawn + 1
                    self:enter_crazy_mode()
                elseif random() < 0.35 then
                    self:vanish_temporarily(target)
                else
                    self:disappear_and_respawn(target)
                end
            end
        end
    end,

    enter_crazy_mode = function(self)
        self.crazy_mode = true
        self.state_timer = 0

        local variant = random(1, 3)
        if variant == 1 then
            self.frame_skip = true
        elseif variant == 2 then
            self.pixelated = true
        end

        if random() < 0.1 then
            self.crazy_mode_v2 = true
        end

        self:update_visuals()

        local target = get_target_player(self)
        if target then
            local msg = oh.crazy_messages[random(#oh.crazy_messages)]
            oh.send_whisper(target, msg)
            oh.play_sound(target, "obelisk_analog_random_voice", 1.0)
        end
    end,

    update_visuals = function(self)
        if not is_valid_entity(self) then return end

        local texture = "entity_model.png"

        if self.invisible then
            self.object:set_properties({
                visual_size = {x = 0, y = 0, z = 0},
                glow = 0,
            })
            return
        end

        if self.pixelated then
            texture = texture .. "^[brighten"
        end

        local glow = 0
        if self.crazy_mode then glow = 5 end
        if self.crazy_mode_v2 then glow = 10 end

        local size = self.size_multiplier
        self.object:set_properties({
            textures = {texture, texture},
            visual_size = {x = 2 * size, y = 3 * size, z = 2 * size},
            glow = glow,
        })
    end,

    break_blocks_in_path = function(self, dir)
        if not is_valid_entity(self) then return end

        local pos = self.object:get_pos()
        for i = 1, 3 do
            local check_pos = vec_add(pos, vec_mul(dir, i))
            check_pos.y = floor(check_pos.y)
            for y_off = 0, 2 do
                local block_pos = {
                    x = floor(check_pos.x),
                    y = check_pos.y + y_off,
                    z = floor(check_pos.z)
                }
                local node = minetest.get_node(block_pos)
                if node.name ~= "air" and minetest.get_item_group(node.name, "unbreakable") == 0 then
                    if not minetest.is_protected(block_pos, "") then
                        minetest.remove_node(block_pos)
                        minetest.sound_play("obelisk_analog_crack_sound", {pos = block_pos, gain = 0.5})
                    end
                end
            end
        end
    end,

    try_random_ability = function(self, target, distance)
        if not target then return end
        if self.abilities_used_this_spawn >= self.max_abilities_per_spawn then return end

        local phase = oh.current_phase
        local config = oh.get_phase_config()
        local freq = config.ability_frequency or 1
        local base_mult = 0.03

        local abilities = {
            {name = "whisper", chance = base_mult * 4 * freq, func = self.ability_whisper},
            {name = "teleport", chance = base_mult * 2 * freq, func = self.ability_teleport},
            {name = "invisibility", chance = base_mult * 1.5 * freq, func = self.ability_invisibility},
            {name = "speed_change", chance = base_mult * 2 * freq, func = self.ability_speed_change},
            {name = "torch_destroy", chance = base_mult * 2 * freq, func = self.ability_torch_destroy},
            {name = "door_interact", chance = base_mult * 1.5 * freq, func = self.ability_door_interact},
            {name = "sound_distort", chance = base_mult * 3 * freq, func = self.ability_sound_distort},
            {name = "item_steal", chance = base_mult * 0.5 * freq, func = self.ability_item_steal},
            {name = "inventory_shuffle", chance = base_mult * 0.3 * freq, func = self.ability_inventory_shuffle},
            {name = "behind_spawn", chance = base_mult * 1.5 * freq, func = self.ability_behind_spawn},
            {name = "corner_watch", chance = base_mult * 1.5 * freq, func = self.ability_corner_watch},
            {name = "ceiling_hang", chance = base_mult * 1 * freq, func = self.ability_ceiling_hang},
            {name = "wall_phase", chance = base_mult * 1 * freq, func = self.ability_wall_phase},
            {name = "name_whisper", chance = base_mult * 1 * freq, func = self.ability_name_whisper},
            {name = "light_flicker", chance = base_mult * 2 * freq, func = self.ability_light_flicker},
            {name = "freeze_player", chance = base_mult * 0.8 * freq, func = self.ability_freeze_player},
            {name = "fog_gen", chance = base_mult * 0.5 * freq, func = self.ability_fog_gen},
            {name = "jumpscare", chance = base_mult * 0.4 * freq, func = self.ability_jumpscare},
            {name = "env_manipulate", chance = base_mult * 0.3 * freq, func = self.ability_env_manipulate},
            {name = "size_change", chance = base_mult * 0.8 * freq, func = self.ability_size_change},
            {name = "clone_surround", chance = 0.0001, func = self.ability_clone_surround},
            {name = "mirror_appear", chance = base_mult * 0.5 * freq, func = self.ability_mirror_appear},
            {name = "block_decay", chance = base_mult * 1 * freq, func = self.ability_block_decay},
            {name = "window_peek", chance = base_mult * 1 * freq, func = self.ability_window_peek},
        }

        local shuffled = {}
        for i, v in ipairs(abilities) do
            local j = random(1, i)
            shuffled[i] = shuffled[j]
            shuffled[j] = v
        end

        for _, ability in ipairs(shuffled) do
            if self:is_ability_ready(ability.name) and random() < ability.chance then
                ability.func(self, target, distance)
                self:set_ability_cooldown(ability.name)
                self.abilities_used_this_spawn = self.abilities_used_this_spawn + 1
                self.last_ability_time = 0
                self.ability_delay = random(5, 10)
                break
            end
        end
    end,

    ability_whisper = function(self, target, distance)
        oh.send_whisper(target)
    end,

    ability_teleport = function(self, target, distance)
        if not is_valid_entity(self) or distance <= 20 then return end

        local new_distance = distance * 0.5
        local tpos = target:get_pos()
        if not tpos then return end

        local dir = vec_dir(tpos, self.object:get_pos())
        local new_pos = vec_add(tpos, vec_mul(dir, new_distance))
        new_pos.y = tpos.y

        oh.create_particles(self.object:get_pos(), "default_obsidian.png", 20, 0.5)
        self.object:set_pos(new_pos)
        oh.play_sound(target, "obelisk_analog_random_voice", 0.5)

        if random() < 0.2 then
            self:enter_crazy_mode()
            self.state = STATE.CHASING
        end
    end,

    ability_invisibility = function(self, target, distance)
        if random() < 0.3 then
            self.invisible = true
            self.invisible_timer = 3
        else
            self.blinky = true
            self.invisible_timer = 5
        end
        self:update_visuals()
    end,

    ability_speed_change = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local entity_ref = self.object
        local base = self.base_speed

        if random() < 0.5 then
            self.current_speed = base * 0.3
            minetest.after(3, function()
                if entity_ref and entity_ref:get_pos() then
                    local lua = entity_ref:get_luaentity()
                    if lua then
                        lua.current_speed = base * 3
                        minetest.after(2, function()
                            if entity_ref and entity_ref:get_pos() then
                                local lua2 = entity_ref:get_luaentity()
                                if lua2 then
                                    lua2.current_speed = base
                                end
                            end
                        end)
                    end
                end
            end)
        else
            self.current_speed = base * (0.5 + random() * 2)
        end
    end,

    ability_torch_destroy = function(self, target, distance)
        local tpos = target:get_pos()
        if not tpos then return end

        local torch_range = {x = 15, y = 15, z = 15}
        local torches = minetest.find_nodes_in_area(
            vec_sub(tpos, torch_range),
            vec_add(tpos, torch_range),
            {"default:torch", "default:torch_wall", "default:torch_ceiling"}
        )

        if #torches > 0 then
            local torch_pos = torches[random(#torches)]
            minetest.remove_node(torch_pos)
            minetest.sound_play("obelisk_analog_crack_sound", {pos = torch_pos, gain = 0.5})
        end
    end,

    ability_door_interact = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local tpos = target:get_pos()
        if not tpos then return end

        local door_range = {x = 20, y = 20, z = 20}
        local doors = minetest.find_nodes_in_area(
            vec_sub(tpos, door_range),
            vec_add(tpos, door_range),
            {"group:door"}
        )

        if #doors > 0 then
            local door_pos = doors[random(#doors)]
            local node = minetest.get_node(door_pos)
            local def = minetest.registered_nodes[node.name]

            if def and def.on_rightclick then
                pcall(def.on_rightclick, door_pos, node, nil, nil, nil)
            end

            minetest.sound_play("obelisk_analog_endless_house_creaking", {pos = door_pos, gain = 0.8})

            if random() < 0.2 then
                local spawn_pos = vec_add(door_pos, {x = 0, y = 0, z = 1})
                self.object:set_pos(spawn_pos)
                self.state = STATE.IDLE
                self.state_timer = 0
            end
        end
    end,

    ability_sound_distort = function(self, target, distance)
        local sounds = {
            "obelisk_analog_random_voice",
            "obelisk_analog_crack_sound",
            "obelisk_analog_endless_house_creaking",
        }
        oh.play_sound(target, sounds[random(#sounds)], random() * 0.5 + 0.3)
    end,

    ability_item_steal = function(self, target, distance)
        local inv = target:get_inventory()
        if not inv then return end

        local main = inv:get_list("main")
        if not main then return end

        local items_with_index = {}
        for i, stack in ipairs(main) do
            if not stack:is_empty() then
                table.insert(items_with_index, i)
            end
        end

        if #items_with_index > 0 then
            local steal_index = items_with_index[random(#items_with_index)]
            inv:set_stack("main", steal_index, ItemStack(""))
            oh.send_whisper(target, "Something is missing...")

            local pdata = oh.player_data[target:get_player_name()]
            if pdata then
                pdata.items_stolen = (pdata.items_stolen or 0) + 1
            end
        end
    end,

    ability_inventory_shuffle = function(self, target, distance)
        local inv = target:get_inventory()
        if not inv then return end

        local main = inv:get_list("main")
        if not main then return end

        for i = #main, 2, -1 do
            local j = random(i)
            main[i], main[j] = main[j], main[i]
        end

        inv:set_list("main", main)
        oh.send_whisper(target, "Your belongings shift...")
    end,

    ability_behind_spawn = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local spawn_pos = oh.find_spawn_pos_behind_player(target)
        if not spawn_pos then return end

        spawn_pos = vec_add(spawn_pos, vec_mul(target:get_look_dir(), -5))
        self.object:set_pos(spawn_pos)

        if random() < 0.3 then
            local entity_ref = self.object
            local target_name = target:get_player_name()
            minetest.after(1, function()
                if entity_ref and entity_ref:get_pos() then
                    local lua = entity_ref:get_luaentity()
                    local t = minetest.get_player_by_name(target_name)
                    if lua and t then
                        lua:disappear_and_respawn(t)
                    end
                end
            end)
        end
    end,

    ability_corner_watch = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local tpos = target:get_pos()
        if not tpos then return end

        local corners = {}
        for x = -20, 20, 10 do
            for z = -20, 20, 10 do
                local corner_pos = {x = tpos.x + x, y = tpos.y, z = tpos.z + z}
                local node = minetest.get_node(corner_pos)
                if node.name ~= "air" then
                    table.insert(corners, corner_pos)
                end
            end
        end

        if #corners > 0 then
            local corner = corners[random(#corners)]
            corner.y = corner.y + 1
            self.object:set_pos(corner)
            self.state = STATE.CORNER_WATCH
            self.state_timer = 0
        end
    end,

    ability_ceiling_hang = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local tpos = target:get_pos()
        if not tpos then return end

        local ceiling_pos = {
            x = tpos.x + random(-10, 10),
            y = tpos.y + 5,
            z = tpos.z + random(-10, 10)
        }

        for y = 0, 10 do
            local check_pos = {x = ceiling_pos.x, y = tpos.y + y, z = ceiling_pos.z}
            local node = minetest.get_node(check_pos)
            if node.name ~= "air" then
                ceiling_pos.y = check_pos.y - 1
                break
            end
        end

        self.object:set_pos(ceiling_pos)
        self.is_upside_down = true
        self.state = STATE.CEILING_HANG
        self.state_timer = 0
        self:face_player(target)
    end,

    ability_wall_phase = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local tpos = target:get_pos()
        if not tpos then return end

        local look_dir = target:get_look_dir()
        local wall_check = vec_add(tpos, vec_mul(look_dir, 5))

        local node = minetest.get_node(wall_check)
        if node.name ~= "air" then
            self.object:set_pos(wall_check)

            if random() < 0.2 then
                local entity_ref = self.object
                local target_name = target:get_player_name()
                minetest.after(0.5, function()
                    if entity_ref and entity_ref:get_pos() then
                        local t = minetest.get_player_by_name(target_name)
                        if t then
                            oh.show_jumpscare(t, 0.3)
                        end
                    end
                end)
            end
        end
    end,

    ability_name_whisper = function(self, target, distance)
        local name = target:get_player_name()
        minetest.chat_send_player(name, minetest.colorize("#8B0000", name .. "..."))
    end,

    ability_light_flicker = function(self, target, distance)
        local tpos = target:get_pos()
        if not tpos then return end

        local light_range = {x = 20, y = 20, z = 20}
        local lights = minetest.find_nodes_in_area(
            vec_sub(tpos, light_range),
            vec_add(tpos, light_range),
            {"default:torch", "default:torch_wall", "default:torch_ceiling"}
        )

        for _, light_pos in ipairs(lights) do
            local node = minetest.get_node(light_pos)
            local node_name = node.name
            local param2 = node.param2

            minetest.swap_node(light_pos, {name = "air"})
            minetest.after(0.2, function()
                minetest.swap_node(light_pos, {name = node_name, param2 = param2})
            end)
            minetest.after(0.4, function()
                minetest.swap_node(light_pos, {name = "air"})
            end)
            minetest.after(0.6, function()
                minetest.swap_node(light_pos, {name = node_name, param2 = param2})
            end)
        end
    end,

    ability_freeze_player = function(self, target, distance)
        oh.freeze_player(target, 2)
        oh.send_whisper(target, "You cannot move...")
    end,

    ability_fog_gen = function(self, target, distance)
        local tpos = target:get_pos()
        if not tpos then return end

        oh.create_particles(tpos, "default_cloud.png^[colorize:#888888:200", 100, 5, {
            spread = 10,
            minvel = {x = -0.5, y = 0, z = -0.5},
            maxvel = {x = 0.5, y = 0.2, z = 0.5},
            minexptime = 3,
            maxexptime = 5,
            minsize = 5,
            maxsize = 10,
            glow = 1,
        })
    end,

    ability_jumpscare = function(self, target, distance)
        if distance < 15 then
            oh.show_jumpscare(target, 0.5)
        end
    end,

    ability_env_manipulate = function(self, target, distance)
        local effect = random(1, 4)
        local tpos = target:get_pos()

        if effect == 1 then
            for i = 1, 5 do
                minetest.after(i * 0.5, function()
                    local time = (i % 2 == 0) and 0.0 or 0.5
                    minetest.set_timeofday(time)
                end)
            end
        elseif effect == 2 then
            for i = 1, 10 do
                minetest.after(i * 0.2, function()
                    minetest.set_timeofday(random())
                end)
            end
        elseif effect == 3 and tpos then
            local leaf_range = {x = 30, y = 30, z = 30}
            local leaves = minetest.find_nodes_in_area(
                vec_sub(tpos, leaf_range),
                vec_add(tpos, leaf_range),
                {"group:leaves"}
            )
            for _, leaf_pos in ipairs(leaves) do
                if random() < 0.3 then
                    minetest.swap_node(leaf_pos, {name = "obelisk_analog:dead_leaves"})
                end
            end
        elseif effect == 4 then
            local start_time = minetest.get_timeofday()
            for i = 1, 20 do
                minetest.after(i * 0.3, function()
                    local new_time = start_time - (i * 0.02)
                    if new_time < 0 then new_time = new_time + 1 end
                    minetest.set_timeofday(new_time)
                end)
            end
        end
    end,

    ability_size_change = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local new_size = 0.5 + random() * 2
        self.size_multiplier = new_size
        self:update_visuals()

        local entity_ref = self.object
        minetest.after(10, function()
            if entity_ref and entity_ref:get_pos() then
                local lua = entity_ref:get_luaentity()
                if lua then
                    lua.size_multiplier = 1
                    lua:update_visuals()
                end
            end
        end)
    end,

    ability_clone_surround = function(self, target, distance)
        local tpos = target:get_pos()
        if not tpos then return end

        for i = 1, 8 do
            local angle = (i / 8) * math.pi * 2
            local clone_pos = {
                x = tpos.x + math.cos(angle) * 5,
                y = tpos.y,
                z = tpos.z + math.sin(angle) * 5,
            }
            minetest.add_entity(clone_pos, "obelisk_analog:clone")
        end

        oh.send_whisper(target, "YOU ARE SURROUNDED")
        oh.show_jumpscare(target, 1)
    end,

    ability_mirror_appear = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local tpos = target:get_pos()
        if not tpos then return end

        local look_dir = target:get_look_dir()
        local mirror_pos = vec_add(tpos, vec_mul(look_dir, 10))

        self.object:set_pos(mirror_pos)
        self.object:set_properties({
            textures = {
                "entity_model.png^[colorize:#FFFFFF:100",
                "entity_model.png^[colorize:#FFFFFF:100"
            }
        })

        local entity_ref = self.object
        minetest.after(3, function()
            if entity_ref and entity_ref:get_pos() then
                entity_ref:set_properties({
                    textures = {"entity_model.png", "entity_model.png"}
                })
            end
        end)
    end,

    ability_block_decay = function(self, target, distance)
        local tpos = target:get_pos()
        if not tpos then return end

        for i = 1, 5 do
            minetest.after(i * 0.5, function()
                local decay_pos = {
                    x = tpos.x + random(-5, 5),
                    y = tpos.y + random(-2, 2),
                    z = tpos.z + random(-5, 5),
                }
                local node = minetest.get_node(decay_pos)
                if node.name ~= "air" and minetest.get_item_group(node.name, "unbreakable") == 0 then
                    oh.create_particles(decay_pos, "default_dirt.png", 10, 0.5)
                    minetest.remove_node(decay_pos)
                end
            end)
        end
    end,

    ability_window_peek = function(self, target, distance)
        if not is_valid_entity(self) then return end

        local tpos = target:get_pos()
        if not tpos then return end

        local search_range = {x = 20, y = 20, z = 20}
        local windows = minetest.find_nodes_in_area(
            vec_sub(tpos, search_range),
            vec_add(tpos, search_range),
            {"default:glass", "default:obsidian_glass"}
        )

        if #windows > 0 then
            local window = windows[random(#windows)]
            local offset_y = random() < 0.5 and -1 or 0
            self.object:set_pos({x = window.x, y = window.y + offset_y, z = window.z})
            self.state = STATE.WINDOW_PEEK
            self.state_timer = 0
        end
    end,

    disappear_and_respawn = function(self, target)
        if not is_valid_entity(self) then return end
        if not target then return end

        local pos = self.object:get_pos()
        oh.create_particles(pos, "default_obsidian.png", 30, 0.5, {
            minvel = {x = -2, y = -2, z = -2},
            maxvel = {x = 2, y = 2, z = 2},
        })

        local spawn_pos = oh.find_spawn_pos_behind_player(target)
        if spawn_pos then
            self.object:set_pos(spawn_pos)
        end

        self.state = STATE.STALKING
        self.state_timer = 0
        self.crazy_mode = false
        self.crazy_mode_v2 = false
        self.pixelated = false
        self.frame_skip = false
        self:update_visuals()
    end,

    kill_player = function(self, target)
        if not target then return end

        oh.show_jumpscare(target, 1)

        local name = target:get_player_name()
        minetest.after(0.5, function()
            local p = minetest.get_player_by_name(name)
            if p then
                p:set_hp(0, {type = "punch", from = "obelisk_analog"})
            end
        end)

        local now = minetest.get_gametime()
        oh.global_spawn_cooldown_until = now + (C.ENTITY.GLOBAL_COOLDOWN_AFTER_KILL or 900)
        self:remove_entity()
    end,

    remove_entity = function(self)
        oh.entity_active = false
        oh.current_entity = nil
        if self.object then
            self.object:remove()
        end
    end,

    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        if not puncher or not puncher:is_player() then return end

        self.hit_count = self.hit_count + 1

        local hit_messages = {
            "You cannot kill me...",
            "That tickles...",
            "Is that all?",
            "Futile...",
            "I am eternal...",
        }

        if self.no_escape_mode then
            self.no_escape_hits = self.no_escape_hits - 1
            if self.no_escape_hits <= 0 then
                self:escape_temporarily(puncher)
                return
            end

            if self.state ~= STATE.NO_ESCAPE then
                self.state = STATE.NO_ESCAPE
                self.state_timer = 0
                oh.send_whisper(puncher, "YOU CANNOT BANISH ME")
            end
            return
        end

        if self.hit_count >= self.hits_to_escape then
            self:escape_temporarily(puncher)
            return
        end

        if random() < 0.15 then
            oh.send_whisper(puncher, hit_messages[random(#hit_messages)])
        end

        if random() < 0.05 then
            self.crazy_mode_v2 = true
            self:enter_crazy_mode()
            self.state = STATE.CHASING
            oh.send_whisper(puncher, "YOU SHOULDN'T HAVE DONE THAT")
        elseif random() < 0.4 then
            self:disappear_and_respawn(puncher)
        elseif random() < 0.2 then
            self:vanish_temporarily(puncher)
        end
    end,

    vanish_temporarily = function(self, target)
        if not is_valid_entity(self) then return end

        local pos = self.object:get_pos()
        oh.create_particles(pos, "default_obsidian.png^[colorize:#2a0050:180", 40, 0.8, {
            minvel = {x = -2, y = -2, z = -2},
            maxvel = {x = 2, y = 2, z = 2},
            glow = 5,
        })

        local player_name = nil
        if target and target:is_player() then
            player_name = target:get_player_name()
            local vanish_messages = {
                "I'll be watching...",
                "For now...",
                "Don't relax...",
                "I'm never far...",
            }
            oh.send_whisper(target, vanish_messages[random(#vanish_messages)])
        end

        self:remove_entity()

        if player_name then
            local reappear_time = random(20, 80)
            minetest.after(reappear_time, function()
                local p = minetest.get_player_by_name(player_name)
                if p and not oh.entity_active then
                    oh.spawn_entity_near_player(p)
                end
            end)
        end
    end,

    escape_temporarily = function(self, player)
        if not is_valid_entity(self) then return end

        local pos = self.object:get_pos()
        oh.create_particles(pos, "default_obsidian.png^[colorize:#4B0082:200", 50, 1, {
            minvel = {x = -3, y = -3, z = -3},
            maxvel = {x = 3, y = 3, z = 3},
            glow = 10,
        })

        local player_name = nil
        if player and player:is_player() then
            player_name = player:get_player_name()
            local laugh_messages = {
                "Hehehehe... I'll be back...",
                "You think you've won? HAHAHA!",
                "Running won't save you forever...",
                "Until next time... hehe...",
                "I'll find you again... HAHAHAHA!",
            }
            oh.send_whisper(player, laugh_messages[random(#laugh_messages)])
            oh.play_sound(player, "obelisk_analog_random_voice", 1.0)
        end

        self:remove_entity()

        if player_name then
            local respawn_time = random(C.ENTITY.RESPAWN_TIME_MIN, C.ENTITY.RESPAWN_TIME_MAX)
            minetest.after(respawn_time, function()
                local p = minetest.get_player_by_name(player_name)
                if p and not oh.entity_active then
                    oh.spawn_entity_near_player(p)
                    oh.send_whisper(p, "I told you I'd be back...")
                end
            end)
        end
    end,
}

minetest.register_entity("obelisk_analog:entity", entity_def)

local clone_def = {
    initial_properties = {
        physical = false,
        collisionbox = {0, 0, 0, 0, 0, 0},
        visual = "upright_sprite",
        textures = {"entity_model.png", "entity_model.png"},
        visual_size = {x = 2, y = 3, z = 2},
        spritediv = {x = 1, y = 1},
        static_save = false,
        glow = 3,
    },

    timer = 0,
    max_life = 3,

    on_activate = function(self, staticdata, dtime_s)
        self.timer = 0
        self.max_life = 2 + random() * 2
    end,

    on_step = function(self, dtime)
        self.timer = self.timer + dtime

        local pos = self.object:get_pos()
        if not pos then
            self.object:remove()
            return
        end

        local offset = {
            x = (random() - 0.5) * 0.2,
            y = (random() - 0.5) * 0.1,
            z = (random() - 0.5) * 0.2,
        }
        self.object:set_pos(vec_add(pos, offset))

        if self.timer > self.max_life then
            oh.create_particles(pos, "default_obsidian.png", 20, 0.3)
            self.object:remove()
        end
    end,
}

minetest.register_entity("obelisk_analog:clone", clone_def)
