-- .NET debugging commands on top of nvim-dap + nvim-dap-cs (netcoredbg).
--
--   :DotnetDebug           build the startup project and launch it under the debugger.
--                          Asks once per working directory which project / launch
--                          profile to use (when there is more than one), then remembers.
--   :DotnetDebug!          forget the remembered project/profile and ask again.
--   :DotnetDebugTest       debug the test method (or class) under the cursor.
--   :DotnetDebugTest!      debug every test in the current test project.
--   :DotnetDebugTest {filter}   debug tests matching a `dotnet test --filter` expression.
--   :DotnetAttach          attach to a running process (picker).
--
-- Build errors go to the quickfix list. Launch settings (env vars, applicationUrl,
-- commandLineArgs) come from Properties/launchSettings.json, like `dotnet run`.

local M = {}

-- Remembered choices, keyed by working directory: { project, profile, tfm }
local state = {}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "dotnet debug" })
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

local function cwd()
	return vim.fs.normalize(vim.uv.cwd())
end

local function buf_dir()
	local name = vim.api.nvim_buf_get_name(0)
	if name ~= "" and vim.bo.buftype == "" then
		return vim.fs.dirname(vim.fs.normalize(name))
	end
	return cwd()
end

--- Nearest *.csproj at or above `dir`.
local function nearest_csproj(dir)
	return vim.fs.find(function(name)
		return name:match("%.csproj$") ~= nil
	end, { path = dir, upward = true, type = "file", limit = 1 })[1]
end

--- All *.csproj below the working directory (skipping bin/obj/node_modules/.git).
local function all_csprojs()
	local skip = { bin = true, obj = true, node_modules = true, [".git"] = true, [".vs"] = true }
	local found = {}
	for name, type in
		vim.fs.dir(cwd(), {
			depth = 6,
			skip = function(dir_name)
				return not skip[dir_name]
			end,
		})
	do
		if type == "file" and name:match("%.csproj$") then
			table.insert(found, vim.fs.normalize(vim.fs.joinpath(cwd(), name)))
		end
	end
	table.sort(found)
	return found
end

local function is_test_project(content)
	return content:find("Microsoft.NET.Test.Sdk", 1, true) ~= nil
		or content:match("<IsTestProject>%s*true") ~= nil
		or content:match("<OutputType>%s*Exe%s*</OutputType>") and content:find("TestingPlatform", 1, true) ~= nil
end

local function is_runnable(content)
	if is_test_project(content) then
		return false
	end
	return content:match("<OutputType>%s*W?i?n?Exe%s*</OutputType>") ~= nil
		or content:match('Sdk="Microsoft%.NET%.Sdk%.Web"') ~= nil
		or content:match('Sdk="Microsoft%.NET%.Sdk%.Worker"') ~= nil
		or content:match('Sdk="Microsoft%.NET%.Sdk%.Razor"') ~= nil
end

local function project_name(path)
	return vim.fn.fnamemodify(path, ":t:r")
end

--- Pick one of `items` (calls cb immediately when there is only one).
local function pick(items, prompt, format, cb)
	if #items == 0 then
		return cb(nil)
	elseif #items == 1 then
		return cb(items[1])
	end
	vim.ui.select(items, { prompt = prompt, format_item = format }, function(choice)
		if choice then
			cb(choice)
		end
	end)
end

--- Projects that match `filter`, with the current buffer's project first.
local function candidate_projects(filter)
	local current = nearest_csproj(buf_dir())
	current = current and vim.fs.normalize(current)
	local list = {}
	for _, p in ipairs(all_csprojs()) do
		local content = read_file(p) or ""
		if filter(content) then
			table.insert(list, p)
		end
	end
	if current and not vim.tbl_contains(list, current) then
		local content = read_file(current) or ""
		if filter(content) then
			table.insert(list, 1, current)
		end
	elseif current then
		table.sort(list, function(a, b)
			if a == current then
				return true
			elseif b == current then
				return false
			end
			return a < b
		end)
	end
	return list
end

-- Build output -> quickfix ---------------------------------------------------

local function build_output_to_qf(output, title)
	local items, seen = {}, {}
	for line in output:gmatch("[^\r\n]+") do
		local file, lnum, col, kind, code, msg =
			line:match("^%s*(.-)%((%d+),(%d+)[%d,]*%)%s*:%s*(%a+)%s+(%w+)%s*:%s*(.-)%s*%[[^%]]*%]%s*$")
		if file and (kind == "error" or kind == "warning") then
			local key = table.concat({ file, lnum, col, code }, ":")
			if not seen[key] then
				seen[key] = true
				table.insert(items, {
					filename = file,
					lnum = tonumber(lnum),
					col = tonumber(col),
					type = kind == "error" and "E" or "W",
					text = code .. ": " .. msg,
				})
			end
		elseif line:match(":%s*error%s+%w+:") and not seen[line] then
			-- Errors without a source position (MSBuild, NuGet, SDK)
			seen[line] = true
			table.insert(items, { text = vim.trim(line), type = "E" })
		end
	end
	-- Errors first
	table.sort(items, function(a, b)
		return (a.type == "E" and 0 or 1) < (b.type == "E" and 0 or 1)
	end)
	vim.fn.setqflist({}, " ", { title = title, items = items })
	return #items
end

local function report_build_failure(output, what)
	local n = build_output_to_qf(output, what .. " failed")
	if n > 0 then
		notify(what .. " failed — see quickfix list", vim.log.levels.ERROR)
		vim.cmd("botright copen")
	else
		local lines = vim.split(vim.trim(output), "\n")
		notify(
			what .. " failed:\n" .. table.concat(vim.list_slice(lines, math.max(1, #lines - 15)), "\n"),
			vim.log.levels.ERROR
		)
	end
end

-- MSBuild evaluation -----------------------------------------------------------

--- Evaluate TargetPath / TargetFrameworks for `project` (optionally for one TFM).
local function evaluate(project, tfm, cb)
	local cmd = {
		"dotnet",
		"msbuild",
		project,
		"-nologo",
		"-p:Configuration=Debug",
		"-getProperty:TargetPath",
		"-getProperty:TargetFrameworks",
	}
	if tfm then
		table.insert(cmd, "-p:TargetFramework=" .. tfm)
	end
	vim.system(cmd, { text = true }, function(res)
		vim.schedule(function()
			local ok, decoded = pcall(vim.json.decode, res.stdout or "")
			if res.code ~= 0 or not ok or type(decoded) ~= "table" then
				return report_build_failure((res.stdout or "") .. (res.stderr or ""), "Project evaluation")
			end
			cb(decoded.Properties or {})
		end)
	end)
end

--- Resolve the output .dll, asking for a target framework if the project multi-targets.
local function resolve_target(project, remembered_tfm, cb)
	evaluate(project, remembered_tfm, function(props)
		if props.TargetPath and props.TargetPath ~= "" then
			return cb(props.TargetPath, remembered_tfm)
		end
		local tfms = vim.split(props.TargetFrameworks or "", ";", { trimempty = true })
		if #tfms == 0 then
			return notify("Could not determine the output path of " .. project, vim.log.levels.ERROR)
		end
		pick(tfms, "Target framework", nil, function(tfm)
			evaluate(project, tfm, function(p2)
				cb(p2.TargetPath, tfm)
			end)
		end)
	end)
end

local function build(project, tfm, cb)
	local cmd = { "dotnet", "build", project, "-c", "Debug", "-nologo", "-tl:off", "-clp:NoSummary" }
	if tfm then
		vim.list_extend(cmd, { "-f", tfm })
	end
	notify("Building " .. project_name(project) .. " …")
	vim.system(cmd, { text = true }, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				return report_build_failure((res.stdout or "") .. (res.stderr or ""), "Build")
			end
			cb()
		end)
	end)
end

-- launchSettings.json --------------------------------------------------------

--- Split a command line into arguments, honouring double quotes.
local function split_args(s)
	local args, cur, in_quotes = {}, "", false
	for c in (s or ""):gmatch(".") do
		if c == '"' then
			in_quotes = not in_quotes
		elseif c:match("%s") and not in_quotes then
			if cur ~= "" then
				table.insert(args, cur)
				cur = ""
			end
		else
			cur = cur .. c
		end
	end
	if cur ~= "" then
		table.insert(args, cur)
	end
	return args
end

--- Launch profiles with commandName "Project" (the ones `dotnet run` can use).
local function launch_profiles(project)
	local path = vim.fs.joinpath(vim.fs.dirname(project), "Properties", "launchSettings.json")
	local content = read_file(path)
	if not content then
		return {}
	end
	local ok, json = pcall(vim.json.decode, content)
	if not ok or type(json) ~= "table" or type(json.profiles) ~= "table" then
		notify("Could not parse " .. path, vim.log.levels.WARN)
		return {}
	end
	local profiles = {}
	for name, p in pairs(json.profiles) do
		if p.commandName == "Project" then
			p.name = name
			table.insert(profiles, p)
		end
	end
	table.sort(profiles, function(a, b)
		return a.name < b.name
	end)
	return profiles
end

local function apply_profile(profile)
	local env, args = {}, {}
	if profile then
		for k, v in pairs(profile.environmentVariables or {}) do
			env[k] = tostring(v)
		end
		if profile.applicationUrl and profile.applicationUrl ~= "" and not env.ASPNETCORE_URLS then
			env.ASPNETCORE_URLS = profile.applicationUrl
		end
		args = split_args(profile.commandLineArgs)
	end
	return env, args
end

-- Commands -------------------------------------------------------------------

function M.debug(reset)
	local key = cwd()
	if reset then
		state[key] = nil
	end
	local s = state[key] or {}

	local function with_project(cb)
		if s.project and vim.uv.fs_stat(s.project) then
			return cb(s.project)
		end
		local projects = candidate_projects(is_runnable)
		if #projects == 0 then
			-- Fall back to anything that isn't a test project (OutputType may come from Directory.Build.props)
			projects = candidate_projects(function(c)
				return not is_test_project(c)
			end)
		end
		if #projects == 0 then
			return notify("No .csproj found below " .. key, vim.log.levels.ERROR)
		end
		pick(projects, "Project to debug", function(p)
			return project_name(p) .. "  (" .. vim.fn.fnamemodify(p, ":.") .. ")"
		end, cb)
	end

	with_project(function(project)
		s.project = project
		local profiles = launch_profiles(project)
		local function with_profile(cb)
			if s.profile then
				for _, p in ipairs(profiles) do
					if p.name == s.profile then
						return cb(p)
					end
				end
			end
			if #profiles == 0 then
				return cb(nil)
			end
			pick(profiles, "Launch profile", function(p)
				return p.name .. (p.applicationUrl and ("  " .. p.applicationUrl) or "")
			end, cb)
		end

		with_profile(function(profile)
			s.profile = profile and profile.name or nil
			resolve_target(project, s.tfm, function(target, tfm)
				s.tfm = tfm
				state[key] = s
				build(project, tfm, function()
					local env, args = apply_profile(profile)
					local name = project_name(project) .. (profile and (" [" .. profile.name .. "]") or "")
					notify("Debugging " .. name)
					require("dap").run({
						type = "coreclr",
						request = "launch",
						name = "Debug " .. name,
						program = target,
						cwd = vim.fs.dirname(project),
						args = args,
						env = env,
						stopAtEntry = false,
					})
				end)
			end)
		end)
	end)
end

--- Fully qualified-ish name of the test method / class under the cursor.
local function test_filter_at_cursor()
	local ok, node = pcall(vim.treesitter.get_node)
	if not ok or not node then
		return nil
	end
	local bufnr = vim.api.nvim_get_current_buf()
	local method, classes, namespace = nil, {}, nil
	while node do
		local t = node:type()
		local name_node = node:field("name")[1]
		local name = name_node and vim.treesitter.get_node_text(name_node, bufnr)
		if t == "method_declaration" and not method then
			method = name
		elseif t == "class_declaration" or t == "record_declaration" or t == "struct_declaration" then
			table.insert(classes, 1, name)
		elseif t == "namespace_declaration" then
			namespace = name
		end
		node = node:parent()
	end
	if #classes == 0 then
		return nil
	end
	if not namespace then
		-- File-scoped namespace is a sibling of the class, not an ancestor.
		local root = vim.treesitter.get_parser(bufnr):parse()[1]:root()
		for child in root:iter_children() do
			if child:type() == "file_scoped_namespace_declaration" then
				namespace = vim.treesitter.get_node_text(child:field("name")[1], bufnr)
				break
			end
		end
	end
	-- Nested classes are joined with "+" in fully qualified test names.
	local parts = { table.concat(classes, "+") }
	if namespace then
		table.insert(parts, 1, namespace)
	end
	if method then
		table.insert(parts, method)
	end
	return "FullyQualifiedName~" .. table.concat(parts, ".")
end

local test_job

function M.debug_test(filter, whole_project)
	if test_job then
		return notify("A test debug run is already in progress", vim.log.levels.WARN)
	end
	if not filter and not whole_project then
		filter = test_filter_at_cursor()
		if not filter then
			whole_project = true
		end
	end

	local current = nearest_csproj(buf_dir())
	local function with_project(cb)
		if current and is_test_project(read_file(current) or "") then
			return cb(vim.fs.normalize(current))
		end
		local projects = candidate_projects(is_test_project)
		if #projects == 0 then
			return notify("No test project found", vim.log.levels.ERROR)
		end
		pick(projects, "Test project", project_name, cb)
	end

	with_project(function(project)
		local cmd = { "dotnet", "test", project, "-nologo", "-tl:off" }
		if filter then
			vim.list_extend(cmd, { "--filter", filter })
		end
		notify("Building and starting tests" .. (filter and (" (" .. filter .. ")") or "") .. " …")

		local output, attached = {}, false
		local function on_output(_, data)
			if not data then
				return
			end
			table.insert(output, data)
			if attached then
				return
			end
			local pid = data:match("Process Id:%s*(%d+)")
			if pid then
				attached = true
				vim.schedule(function()
					require("dap").run({
						type = "coreclr",
						request = "attach",
						name = "Debug tests " .. project_name(project),
						processId = tonumber(pid),
					})
				end)
			end
		end

		test_job = vim.system(cmd, {
			text = true,
			env = {
				VSTEST_HOST_DEBUG = "1", -- VSTest: test host waits for a debugger
				TESTINGPLATFORM_WAIT_ATTACH_DEBUGGER = "1", -- Microsoft.Testing.Platform
			},
			stdout = on_output,
			stderr = on_output,
		}, function(res)
			vim.schedule(function()
				test_job = nil
				local text = table.concat(output)
				if not attached then
					return report_build_failure(text, "Test build")
				end
				local summary = {}
				for line in text:gmatch("[^\r\n]+") do
					if line:match("^%s*Passed!") or line:match("^%s*Failed!") or line:match("Total tests") then
						table.insert(summary, vim.trim(line))
					end
				end
				notify(
					#summary > 0 and table.concat(summary, "\n") or ("dotnet test exited with code " .. res.code),
					res.code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
				)
			end)
		end)
	end)
end

function M.stop_tests()
	if test_job then
		test_job:kill("sigterm")
		test_job = nil
	end
end

function M.attach()
	require("dap").run({
		type = "coreclr",
		request = "attach",
		name = "Attach to process",
		processId = require("dap.utils").pick_process,
	})
end

vim.api.nvim_create_user_command("DotnetDebug", function(opts)
	M.debug(opts.bang)
end, { bang = true, desc = "Build and debug the .NET startup project (! = choose project again)" })

vim.api.nvim_create_user_command("DotnetDebugTest", function(opts)
	local filter = opts.args ~= "" and opts.args or nil
	M.debug_test(filter, opts.bang)
end, { bang = true, nargs = "?", desc = "Debug the .NET test under the cursor (! = whole project, arg = filter)" })

vim.api.nvim_create_user_command("DotnetAttach", M.attach, { desc = "Attach the .NET debugger to a process" })

return M
