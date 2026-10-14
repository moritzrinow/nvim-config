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
