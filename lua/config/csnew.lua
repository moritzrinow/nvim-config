-- :CsNew {class|interface|enum|record|struct} Name
--
-- Creates Name.cs next to the current file (or inside the directory shown in
-- an Oil buffer) with a file-scoped namespace derived from the nearest
-- .csproj: <RootNamespace> (or the project file name) plus the folder path
-- relative to the project directory, like Visual Studio's "Add → Class".

local M = {}

local kinds = { "class", "interface", "enum", "record", "struct" }

-- Roslyn request listing the projects a document belongs to.
local PROJECT_CONTEXTS = "textDocument/_vs_getProjectContexts"
local POLL_MS = 250
local WAIT_MS = 15000

--- Directory new files go to: Oil's current directory, the current file's
--- directory, or the working directory.
function M.target_dir()
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
	local dir = M.target_dir()
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

	-- A buffer left over for this path (e.g. a deleted earlier attempt) would
	-- be reused by :edit without a new didOpen, keeping Roslyn's stale
	-- miscellaneous-files copy. Wipe it so the file is opened fresh.
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) == path then
			if vim.bo[buf].modified then
				return vim.notify("CsNew: a modified buffer for " .. path .. " is still open", vim.log.levels.ERROR)
			end
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end

	vim.fn.mkdir(dir, "p")
	vim.fn.writefile(lines, path)

	M.open_in_project(path, function()
		-- Cursor inside the braces, ready to type.
		vim.api.nvim_win_set_cursor(0, { #lines - 1, 0 })
	end)
end

--- Open a just-created .cs file only once Roslyn has added it to its project.
---
--- Opened earlier, it becomes a miscellaneous file, and after the reload the
--- project ends up without its project references and implicit usings (no
--- solution types or unimported-namespace completion), and stays so.
---
--- So: make Roslyn reload the project, then ask which project owns the
--- still-closed file until it names the real one.
---
--- A "created" event for the .cs file alone doesn't trigger the reload on
--- Windows: Roslyn lower-cases the drive letter of event paths (c:\...) but
--- keeps project directories upper-case (C:\...), and its glob check
--- (Microsoft.Extensions.FileSystemGlobbing 10.0) compares them
--- case-sensitively, so the new file never matches the project's **/*.cs. A
--- "changed" event for the .csproj takes the same reload path without the
--- glob check. It doesn't cause a restore: Roslyn restores only when package
--- references differ from the last load or project.assets.json is missing.
--- Both events need Roslyn to accept client file events, which easy-dotnet
--- enables by default on Windows.
---
--- For unknown files Roslyn answers with a throwaway "Miscellaneous Files"
--- context, so only a context of the nearest .csproj counts ("Proj" or
--- "Proj (net10.0)").
---
--- Used by :CsNew and by easy-dotnet's create item (see plugins/csharp.lua).
---@param path string absolute path of the new file (already written)
---@param after_open? fun() called once the buffer is open
function M.open_in_project(path, after_open)
	path = vim.fs.normalize(path)
	local function open()
		vim.cmd.edit(vim.fn.fnameescape(path))
		if after_open then
			after_open()
		end
	end

	local client = vim.lsp.get_clients({ name = "easy_dotnet" })[1] -- easy-dotnet's Roslyn client
	if not client then
		return open()
	end

	local uri = vim.uri_from_fname(path)
	local csproj = find_csproj(vim.fs.dirname(path))
	local proj = csproj and vim.fn.fnamemodify(csproj, ":t:r")
	local changes = { { uri = uri, type = 1 } } -- 1 = Created
	if csproj then
		changes[#changes + 1] = { uri = vim.uri_from_fname(csproj), type = 2 } -- 2 = Changed
	end
	client:notify("workspace/didChangeWatchedFiles", { changes = changes })

	local function in_project(ctx)
		if ctx._vs_is_miscellaneous or ctx._vs_label == "Miscellaneous Files" then
			return false
		end
		local label = ctx._vs_label or ""
		return not proj or label == proj or label:find(proj .. " (", 1, true) == 1
	end

	local name = vim.fs.basename(path)
	vim.notify(("Waiting for Roslyn to add %s to %s…"):format(name, proj or "its project"), vim.log.levels.INFO)
	local deadline = vim.uv.now() + WAIT_MS
	local function poll()
		client:request(PROJECT_CONTEXTS, { _vs_textDocument = { uri = uri } }, function(_, result)
			local contexts = result and result._vs_projectContexts or {}
			if vim.iter(contexts):any(in_project) then
				return open()
			end
			if vim.uv.now() >= deadline then
				vim.notify(("Roslyn hasn't added %s to a project yet; opening anyway"):format(name), vim.log.levels.WARN)
				return open()
			end
			vim.defer_fn(poll, POLL_MS)
		end)
	end
	poll()
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
