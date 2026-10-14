-- Colorscheme, icons, which-key, LSP progress

vim.cmd.colorscheme("rose-pine")

require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons() -- plugins that only know nvim-web-devicons get mini.icons

require("fidget").setup({})

local wk = require("which-key")
wk.setup({})
wk.add({
	{ "<leader>s", group = "[S]earch" },
	{ "<leader>x", group = "Trouble / diagnostics" },
	{ "<leader>c", group = "[C]ode" },
	{ "<leader>t", group = "[T]oggle" },
	{ "<leader>p", group = "[P]ack" },
	{ "<leader>h", group = "[H]arpoon" },
})
vim.keymap.set("n", "<leader>?", function()
	wk.show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })
