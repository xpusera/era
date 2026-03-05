-- Luanti
-- SPDX-License-Identifier: LGPL-2.1-or-later

xp_import = xp_import or {}

local function tolower(s)
	return (s or ""):lower()
end

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function has_ext(path, ext)
	path = tolower(path)
	ext = tolower(ext)
	return path:sub(-#ext) == ext
end

local function sanitize_id(name, fallback)
	name = tolower(trim(name))
	name = name:gsub("[^a-z0-9_]", "_")
	name = name:gsub("_+", "_")
	name = name:gsub("^_+", ""):gsub("_+$", "")
	if name == "" then
		return fallback or "package"
	end
	return name
end

local function safe_dir_list(path, want_dirs)
	local ok, res = pcall(core.get_dir_list, path, want_dirs)
	if not ok or type(res) ~= "table" then
		return {}
	end
	local out = {}
	for _, v in ipairs(res) do
		v = tostring(v)
		if v ~= "." and v ~= ".." then
			out[#out + 1] = v
		end
	end
	table.sort(out)
	return out
end

local function path_join(a, b)
	return a .. DIR_DELIM .. b
end

local function unique_target(base_dir, name)
	local candidate = path_join(base_dir, name)
	if not core.path_exists(candidate) then
		return candidate
	end
	for i = 2, 200 do
		local c = path_join(base_dir, name .. "_" .. i)
		if not core.path_exists(c) then
			return c
		end
	end
	return path_join(base_dir, name .. "_" .. tostring(core.get_us_time()))
end

function xp_import.get_import_dir()
	local dir = core.get_user_path() .. DIR_DELIM .. "imports"
	core.mkdir(dir)
	return dir
end

function xp_import.get_pending_file()
	return xp_import.get_import_dir() .. DIR_DELIM .. ".pending_xp_imports.txt"
end

	function xp_import.get_pending()
		local pending_path = xp_import.get_pending_file()
		local f = io.open(pending_path, "r")
		if not f then
			return {}
		end
		local out = {}
		local seen = {}
		for line in f:lines() do
			line = trim(line)
			if line ~= "" and not seen[line] and core.path_exists(line) and has_ext(line, ".xp") then
				seen[line] = true
				out[#out + 1] = line
			end
		end
		f:close()
		table.sort(out)
		return out
	end

	function xp_import.remove_pending(paths)
		if type(paths) ~= "table" or #paths == 0 then
			return
		end
		local remove = {}
		for _, p in ipairs(paths) do
			if type(p) == "string" and p ~= "" then
				remove[p] = true
			end
		end
		if not next(remove) then
			return
		end

		local pending_path = xp_import.get_pending_file()
		local f = io.open(pending_path, "r")
		if not f then
			return
		end
		local kept = {}
		for line in f:lines() do
			line = trim(line)
			if line ~= "" and not remove[line] then
				kept[#kept + 1] = line
			end
		end
		f:close()

		if #kept == 0 then
			os.remove(pending_path)
			return
		end

		local wf = io.open(pending_path, "w")
		if not wf then
			return
		end
		for _, line in ipairs(kept) do
			wf:write(line)
			wf:write("\n")
		end
		wf:close()
	end

function xp_import.list_xp_files()
	local dir = xp_import.get_import_dir()
	local files = safe_dir_list(dir, false)
	local out = {}
	for _, f in ipairs(files) do
		if has_ext(f, ".xp") then
			out[#out + 1] = path_join(dir, f)
		end
	end
	table.sort(out)
	return out
end

local function detect_xp_root(extracted_dir)
	local function has_any(root)
		local candidates = {
			"mods",
			"games",
			"textures",
			"texture",
			"texture_packs",
		}
		for _, name in ipairs(candidates) do
			local p = path_join(root, name)
			if core.path_exists(p) and #safe_dir_list(p, true) > 0 then
				return true
			end
		end
		return false
	end

	if has_any(extracted_dir) then
		return extracted_dir
	end

	local subdirs = safe_dir_list(extracted_dir, true)
	if #subdirs == 1 then
		local nested = path_join(extracted_dir, subdirs[1])
		if has_any(nested) then
			return nested
		end
	end

	return nil
end

local function install_tree(expected_type, base_dir, dirs, dest_dir)
	local installed = {}
	local errors = {}
	for _, dirname in ipairs(dirs) do
		local src = path_join(base_dir, dirname)
		local base = expected_type == "txp" and { type = "txp", path = src } or pkgmgr.get_base_folder(src)
		if expected_type ~= "txp" and (not base or base.type == "invalid") then
			errors[#errors + 1] = fgettext("Invalid $1 folder: $2", expected_type, dirname)
		else
			local id = sanitize_id(dirname, expected_type)
			local target = unique_target(dest_dir, id)
			local ok_path, err = pkgmgr.install_dir(expected_type, src, id, target)
			if not ok_path then
				errors[#errors + 1] = err or fgettext("Failed to install $1", dirname)
			else
				installed[#installed + 1] = { name = dirname, id = id, path = ok_path }
			end
		end
	end
	return installed, errors
end

function xp_import.install_xp_file(xp_path)
	if type(xp_path) ~= "string" or xp_path == "" then
		return nil, fgettext("Invalid .xp path")
	end
	if not core.path_exists(xp_path) or not has_ext(xp_path, ".xp") then
		return nil, fgettext("Not a .xp file: $1", xp_path)
	end

	local tempdir = core.get_temp_path()
	if tempdir == "" then
		return nil, fgettext("Unable to create temporary folder")
	end
	local ok = core.extract_zip(xp_path, tempdir)
	if not ok then
		core.delete_dir(tempdir)
		return nil, fgettext("Failed to extract .xp archive (unsupported or broken archive)")
	end

	local root = detect_xp_root(tempdir)
	if not root then
		core.delete_dir(tempdir)
		return nil, fgettext(".xp archive must contain at least one of: mods/, games/, textures/")
	end

	local result = {
		mods = {},
		games = {},
		textures = {},
		errors = {},
	}

	local mods_dir = path_join(root, "mods")
	if core.path_exists(mods_dir) then
		local mod_dirs = safe_dir_list(mods_dir, true)
		local installed, errors = install_tree("mod", mods_dir, mod_dirs, core.get_modpath())
		result.mods = installed
		for _, e in ipairs(errors) do
			result.errors[#result.errors + 1] = e
		end
	end

	local games_dir = path_join(root, "games")
	if core.path_exists(games_dir) then
		local game_dirs = safe_dir_list(games_dir, true)
		local installed, errors = install_tree("game", games_dir, game_dirs, core.get_gamepath())
		result.games = installed
		for _, e in ipairs(errors) do
			result.errors[#result.errors + 1] = e
		end
	end

	local tex_dir = nil
	for _, name in ipairs({"textures", "texture", "texture_packs"}) do
		local p = path_join(root, name)
		if core.path_exists(p) then
			tex_dir = p
			break
		end
	end
	if tex_dir then
		local txp_dirs = safe_dir_list(tex_dir, true)
		local installed, errors = install_tree("txp", tex_dir, txp_dirs, core.get_texturepath())
		result.textures = installed
		for _, e in ipairs(errors) do
			result.errors[#result.errors + 1] = e
		end
	end

	core.delete_dir(tempdir)

	local any = (#result.mods + #result.games + #result.textures) > 0
	if not any then
		return nil, fgettext("No installable content found in .xp")
	end

	if #result.mods > 0 then
		pkgmgr.reload_by_type("mod")
	end
	if #result.games > 0 then
		pkgmgr.reload_by_type("game")
	end
	if #result.textures > 0 then
		pkgmgr.reload_by_type("txp")
	end

	return result, nil
end
