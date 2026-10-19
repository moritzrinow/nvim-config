-- .NET via easy-dotnet.nvim: Roslyn LSP (client "easy_dotnet"), debugger,
-- test runner, NuGet / project-file tooling, `///` doc comments.
--
-- Machine requirements:
--   dotnet tool install -g EasyDotnet      (easy-dotnet-server; :Dotnet _server update)
--   roslyn-language-server                 (installed automatically on first use;
--                                           updates via `dotnet-easydotnet roslyn update`)
-- Roslyn settings (inlay hints, code lens, analysis scope): lsp/easy_dotnet.lua.
-- Health check: :checkhealth easy-dotnet

-- Open files created by easy-dotnet's server (create item, <leader>nn) the
-- same way :CsNew does: only after Roslyn has added them to their project.
-- Otherwise Roslyn's Windows new-file bug (see lua/config/csnew.lua) leaves
-- them as "Miscellaneous Files" without solution types until a restart.
-- The server opens files through this RPC handler module; replacing it in
-- package.loaded must happen before easy-dotnet loads its RPC client.
do
	local mod = "easy-dotnet.rpc.handlers.open_buffer"
	local original = require(mod)
	local NEW_FILE_SECONDS = 30

	--- A .cs file that was just created and isn't open in any buffer yet.
	local function is_new_cs_file(path)
		if not path:match("%.cs$") or vim.fn.bufloaded(path) == 1 then
			return false
		end
		local stat = vim.uv.fs_stat(path)
		if not stat then
			return false
		end
		local created = stat.birthtime and stat.birthtime.sec > 0 and stat.birthtime.sec or stat.mtime.sec
		return os.time() - created <= NEW_FILE_SECONDS
	end

	package.loaded[mod] = function(params, response, throw, validate)
		local path = type(params) == "table" and type(params.path) == "string" and vim.fn.expand(params.path)
		if not path or not is_new_cs_file(path) or not vim.lsp.get_clients({ name = "easy_dotnet" })[1] then
			return original(params, response, throw, validate)
		end
		-- Answer right away; the wait for Roslyn can take a few seconds.
		response(true)
		require("config.csnew").open_in_project(path)
	end
end

local dotnet = require("easy-dotnet")

dotnet.setup({
	picker = "snacks",

	lsp = {
		enabled = true,
	},

	-- Empty .cs files (e.g. created in Oil) are filled with namespace + type,
	-- and easy-dotnet's "create item" uses the same style. :CsNew writes
	-- file-scoped namespaces too.
	auto_bootstrap_namespace = {
		type = "file_scoped",
		enabled = true,
	},

	test_runner = {
		mappings = {
			-- In test files (buffer-local). Defaults (<leader>r/t/d/p) collide
			-- with the <leader>t, <leader>d and <leader>p groups.
			run_test_from_buffer = { lhs = "<leader>rt", desc = "Run test under cursor" },
			run_all_tests_from_buffer = { lhs = "<leader>rf", desc = "Run all tests in file" },
			peek_stack_trace_from_buffer = { lhs = "<leader>rp", desc = "Peek test stack trace" },
			debug_test_from_buffer = { lhs = "<leader>dt", desc = "Debug test under cursor" },
			-- The test runner window keeps easy-dotnet's defaults
			-- (<leader>r/R/d/p/g/e, o, E, W, ]f/[f, q, ...).
		},
	},

	-- Shown after :Dotnet outdated (<leader>no) in a project file; defaults
	-- (<leader>pu/<leader>pa) collide with the plugin-update key.
	outdated = {
		mappings = {
			upgrade = { lhs = "<leader>nu", desc = "Upgrade package under cursor" },
			upgrade_all = { lhs = "<leader>nU", desc = "Upgrade all outdated packages" },
		},
	},

	-- Its <leader>ar (add project reference) collides with harpoon's
	-- <leader>a; mapped as <leader>nR below instead.
	csproj_mappings = false,
	fsproj_mappings = false,
})

-- :CsNew {class|interface|enum|record|struct} Name — kept next to easy-dotnet's
-- create item (<leader>nn) because it works around Roslyn ignoring new files
-- on Windows (see lua/config/csnew.lua).
local csnew = require("config.csnew")

-- Keymaps ---------------------------------------------------------------------
local map = vim.keymap.set

-- <leader>n: .NET project / NuGet
map("n", "<leader>na", "<cmd>Dotnet add package<CR>", { desc = "NuGet: [A]dd package" })
map("n", "<leader>nr", "<cmd>Dotnet remove package<CR>", { desc = "NuGet: [R]emove package" })
map("n", "<leader>no", "<cmd>Dotnet outdated<CR>", { desc = "NuGet: show [O]utdated (in project file)" })
map("n", "<leader>nO", function()
	-- easy-dotnet has no command to hide them again; its hints live in the
	-- "easy-dotnet" extmark namespace (only used by outdated in project files).
	vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("easy-dotnet"), 0, -1)
end, { desc = "NuGet: hide [O]utdated hints" })
map("n", "<leader>nb", "<cmd>Dotnet build quickfix<CR>", { desc = ".NET: [B]uild (errors to quickfix)" })
map("n", "<leader>ns", "<cmd>Dotnet secrets<CR>", { desc = ".NET: user [S]ecrets" })
map("n", "<leader>nn", function()
	dotnet.create_item(csnew.target_dir())
end, { desc = ".NET: [N]ew item (class/interface/...)" })

-- Add project reference, in project files only
vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("user.dotnet_project_files", { clear = true }),
	pattern = { "*.csproj", "*.fsproj" },
	callback = function(ev)
		map("n", "<leader>nR", function()
			require("easy-dotnet.csproj-mappings").add_project_reference(ev.file)
		end, { buf = ev.buf, desc = ".NET: add project [R]eference" })
	end,
})

-- <leader>r: tests (run/peek keys in test files are set up by easy-dotnet above)
map("n", "<leader>rr", "<cmd>Dotnet testrunner<CR>", { desc = "Toggle test [R]unner" })
