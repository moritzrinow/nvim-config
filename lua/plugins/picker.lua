-- snacks.nvim: picker (telescope replacement), vim.ui.select/input, zen mode

require("snacks").setup({
	picker = {
		enabled = true,
		ui_select = true, -- replaces vim.ui.select (code actions, etc.)
	},
	input = { enabled = true },
	zen = { enabled = true },
	-- Everything else in snacks stays off unless enabled explicitly.
})

local map = vim.keymap.set
local picker = Snacks.picker

-- Same mnemonics as the old telescope setup
map("n", "<leader>sh", function() picker.help() end, { desc = "[S]earch [H]elp" })
map("n", "<leader>sk", function() picker.keymaps() end, { desc = "[S]earch [K]eymaps" })
map("n", "<leader>sf", function() picker.files() end, { desc = "[S]earch [F]iles" })
map("n", "<leader>ss", function() picker.pickers() end, { desc = "[S]earch [S]elect picker" })
map({ "n", "x" }, "<leader>sw", function() picker.grep_word() end, { desc = "[S]earch current [W]ord" })
map("n", "<leader>sg", function() picker.grep() end, { desc = "[S]earch by [G]rep" })
map("n", "<leader>sd", function() picker.diagnostics() end, { desc = "[S]earch [D]iagnostics" })
map("n", "<leader>sr", function() picker.resume() end, { desc = "[S]earch [R]esume" })
map("n", "<leader>s.", function() picker.recent() end, { desc = "[S]earch Recent Files" })
map("n", "<leader><leader>", function() picker.buffers() end, { desc = "[ ] Find existing buffers" })
map("n", "<leader>/", function() picker.lines() end, { desc = "[/] Fuzzily search in current buffer" })
map("n", "<leader>s/", function() picker.grep_buffers() end, { desc = "[S]earch [/] in Open Files" })
map("n", "<leader>sn", function()
	picker.files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim files" })

-- Git pickers (fugitive covers the rest)
map("n", "<leader>gs", function() picker.git_status() end, { desc = "[G]it [S]tatus" })
map("n", "<leader>gb", function() picker.git_branches() end, { desc = "[G]it [B]ranches" })
