# Review — myengine Registry and Lua Binding

## What This System Does
The `myengine` system provides a Lua-accessible API to get, set, and interact with C++ classes, methods, and properties. It uses an auto-generated registry to map Lua paths to internal C++ structures, and an alias layer to provide stable, public-facing mod paths that persist even when internal C++ structures are refactored.

## Key Files
- `src/myengine/aliases.h` — Defines the `AliasLayer` class for path translation.
- `src/myengine/aliases.cpp` — Implements path resolution and alias file loading.
- `src/myengine/registry.h` — Defines the `Registry` for mapping paths to C++ accessors.
- `src/myengine/registry.cpp` — Implements the backend for get/set/hook/watch/modify/rewrite.
- `src/script/lua_api/l_myengine.h` — Header for the `myengine` Lua API module.
- `src/script/lua_api/l_myengine.cpp` — Implements the Lua-to-C++ bindings for the `myengine` table.
- `myengine/alias_map.txt` — Human-maintained mapping of stable paths to internal paths.
- `src/script/scripting_server.cpp` — Initializes and registers the `myengine` API.
- `src/script/lua_api/l_base.cpp` — Provides base utilities for Lua-C++ interaction.
- `src/script/lua_api/l_internal.h` — Contains macros for registering Lua functions.

## How The Pieces Connect
1. **Lua Call**: A mod calls `myengine.get("stable.path")`.
2. **Lua Binding**: `ModApiMyEngine::l_get` in `l_myengine.cpp` is triggered.
3. **Alias Resolution**: It calls `AliasLayer::resolve("stable.path")`.
4. **Translation**: `AliasLayer` checks its in-memory map (loaded from `alias_map.txt`). If "stable.path" is found, it returns the real internal path (e.g., "internal.structure.value").
5. **Registry Lookup**: The system uses the resolved path to look up the corresponding C++ object or property in the `Registry`.
6. **Execution**: The `Registry` performs the requested operation (get/set/etc.) on the C++ side and returns the result to Lua.

## Locations Of Things
- `ModApiMyEngine::Initialize`: `src/script/lua_api/l_myengine.cpp`. Registers the `myengine` global table.
- `AliasLayer::load_aliases`: `src/myengine/aliases.cpp`. Reads `myengine/alias_map.txt` at startup.
- `AliasLayer::resolve`: `src/myengine/aliases.cpp`. Main entry point for path translation.
- `Registry::get/set/...`: `src/myengine/registry.cpp`. Handles the actual data access.

## Gotchas
- **Stale Aliases**: If an alias points to a real path that no longer exists in the C++ registry, the system must log a warning but not crash.
- **One-to-One**: Aliases are currently one-to-one; no wildcards are supported.
- **Resolution Order**: Aliases must be resolved *before* any registry lookup is attempted.
- **Bootstrapping**: The `AliasLayer` must be initialized early enough to be available when the first Lua scripts are loaded.

## Open Questions
- How is the "real internal path" registry generated? (Assumed to be an external build-time process for this task).
- Should aliases also support nested resolution (alias of an alias)? (Task says one-to-one, so likely not).
