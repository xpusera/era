# Fork APIs

This fork adds Android `htmlview` APIs and upgrades glTF animation support.

## Camera control (Lua)

Server-driven per-player camera control, synced to the client.

`core.camera.set(player, preset, opts)`
- `player`: `ObjectRef` (player)
- `preset`: string
  - `"first_person"`
  - `"third_person"`
  - `"third_person_front"`
  - `"free"`
  - `"follow_orbit"`
- `opts`: table (preset-specific)
  - `ease`: optional `{ time = number, type = string }`
    - `type`: `"linear" | "in_cubic" | "out_cubic" | "in_out_cubic" | "out_back"`
  - `lock_input`: optional boolean (default `false`)
  - `fov`: optional number (degrees). For `first_person`/`third_person` presets.

`core.camera.clear(player, opts?)`
- Resets camera to default.
- Optional `opts.ease` for smooth transition.

`core.camera.shake(player, { intensity, duration, decay })`

`core.camera.fade(player, { color, fade_in, hold, fade_out, callback? })`
- `color`: `"#RRGGBB"` or `"#RRGGBBAA"`
- `callback`: called when the `hold` phase starts.

### `free` preset options

`core.camera.set(player, "free", { pos, facing?, rot?, ease?, lock_input? })`
- `pos`: `{x,y,z}` (world pos)
- `facing`: `{x,y,z}` look-at point (optional)
- `rot`: `{x,y,z}` Euler degrees (optional)

### `follow_orbit` preset options

`core.camera.set(player, "follow_orbit", { target, radius, yaw_offset, pitch_offset, view_offset })`
- `target`: entity `ObjectRef` or position table
- `view_offset`: `{x,y,z}`

## Android: `htmlview` (Lua)

Available only on Android builds. On non-Android platforms, calling these functions errors.

`htmlview.run(id, html)`
- `id`: string (instance id)
- `html`: string (HTML source)

`htmlview.run_external(id, root_dir, entry?)`
- `root_dir`: string (directory containing HTML files)
- `entry`: string (default: `"index.html"`)
- Notes: `root_dir` is sandbox-checked.

`htmlview.stop(id)`

`htmlview.display(id, opts)`
- `opts`: table
  - `visible`: boolean (default `true`)
  - `safe_area`: boolean (default `true`)
  - `fullscreen`: boolean (default `false`)
  - `drag_embed` / `draggable`: boolean (default `false`)
  - `border_radius`: number (default `0`)
  - `x`, `y`: number or string `"center"`
  - `width`, `height`: number or string `"fullscreen"`

`htmlview.send(id, message)`
- `message`: string

`htmlview.navigate(id, url)`

`htmlview.inject(id, js)`
- `js`: string (JavaScript)

`htmlview.pipe(from_id, to_id)`
- Pipes messages from one HTMLView instance to another.

`htmlview.capture(id, opts?)`
- `opts`: optional table
  - `width`: int (0 = default)
  - `height`: int (0 = default)

`htmlview.on_message(id, callback_or_nil)`
- Registers/clears a callback for messages coming from the HTML view.
- Callback signature: `callback(message)`

`htmlview.on_capture(id, callback_or_nil)`
- Registers/clears a callback for `htmlview.capture`.
- Callback signature: `callback(png_bytes)` where `png_bytes` is a Lua string containing PNG file bytes.

## glTF multi-clip animation (Lua)

glTF/GLB meshes can contain multiple animations. This fork loads each glTF `animations[i]` as a selectable clip.

`ObjectRef:set_animation(frame_range, frame_speed, frame_blend, frame_loop)`
- Keeps legacy behavior.
- Also clears any previously selected glTF clip.

`ObjectRef:set_animation_clip(clip, frame_range, frame_speed, frame_blend, frame_loop)`
- Selects a glTF animation clip at runtime and starts the animation.
- `clip`:
  - number: 0-based clip index
  - string: clip name (from glTF `animations[i].name`)
- `frame_range` is relative to the chosen clip (0 = clip start).
- For non-glTF meshes, `clip` is ignored and this behaves like `set_animation`.

`ObjectRef:get_animation()`
- Returns: `frame_range, frame_speed, frame_blend, frame_loop, clip`
- `clip` is:
  - `nil` (no clip selected)
  - number (clip index)
  - string (clip name)

### Crossfade blending behavior

For skinned meshes (including glTF), `frame_blend` controls crossfade duration (seconds) when switching animations.

- Previous clip continues advancing during the blend (it does not freeze on the switch frame).
- Target clip starts at the requested `frame_range` start and advances during the blend.

## Lua Animator layer (state machine + events + additive layers)

This fork ships a built-in Lua module `core.animator` (loaded from `builtin/common/animator.lua`). It provides:

- Animation state machines (idle/walk/run/jump/attack...)
- Crossfade transitions (uses `frame_blend` when applying states)
- Frame-based animation events (footsteps, hit frames, particle spawns, etc.)
- Optional additive bone layers (implemented via bone overrides)

### `core.animator.create(object, def)`

Creates an animator instance (does not auto-run).

- `object`: `ObjectRef`
- `def`: table
  - `states`: `{[name] = state_def, ...}`
  - `transitions`: `{ transition_def, ... }`
  - `initial`: state name
  - `get_context(self, object, dtime) -> table`: optional
  - `on_event(self, object, event)`: optional
  - `on_step(self, object, dtime, ctx)`: optional

`state_def`:
- `clip`: `nil` (non-glTF / legacy) or clip selector (0-based index or clip name string)
- `range`: `{x=..., y=...}` (relative to clip when using `clip`)
- `speed`: number (frames/sec)
- `loop`: boolean (default `true`)
- `blend`: number (seconds, default `0`)
- `events`: optional list `{ {name=string, frame=number, data=any, callback=function?}, ... }`

`transition_def`:
- `from`: state name or `"*"`
- `to`: state name
- `condition(ctx, self, object) -> boolean`
- `blend`: optional override blend seconds
- `priority`: optional number (higher wins)

### `core.animator.register(animator)`

Registers the animator to run automatically each globalstep (removed automatically when the object becomes invalid).

## Player model upgrade helpers (Lua)

### Equipment / mesh layering (bone attachments)

Use the engine's attachment system to attach equipment entities to bones:

- `child:set_attach(parent, bone, position, rotation, forced_visible)`

This works for animated meshes; attached objects follow the chosen bone.

### Bone-level control (Lua)

This fork adds a convenience API for per-bone rotation overrides:

`ObjectRef:set_bone_rotation(bone, x, y, z, opts?)`

- `bone`: string
- `x, y, z`: rotation in degrees
- `opts`: optional table
  - `absolute`: boolean (default `false`)
  - `interpolation`: number seconds (default `0`)

This is implemented using bone overrides (`set_bone_override`) and supports additive control when `absolute=false`.

### Additive animation layers (Lua)

Additive layers can be built on top of base animations using relative bone overrides:

- Use `ObjectRef:set_bone_override(bone, { rotation = { vec = <radians>, absolute = false } })`
- Or use `Animator:set_additive_layer(name, layer)` from `core.animator`

## Morph targets (optional)

- glTF morph target animation channels (`WEIGHTS`) are ignored (model still loads).
- If you need facial expressions/emotes today, emulate morphs via:
  - mesh swapping (`ObjectRef:set_properties({mesh=...})`)
  - bone scaling/rotation overrides on dedicated facial bones

## Particle spawner upgrades (Lua)

These extend `core.add_particlespawner({ ... })`.

### Emit from entity bone

`attached` can be a table:

- `attached = { object = entity_ref, bone = "bone_name", offset = vector.new(x,y,z) }`

If the bone cannot be resolved on the client, the spawner falls back to the entity origin.

### Color gradient over lifetime

`color_over_lifetime = { { t = 0.0, color = "#RRGGBBAA" }, ... }`

Colors are interpolated linearly between keyframes.

### Billboard facing modes

`face_camera` (string):
- `"rotate_xyz"` (default)
- `"rotate_y"`
- `"velocity"`
- `"world"`

### Per-particle spawn callback

`on_particle_spawn = function(index) return overrides end`

Supported override fields:
- `pos = {x,y,z}`
- `velocity = {x,y,z}`
- `acceleration = {x,y,z}`
- `size = number`
- `expirationtime = number`

Notes:
- When `on_particle_spawn` is provided, the spawner is simulated server-side and particles are sent as individual spawns.
- In this mode, `attached.bone` is ignored (server does not have access to client skeleton pose), and `color_over_lifetime` is not applied.
- Keep `amount` modest; the callback runs once per spawned particle.

## Per-player fog (Lua)

`core.set_fog(player, def_or_nil)`

`def_or_nil`:
- `nil`: clears fog override (returns to normal sky-driven fog)
- table:
  - `color`: `"#RRGGBB"` or `"#RRGGBBAA"`
  - `fog_start`: number (0..1 fraction of render distance)
  - `fog_end`: number (0..1 fraction of render distance)
  - `blend_time`: number seconds (default `0`)
  - `weather`: optional table `{ color, fog_start, fog_end }` (stored and synced; currently not auto-applied)

## Time-of-day sky keyframes (Lua)

`core.set_sky_keyframes(player, def_or_nil)`

`def_or_nil`:
- `nil`: clears sky keyframes (returns to normal sky colors)
- table:
  - array part: keyframes, each `{ time=0..1, sky=color, fog=color?, ambient=color? }`
  - `interpolation`: optional string (`"linear"` default, or `"cubic"`)

Notes:
- `sky` controls the upper sky color; `fog` controls horizon/fog color.
- `ambient` is currently applied to cloud ambient shading only (does not affect node lighting).
