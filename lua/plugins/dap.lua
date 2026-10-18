-- nvim-dap + dap-ui, with Go (delve) and .NET (netcoredbg) adapters

local dap = require("dap")
local dapui = require("dapui")

require("mason-nvim-dap").setup({
	automatic_installation = true,
	handlers = {},
	ensure_installed = { "delve", "netcoredbg" },
})

dapui.setup({
	icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
	controls = {
		icons = {
			pause = "⏸",
			play = "▶",
			step_into = "⏎",
			step_over = "⏭",
			step_out = "⏮",
			step_back = "b",
			run_last = "▶▶",
			terminate = "⏹",
			disconnect = "⏏",
		},
	},
})

dap.listeners.after.event_initialized["dapui_config"] = dapui.open
dap.listeners.before.event_terminated["dapui_config"] = dapui.close
dap.listeners.before.event_exited["dapui_config"] = dapui.close

-- Go
require("dap-go").setup({
	delve = {
		-- On Windows delve must be run attached or it crashes.
		detached = vim.fn.has("win32") == 0,
	},
	dap_configurations = {},
})

-- .NET
require("dap-cs").setup({
	dap_configurations = {
		{
			type = "coreclr",
			name = "Attach remote",
			mode = "remote",
			request = "attach",
		},
	},
	netcoredbg = {
		path = "netcoredbg",
	},
})

local map = vim.keymap.set
map("n", "<F5>", dap.continue, { desc = "Debug: Start/Continue" })
map("n", "<F1>", dap.step_into, { desc = "Debug: Step Into" })
map("n", "<F2>", dap.step_over, { desc = "Debug: Step Over" })
map("n", "<F3>", dap.step_out, { desc = "Debug: Step Out" })
map("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: Toggle [B]reakpoint" })
map("n", "<leader>B", function()
	dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Debug: Set conditional [B]reakpoint" })
map("n", "<F7>", dapui.toggle, { desc = "Debug: See last session result" })

-- Session commands ------------------------------------------------------------
local dotnet = require("config.dotnet_debug")

local function stop()
	dap.terminate()
	dotnet.stop_tests()
	dapui.close()
end

vim.api.nvim_create_user_command("DebugStop", stop, { desc = "Stop the debug session" })
vim.api.nvim_create_user_command("DebugRestart", dap.restart, { desc = "Restart the debug session" })
vim.api.nvim_create_user_command("DebugLast", dap.run_last, { desc = "Re-run the last debug configuration (no rebuild)" })
vim.api.nvim_create_user_command("DebugClearBreakpoints", dap.clear_breakpoints, { desc = "Remove all breakpoints" })

--- Debug the test under the cursor, for whichever language the buffer is.
local function debug_test()
	local ft = vim.bo.filetype
	if ft == "go" then
		require("dap-go").debug_test()
	elseif ft == "cs" then
		dotnet.debug_test()
	else
		vim.notify("No test debugging set up for filetype '" .. ft .. "'", vim.log.levels.WARN)
	end
end

map("n", "<leader>dn", function()
	dotnet.debug(false)
end, { desc = "[D]ebug .[N]ET project (build + launch)" })
map("n", "<leader>dN", function()
	dotnet.debug(true)
end, { desc = "[D]ebug .[N]ET project, choose project again" })
map("n", "<leader>dt", debug_test, { desc = "[D]ebug [T]est under cursor" })
map("n", "<leader>da", dotnet.attach, { desc = "[D]ebug: [A]ttach to .NET process" })
map("n", "<leader>dl", dap.run_last, { desc = "[D]ebug [L]ast configuration" })
map("n", "<leader>dr", dap.restart, { desc = "[D]ebug [R]estart" })
map("n", "<leader>dq", stop, { desc = "[D]ebug [Q]uit session" })
map("n", "<leader>dc", dap.clear_breakpoints, { desc = "[D]ebug [C]lear breakpoints" })
map("n", "<leader>de", dapui.eval, { desc = "[D]ebug [E]valuate expression under cursor" })
map("v", "<leader>de", dapui.eval, { desc = "[D]ebug [E]valuate selection" })
