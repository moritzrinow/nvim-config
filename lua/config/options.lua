local o = vim.o

o.number = true
o.relativenumber = true
o.cursorline = true
o.signcolumn = "yes"
o.scrolloff = 10
o.breakindent = true
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.updatetime = 250
o.timeoutlen = 300
o.splitright = true
o.splitbelow = true
o.inccommand = "split"
o.confirm = true
o.winborder = "rounded"

o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

o.spell = true
-- The "programming" dictionary (vim-dirtytalk word lists, see
-- lua/config/spell.lua) is appended once its spell file has been built.
vim.opt.spelllang = { "en" }

vim.opt.guicursor = "n-v-c:block,i-ci:block,r-cr:block,sm:block"

-- Sync with the system clipboard after startup so a slow clipboard provider
-- doesn't delay the first paint.
vim.schedule(function()
	o.clipboard = "unnamedplus"
end)
