-- vim-fugitive needs no setup; :Git / :G are available once loaded.
vim.keymap.set("n", "<leader>gg", "<cmd>Git<CR>", { desc = "[G]it status (fugitive)" })
