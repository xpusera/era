# Fork APIs

This fork adds Android `htmlview` APIs and upgrades glTF animation support.

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

## Pocket dimensions (engine + Lua)

This fork adds a minimal engine layer system to support parallel "pocket" dimensions on the same coordinates.

### Entity visibility layers (Lua)

`ObjectRef:set_layer(layer)` / `ObjectRef:get_layer()`

- Default layer for all objects is `"main"`.
- Objects are only sent to clients whose player layer matches the object's layer.
- Special value: `"*"` makes an object visible to all layers.

### Per-layer node overrides (Lua)

`minetest.layer_set_node(pos, node, layer) -> boolean`

- Sets a per-layer node override that only affects mapblocks sent to players in `layer`.
- Does not modify the real map node.

`minetest.layer_get_node(pos, layer) -> node_or_nil`

- Returns the override node table, or `nil` if there is no override.

`minetest.layer_remove_node(pos, layer) -> boolean`

- Removes an override.

### Pocket mod

This fork ships a mod at `mods/pocket` that implements a Lua-driven pocket dimension API:

- `pocket.register(name, def)`
- `pocket.enter(player, name)` / `pocket.leave(player)`
- `pocket.set_node/get_node/remove_node(pos, layer)` wrappers
- Auto-loads `dimensions/<name>/init.lua` from every enabled mod

A small test mod is included at `mods/pocket_test`.
