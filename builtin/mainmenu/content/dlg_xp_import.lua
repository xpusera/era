-- Luanti
-- SPDX-License-Identifier: LGPL-2.1-or-later

local function basename(path)
	if type(path) ~= "string" then
		return ""
	end
	local p = path:gsub("\\", "/")
	return p:match(".*/(.*)$") or p
end

local function fmt_result(res)
	local parts = {}
	if res.mods and #res.mods > 0 then
		parts[#parts + 1] = fgettext("Mods: $1", tostring(#res.mods))
	end
	if res.games and #res.games > 0 then
		parts[#parts + 1] = fgettext("Games: $1", tostring(#res.games))
	end
	if res.textures and #res.textures > 0 then
		parts[#parts + 1] = fgettext("Textures: $1", tostring(#res.textures))
	end
	local msg = table.concat(parts, ", ")
	if msg == "" then
		msg = fgettext("Installed")
	end
	if res.errors and #res.errors > 0 then
		msg = msg .. "  —  " .. fgettext("$1 warnings", tostring(#res.errors))
	end
	return msg
end

local function get_formspec(data)
	local TOUCH_GUI = core.settings:get_bool("touch_gui")
	local w = TOUCH_GUI and 14 or 10
	local h = 9.05

	local import_dir = xp_import.get_import_dir()
	local files = xp_import.list_xp_files()
	data.files = files
	data.selected = math.min(data.selected or 1, math.max(#files, 1))

	local pending = data.pending or {}
	local has_pending = #pending > 0

	local list = {}
	for _, p in ipairs(files) do
		list[#list + 1] = core.formspec_escape(basename(p))
	end
	local list_str = table.concat(list, ",")

	local msg = data.message or ""
	if msg == "" and has_pending then
		msg = fgettext("$1 pending .xp import(s) detected", tostring(#pending))
	end

	local formspec = {
		"formspec_version[3]",
		"size[", w, ",", h, "]",
		TOUCH_GUI and "padding[0.01,0.01]" or "position[0.5,0.55]",
		"box[0,0;", w, ",0.8;#3333]",
		"style[title;border=false]",
		"button[0,0;", w, ",0.8;title;", fgettext("Import .xp Packages"), "]",

		"textarea[0.4,1.0;", (w - 0.8), ",1.2;;;",
		core.formspec_escape(fgettext("Open/share a .xp to Minetek, or put .xp files into:\n$1", import_dir)),
		"]",

		"tablecolumns[text]",
		"table[0.4,2.2;", (w - 0.8), ",4.2;xp_files;",
		list_str, ";", tostring(data.selected), "]",

		"box[0,6.55;", w, ",1.05;#00000033]",
		"textarea[0.4,6.6;", (w - 0.8), ",0.95;;;", core.formspec_escape(msg), "]",

		"container[0.4,7.7]",
		"button[0,0;2.2,0.8;install_selected;", fgettext("Install"), "]",
		"button[2.35,0;2.2,0.8;install_all;", fgettext("Install all"), "]",
		has_pending and ("button[4.7,0;2.2,0.8;install_pending;" .. fgettext("Install pending") .. "]") or "",
		"button[", (w - 0.8 - 2.2), ",0;2.2,0.8;close;", fgettext("Close"), "]",
		"container_end[]",
	}

	return table.concat(formspec)
end

local function handle_submit(this, fields)
	local data = this.data

	if fields.close then
		this:delete()
		return true
	end

	if fields.xp_files then
		local event = core.explode_table_event(fields.xp_files)
		if event and event.row and event.row > 0 then
			data.selected = event.row
		end
		return true
	end

	local function install_one(path)
		local res, err = xp_import.install_xp_file(path)
		if not res then
			data.message = err or fgettext("Install failed")
			return false
		end
		data.message = fgettext("$1: $2", basename(path), fmt_result(res))
		return true
	end

	if fields.install_selected then
		local files = data.files or {}
		local path = files[data.selected or 1]
		if not path then
			data.message = fgettext("No .xp file selected")
			return true
		end
		if install_one(path) then
			xp_import.remove_pending({ path })
			data.pending = xp_import.get_pending()
		end
		return true
	end

	if fields.install_all then
		local files = data.files or {}
		if #files == 0 then
			data.message = fgettext("No .xp files found")
			return true
		end
		local ok = 0
		local installed_paths = {}
		for _, path in ipairs(files) do
			if install_one(path) then
				ok = ok + 1
				installed_paths[#installed_paths + 1] = path
			end
		end
		if #installed_paths > 0 then
			xp_import.remove_pending(installed_paths)
			data.pending = xp_import.get_pending()
		end
		data.message = fgettext("Installed $1 package(s)", tostring(ok))
		return true
	end

	if fields.install_pending then
		local pending = xp_import.get_pending()
		data.pending = pending
		if #pending == 0 then
			data.message = fgettext("No pending imports")
			return true
		end
		local ok = 0
		local installed_paths = {}
		for _, path in ipairs(pending) do
			if install_one(path) then
				ok = ok + 1
				installed_paths[#installed_paths + 1] = path
			end
		end
		if #installed_paths > 0 then
			xp_import.remove_pending(installed_paths)
		end
		data.pending = xp_import.get_pending()
		data.message = fgettext("Installed $1 pending package(s)", tostring(ok))
		return true
	end

	return false
end

function create_xp_import_dialog(pending)
	local dlg = dialog_create("xp_import_dialog", get_formspec, handle_submit, nil)
	dlg.data.selected = 1
	dlg.data.message = ""
	dlg.data.pending = pending or xp_import.get_pending()
	return dlg
end
