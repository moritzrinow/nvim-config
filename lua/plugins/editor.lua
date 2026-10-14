-- General editing plugins: oil, harpoon, autopairs, guess-indent, trouble, zen

-- Oil: edit the filesystem like a buffer
require("oil").setup({})
vim.keymap.set("n", "\\", "<cmd>Oil<CR>", { desc = "Open Oil filesystem explorer" })

-- Harpoon 2
local harpoon = require("harpoon")
harpoon:setup()

vim.keymap.set("n", "<leader>a", function()
	harpoon:list():add()
end, { desc = "Harpoon: [A]dd file" })
vim.keymap.set("n", "<C-e>", function()
	harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Harpoon: quick menu" })
vim.keymap.set("n", "<C-S-P>", function()
	harpoon:list():prev()
end, { desc = "Harpoon: previous" })
vim.keymap.set("n", "<C-S-N>", function()
	harpoon:list():next()
end, { desc = "Harpoon: next" })
for i = 1, 4 do
	vim.keymap.set("n", "<leader>h" .. i, function()
		harpoon:list():select(i)
	end, { desc = "Harpoon: file " .. i })
end

-- vim-dirtytalk word lists → "programming" spell dictionary. Built by the
-- PackChanged hook in config/pack.lua (or :DirtytalkBuild); only added to
-- 'spelllang' once the file exists, otherwise Neovim prompts to download it.
require("config.spell").enable()

-- Autopairs
require("nvim-autopairs").setup({})

-- Detect indentation from the buffer
require("guess-indent").setup({})

-- Trouble
require("trouble").setup({})
local map = vim.keymap.set
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer Diagnostics (Trouble)" })
map("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols (Trouble)" })
map("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP Definitions / references / ... (Trouble)" })
map("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List (Trouble)" })
map("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List (Trouble)" })

-- Zen mode comes from snacks.nvim (set up in plugins/picker.lua)
map("n", "<leader>z", function()
	Snacks.zen()
end, { desc = "Toggle [Z]en mode" })
