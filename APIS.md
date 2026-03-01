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
