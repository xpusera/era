# Fork APIs

This fork adds Android `htmlview` (including headless workers + JSON helpers), extra animator helpers, and glTF multi-clip animation support.

## Android: `htmlview` (Lua)

Android-only. On non-Android platforms, calling these functions errors.

Lifecycle note: HTMLViews are owned by the Android activity layout. This fork destroys all active HTMLViews when leaving a world / stopping the server.

### Creating instances

`htmlview.run(id, html)`
- `id`: string
- `html`: string (inline HTML)

`htmlview.run_external(id, root_dir, entry?)`
- `root_dir`: string (directory containing HTML files)
- `entry`: string (default `"index.html"`)
- `root_dir` is sandbox-checked.

### Headless workers (no visible view attached)

`htmlview.run_worker(id, html)`

`htmlview.run_external_worker(id, root_dir, entry?)`

Workers still support `send`, `inject`, `navigate`, and `on_message`, but `display`/`focus` are ignored.

### Showing / positioning

`htmlview.display(id, opts)`
- `opts`:
  - `visible`: boolean (default `true`)
  - `safe_area`: boolean (default `true`)
  - `fullscreen`: boolean (default `false`)
  - `drag_embed` / `draggable`: boolean (default `false`)
  - `border_radius`: number (default `0`)
  - `x`, `y`: number or string `"center"`
  - `width`, `height`: number or string `"fullscreen"`

`htmlview.focus(id)`
- Brings that HTMLView on top when multiple are open.

### Stopping

`htmlview.stop(id)`

### Messaging

`htmlview.send(id, message)`
- `message`: string

`htmlview.send_json(id, value)`
- Encodes a Lua value to JSON and sends it as a string.

`htmlview.on_message(id, cb_or_nil)`
- `cb(message_string)`

`htmlview.on_message_json(id, cb_or_nil)`
- On success: `cb(decoded_table, raw_string)`
- On parse error: `cb(nil, raw_string, error_string)`

`htmlview.pipe(from_id, to_id)`
- Forwards messages from one HTMLView instance to another.

### Navigation / JS

`htmlview.navigate(id, url)`

`htmlview.inject(id, js)`

`htmlview.reload(id)`
- Reloads without destroying the instance.
- For `run_external*`, reloads the current entry.
- For `run*`, reloads the last provided HTML.

### Capture

`htmlview.capture(id, opts?)`
- `opts`:
  - `width`: int (0 = default)
  - `height`: int (0 = default)

`htmlview.on_capture(id, cb_or_nil)`
- `cb(png_bytes)` where `png_bytes` is a Lua string containing PNG file bytes.

### Input control

`htmlview.input(id, opts)`
- `opts`:
  - `block_game_input`: boolean (default `false`)
- When enabled and the view is visible, touches outside the HTMLView are swallowed (prevents interacting with the world behind it).

### State query

`htmlview.state(id) -> table | nil`
- Returns `nil` on error, otherwise a table:
  - `exists`: boolean
  - `worker`: boolean
  - `visible`: boolean
  - `ready`: boolean (`true` after `onPageFinished`)

## glTF multi-clip animation (Lua)

glTF/GLB meshes can contain multiple animations. This fork loads each glTF `animations[i]` as a selectable clip.

`ObjectRef:set_animation(frame_range, frame_speed, frame_blend, frame_loop)`
- Legacy form.
- Also clears any previously selected glTF clip.

`ObjectRef:set_animation(opts)`
- New table form (pass only what you need):
  - `clip`: number (0-based) or string (clip name)
  - `range` / `frame_range`: `{x=..., y=...}`
  - `frame`: number (sets `{frame, frame}`)
  - `speed` / `frame_speed`: number
  - `speed_scale`: number (multiplies the chosen speed)
  - `blend` / `frame_blend`: number
  - `loop` / `frame_loop`: boolean
  - `pause` / `paused`: boolean (sets speed to `0`)

`ObjectRef:set_animation_clip(clip, frame_range, frame_speed, frame_blend, frame_loop)`
- Explicit clip selection.

`ObjectRef:get_animation() -> frame_range, frame_speed, frame_blend, frame_loop, clip`

`ObjectRef:get_animation_info() -> table`
- Returns `{ range, speed, blend, loop, clip, duration, progress=nil, bones=nil }`.
- `progress`/`bones` are placeholders (not currently available from the engine).

### Crossfade blending

For skinned meshes (including glTF), `frame_blend` controls crossfade duration (seconds) when switching animations.

## glTF inspection helpers (Lua)

`core.gltf_get_animation_clips(path) -> list`
- Returns `{ {index,name,start,end,duration}, ... }`.

`core.gltf_inspect(path) -> table`
- Returns:
  - `meshes`: `{ {index,name,primitives}, ... }`
  - `bones`: `{ {node,name}, ... }` (joint nodes across skins)
  - `animations`: `{ {index,name,start,end,duration}, ... }`

## Lua Animator (`core.animator`)

`core.animator.create(object, def)`
- State machine + events + additive layers.

`core.animator.register(animator)`
- Auto-updates each globalstep.

### Global animator event bus

`core.animator.register_on_event(cb)`
`core.animator.unregister_on_event(cb)`
- `cb(animator, object, event_payload)` called for every emitted animation event.

### Humanoid helper

`core.animator.humanoid(object, clips, opts?) -> animator`
- Builds a basic `idle/walk/run/jump/attack` state machine.
- Uses default context `hs` (horizontal speed). For `jump`/`attack`, provide `opts.get_context` that sets `ctx.jumping` / `ctx.attack`.

### Animation end helper

`core.on_animation_end(object, cb)` (alias for `core.animator.on_animation_end`)
- Calls `cb(object)` when the current non-looping animation is expected to end (computed from `ObjectRef:get_animation()`).

## Fog API (Lua)

Extended volumetric and height-based fog controls.

`core.set_fog(player, params_or_nil)`
- Sets custom fog parameters for a specific player. Pass `nil` to clear.
- `params`:
  - `color`: ColorSpec (default: sky fog color)
  - `fog_start`: number (0..0.99, fraction of view distance)
  - `fog_end`: number (0..1, fraction of view distance)
  - `blend_time`: number (seconds, transition duration)
  - `max_density`: number (0..1, opacity at max height)
  - `max_density_height`: number (node-space height for max density)
  - `zero_density_height`: number (node-space height where fog disappears)
  - `uniform`: boolean (if true, ignores height density)
  - `direction`: v3f (up vector for height calculation, default `{x=0,y=1,z=0}`)
  - `turbulence`: number (0..1, noise factor)
  - `speed_density_scale`: number (multiplier for density based on player speed)
  - `layers`: list of table (up to 4 extra fog layers):
    - `color`, `max_density`, `max_density_height`, `zero_density_height`, `uniform`, `direction`
  - `color_transition`: table (dynamic color animation):
    - `speed`: number (animation speed)
    - Array of keyframes or `keyframes` field:
      - `{ time=number(0..1), color=ColorSpec }`

`core.set_fog_boundary(player, params_or_nil)`
- Defines a localized fog zone.
- `params`:
  - `pos`: v3f (center of the zone)
  - `radius`: number (node-space size)
  - `shape`: string (`"sphere"`, `"box"`, `"cylinder"`)
  - `fog`: table (FogParams structure as defined above)
  - `sound`: table (optional ambient sound inside zone):
    - `name`: string
    - `gain`: number
    - `fade_in`: number (seconds)

`core.register_biome_atmosphere(biome_id, params)`
- Registers fog and/or boundary parameters for a specific biome.
- `params`:
  - `fog`: table (FogParams)
  - `boundary`: table (FogBoundaryParams)
