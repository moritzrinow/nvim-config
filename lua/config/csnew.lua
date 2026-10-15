-- :CsNew {class|interface|enum|record|struct} Name
--
-- Creates Name.cs next to the current file (or inside the directory shown in
-- an Oil buffer) with a file-scoped namespace derived from the nearest
-- .csproj: <RootNamespace> (or the project file name) plus the folder path
-- relative to the project directory, like Visual Studio's "Add → Class".

local M = {}

local kinds = { "class", "interface", "enum", "record", "struct" }

--- Directory new files go to: Oil's current directory, the current file's
--- directory, or the working directory.
local function target_dir()
	if vim.bo.filetype == "oil" then
		local ok, oil = pcall(require, "oil")
		local dir = ok and oil.get_current_dir()
		if dir then
			return vim.fs.normalize(dir)
		end
	end
	local name = vim.api.nvim_buf_get_name(0)
	if name ~= "" and vim.bo.buftype == "" then
		return vim.fs.dirname(vim.fs.normalize(name))
	end
	return vim.fs.normalize(vim.uv.cwd())
end

--- Find the nearest *.csproj at or above `dir`.
local function find_csproj(dir)
	return vim.fs.find(function(name)
		return name:match("%.csproj$") ~= nil
	end, { path = dir, upward = true, type = "file", limit = 1 })[1]
end

--- Turn a folder name into a valid namespace segment.
local function segment(name)
	name = name:gsub("[^%w_]", "_")
	if name:match("^%d") then
		name = "_" .. name
	end
	return name
end

--- Namespace for files in `dir`.
local function namespace_for(dir)
	local csproj = find_csproj(dir)
	if not csproj then
		return nil
	end
	local proj_dir = vim.fs.dirname(csproj)
	local root
	local f = io.open(csproj, "r")
	if f then
		local xml = f:read("*a")
		f:close()
		root = xml:match("<RootNamespace>%s*(.-)%s*</RootNamespace>")
	end
	if not root or root == "" then
		root = vim.fn.fnamemodify(csproj, ":t:r")
	end

	local parts = { root }
	local rel = dir:sub(#proj_dir + 2) -- strip "<proj_dir>/"
	if dir ~= proj_dir and rel ~= "" then
		for part in rel:gmatch("[^/]+") do
			parts[#parts + 1] = segment(part)
		end
	end
	return table.concat(parts, ".")
end

---@param kind string
---@param name string
function M.create(kind, name)
	if not vim.tbl_contains(kinds, kind) then
		-- Allow `:CsNew Name` → class (or interface for I-prefixed names)
		if name == nil and kind:match("^[%a_][%w_/\\]*$") then
			name = kind
			kind = name:match("([^/\\]+)$"):match("^I%u") and "interface" or "class"
		else
			return vim.notify("CsNew: kind must be one of " .. table.concat(kinds, ", "), vim.log.levels.ERROR)
		end
	end
	if not name or name == "" then
		return vim.notify("CsNew: missing type name", vim.log.levels.ERROR)
	end

	name = name:gsub("%.cs$", ""):gsub("\\", "/")
	local dir = target_dir()
	local sub = name:match("^(.*)/[^/]+$")
	local type_name = name:match("([^/]+)$")
	if sub then
		dir = vim.fs.joinpath(dir, sub)
	end
	if not type_name:match("^[%a_][%w_]*$") then
		return vim.notify("CsNew: invalid type name '" .. type_name .. "'", vim.log.levels.ERROR)
	end

	local path = vim.fs.joinpath(dir, type_name .. ".cs")
	if vim.uv.fs_stat(path) then
		return vim.notify("CsNew: " .. path .. " already exists", vim.log.levels.ERROR)
	end

	local ns = namespace_for(dir)
	if not ns then
		vim.notify("CsNew: no .csproj found above " .. dir .. "; omitting namespace", vim.log.levels.WARN)
	end

	local lines = {}
	if ns then
		lines[#lines + 1] = "namespace " .. ns .. ";"
		lines[#lines + 1] = ""
	end
	lines[#lines + 1] = "public " .. kind .. " " .. type_name
	lines[#lines + 1] = "{"
	lines[#lines + 1] = "}"

	vim.fn.mkdir(dir, "p")
	vim.fn.writefile(lines, path)
	vim.cmd.edit(vim.fn.fnameescape(path))
	-- Cursor inside the braces, ready to type.
	vim.api.nvim_win_set_cursor(0, { #lines - 1, 0 })
end

vim.api.nvim_create_user_command("CsNew", function(opts)
	M.create(opts.fargs[1], opts.fargs[2])
end, {
	nargs = "+",
	desc = "Create a new C# type file (class|interface|enum|record|struct Name)",
	complete = function(arg_lead, cmdline)
		local _, nargs = cmdline:gsub("%S+", "")
		if nargs > 2 or (nargs == 2 and not cmdline:match("%s$")) then
			return {}
		end
		return vim.tbl_filter(function(k)
			return k:find(arg_lead, 1, true) == 1
		end, kinds)
	end,
})

return M
