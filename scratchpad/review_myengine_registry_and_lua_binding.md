# Review — myengine Registry and Lua Binding

## What This System Does
The `myengine` system provides a Lua-accessible API to get, set, and interact with C++ classes, methods, and properties. It consists of three layers:
1. **Auto-generated Registry**: A build-time scanner (`scanner.py`) extracts C++ entities from headers and registers them.
2. **Stable Alias Layer**: A translation table (`aliases.cpp`) maps public mod paths to real internal paths, allowing engine refactoring without breaking mods.
3. **Lua API**: A global `myengine` table in Lua providing access to engine components.

## Key Files
- `src/myengine/registry.h/cpp` — Registry backend for storing and checking engine paths.
- `src/myengine/aliases.h/cpp` — Alias translation logic and file loading.
- `src/myengine/scanner.py` — Build-time Python script that generates the registry population code.
- `src/script/lua_api/l_myengine.h/cpp` — Lua bindings for the `myengine` API.
- `myengine/alias_map.txt` — Human-maintained alias definitions.
- `src/myengine/CMakeLists.txt` — Build configuration for the scanner and sources.

## How The Pieces Connect
1. **Build Time**: `scanner.py` runs, reading `src/*.h`. It identifies classes/methods and generates `generated_registry.cpp`.
2. **Initialization**: `scripting_server.cpp` calls `Registry::init()` (which runs the generated code) and `AliasLayer::load_aliases()`.
3. **Lua Call**: `myengine.get("mod.path")` calls into C++.
4. **Resolution**: `AliasLayer::resolve("mod.path")` checks `alias_map.txt`. If it finds a mapping to `internal.path`, it returns that; otherwise, it returns the original.
5. **Validation**: `AliasLayer` warns if the target internal path is missing from the `Registry`.
6. **Execution**: The registry is used to access the real C++ data (simulated for now).

## Gotchas
- **Source Paths**: The scanner must use absolute paths or be aware of the build directory structure.
- **Header Guards**: All new C++ files must have proper `#pragma once` or guards.
- **Linker Issues**: Generated files must be correctly added to the CMake target to avoid "undeclared identifier" or "multiple definition" errors.
- **Path Portability**: Use `porting::path_share` for loading the alias map.

## Update (2026-03-31)
- Added build-time scanner integration.
- Fixed CI build errors by adding `find_package(Python3)` and ensuring correct header inclusions in `scripting_server.cpp`.
- Integrated unit tests into the Luanti test framework.
