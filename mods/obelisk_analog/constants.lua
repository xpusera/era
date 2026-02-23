local C = {}

C.DIMENSION = {
    SEQUENCE_Y = 10000,
    WONDERLAND_Y = 20000,
    CORNERS_Y = 30000,
    ENDLESS_HOUSE_Y = 30500,
    HEIGHT = 200,
    VOID_THRESHOLD = 500,
}

C.ENTITY = {
    BASE_SPEED = 2,
    COLLISION_BOX = {-0.4, 0, -0.4, 0.4, 2.5, 0.4},
    VISUAL_SIZE = {x = 2, y = 3, z = 2},
    SPAWN_DISTANCE_MIN = 15,
    SPAWN_DISTANCE_MAX = 30,
    STUCK_THRESHOLD = 5,
    HITS_TO_ESCAPE_MIN = 4,
    HITS_TO_ESCAPE_MAX = 8,
    RESPAWN_TIME_MIN = 120,
    RESPAWN_TIME_MAX = 300,
    KILL_DISTANCE = 2,
    CHASE_TIMEOUT = 12,
    STALK_DISTANCE = 12,
    PER_PLAYER_SPAWN_COOLDOWN = 600,
    GLOBAL_COOLDOWN_AFTER_KILL = 900,
    MIN_STALK_TIME_BEFORE_CHASE = 20,
    MAX_CHASES_PER_SPAWN = 1,
}

C.TIMERS = {
    SPAWN_CHECK = 45,
    DAY_CHECK = 60,
    GOD_MODE_CHECK = 0.3,
    TIME_CONTROL = 1,
    AMBIENT = 90,
    PHASE_EFFECTS = 45,
    NIGHT_EMPOWER = 15,
    SPECIAL_EVENT = 400,
    PORTAL_PARTICLES = 2,
    ABILITY_CHECK = 5,
}

C.ABILITY_COOLDOWNS = {
    whisper = 15,
    teleport = 30,
    invisibility = 40,
    speed_change = 25,
    torch_destroy = 20,
    door_interact = 25,
    sound_distort = 10,
    item_steal = 60,
    inventory_shuffle = 90,
    behind_spawn = 20,
    corner_watch = 30,
    ceiling_hang = 40,
    wall_phase = 25,
    name_whisper = 45,
    light_flicker = 20,
    freeze_player = 50,
    fog_gen = 50,
    jumpscare = 45,
    env_manipulate = 80,
    size_change = 30,
    clone_surround = 900,
    mirror_appear = 35,
    block_decay = 40,
    window_peek = 30,
}

C.LIGHT = {
    DARK_THRESHOLD = 8,
    PORTAL_GLOW = 8,
    RITUAL_GLOW = 5,
}

C.GRID = {
    SEQUENCE_SIZE = 20,
    SEQUENCE_CUBE_HEIGHT = 25,
    WONDERLAND_TREE_SPACING = 15,
    CORNERS_CELL_SIZE = 20,
    CORNERS_PASSAGE_WIDTH = 4,
    CORNERS_WALL_HEIGHT = 30,
}

C.STRUCTURE = {
    HOUSE_SPAWN_CHANCE = 0.05,
    SHRINE_SPAWN_CHANCE = 0.03,
    SIGN_SPAWN_CHANCE = 0.08,
    RITUAL_SPAWN_CHANCE = 0.02,
    GRAVE_SPAWN_CHANCE = 0.04,
    TOWER_SPAWN_CHANCE = 0.02,
    WELL_SPAWN_CHANCE = 0.03,
}

C.FOV_MULTIPLIER = {
    MIN = 0.8,
    MAX = 1.2,
}

C.NIGHT = {
    START = 0.75,
    END = 0.25,
}

C.PHASE = {
    MIN = 1,
    MAX = 5,
    DAYS_PER_ADVANCE = 5,
}

return C
