-- Neovim 0.12+ config, managed with the built-in package manager (vim.pack).
--
-- Layout:
--   lua/config/options.lua   editor options
--   lua/config/keymaps.lua   global keymaps (plugin keymaps live next to the plugin)
--   lua/config/autocmds.lua  global autocommands
--   lua/config/pack.lua      plugin list + build hooks (the only place vim.pack.add is called)
--   lua/plugins/*.lua        per-plugin setup, required explicitly below in dependency order
--
-- Plugin management cheat sheet:
--   :lua vim.pack.update()                 fetch updates, review in a tab, :write to apply / :quit to discard
--   :lua vim.pack.update(nil,{offline=true}) inspect what is installed without fetching
--   :lua vim.pack.del({ 'name' })          remove a plugin after deleting it from pack.lua
--   :checkhealth vim.pack                  sanity-check the lockfile vs. what is on disk
--   nvim-pack-lock.json                    the lockfile; commit it, never edit it by hand

vim.loader.enable()

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.pack")

-- Plugin setup, in dependency order (icons/colorscheme first, LSP after mason, etc.).
require("plugins.ui")
require("plugins.editor")
require("plugins.picker")
require("plugins.treesitter")
require("plugins.completion")
require("plugins.lsp")
require("plugins.format")
require("plugins.git")
require("plugins.dap")
require("plugins.go")
require("plugins.csharp")
require("plugins.markdown")
