local map = vim.keymap.set

-- Clear search highlight with <Esc> in normal mode
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostics
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Spell check toggle
map("n", "<leader>sc", function()
	vim.o.spell = not vim.o.spell
end, { desc = "Toggle [S]pell [C]heck" })

-- Discourage arrow keys in normal mode
map("n", "<left>", "<cmd>echo 'Use h to move!!'<CR>")
map("n", "<right>", "<cmd>echo 'Use l to move!!'<CR>")
map("n", "<up>", "<cmd>echo 'Use k to move!!'<CR>")
map("n", "<down>", "<cmd>echo 'Use j to move!!'<CR>")

-- Plugin management shortcuts
map("n", "<leader>pu", function()
	vim.pack.update()
end, { desc = "[P]ack [U]pdate plugins" })
map("n", "<leader>pl", function()
	vim.pack.update(nil, { offline = true })
end, { desc = "[P]ack [L]ist installed plugins" })
