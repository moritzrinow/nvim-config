-- Plugin list and build hooks for vim.pack (:h vim.pack).
--
-- vim.pack has no lazy-loading: every plugin here is on the runtimepath after
-- this file runs, and their plugin/ scripts are sourced once init.lua finishes.
-- Startup stays fast anyway thanks to vim.loader; everything is "lazy" at the
-- require() level.

local gh = function(repo)
	return "https://github.com/" .. repo
end

-- Build hooks -------------------------------------------------------------
-- Hooks must be registered BEFORE the first vim.pack.add() so they also run
-- when plugins are bootstrapped from the lockfile on a fresh machine.

--- Run `fn` once the plugin's code (plugin/ scripts, user commands) is loaded.
--- During startup, plugin/ files of everything on the runtimepath are sourced
--- after init.lua, so we wait for VimEnter. After startup (interactive
--- vim.pack.add/update) the plugin may not be loaded yet, so packadd it first.
local function after_load(ev, fn)
	if vim.v.vim_did_enter == 1 then
		if not ev.data.active then
			vim.cmd.packadd(ev.data.spec.name)
		end
		fn()
	else
		vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = fn })
	end
end

local hooks = {
	["nvim-treesitter"] = function(ev)
		-- Rebuild parsers whenever the plugin changes (queries and parser
		-- revisions are tied to the plugin version).
		if ev.data.kind == "update" then
			after_load(ev, function()
				vim.cmd("TSUpdate")
			end)
		end
	end,
	["go.nvim"] = function(ev)
		if vim.fn.executable("go") == 1 then
			after_load(ev, function()
				require("go.install").update_all_sync()
			end)
		end
	end,
	["vim-dirtytalk"] = function(ev)
		after_load(ev, function()
			require("config.spell").build() -- builds <data>/site/spell/programming.utf-8.spl
		end)
	end,
}

vim.api.nvim_create_autocmd("PackChanged", {
	group = vim.api.nvim_create_augroup("user.pack_hooks", { clear = true }),
	callback = function(ev)
		local hook = hooks[ev.data.spec.name]
		if hook and (ev.data.kind == "install" or ev.data.kind == "update") then
			hook(ev)
		end
	end,
})

-- Plugins -----------------------------------------------------------------
-- Dependencies are listed before the plugins that need them.
vim.pack.add({
	-- UI / appearance
	{ src = gh("rose-pine/neovim"), name = "rose-pine" },
	gh("nvim-mini/mini.icons"),
	gh("folke/which-key.nvim"),
	gh("j-hui/fidget.nvim"),

	-- Core editing
	gh("nvim-lua/plenary.nvim"),
	gh("folke/snacks.nvim"), -- picker (replaces telescope), vim.ui.select, zen mode, input
	gh("stevearc/oil.nvim"),
	{ src = gh("ThePrimeagen/harpoon"), version = "harpoon2" },
	gh("windwp/nvim-autopairs"),
	gh("NMAC427/guess-indent.nvim"),
	gh("psliwka/vim-dirtytalk"),
	gh("folke/trouble.nvim"),

	-- Treesitter (main branch; master is frozen and doesn't work on 0.12)
	{ src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
	gh("OXY2DEV/markview.nvim"),

	-- LSP / tooling
	gh("neovim/nvim-lspconfig"),
	gh("mason-org/mason.nvim"),
	gh("mason-org/mason-lspconfig.nvim"),
	gh("WhoIsSethDaniel/mason-tool-installer.nvim"),
	gh("folke/lazydev.nvim"),
	gh("stevearc/conform.nvim"),

	-- Completion (stay on the 1.x line; 2.x is still breaking things)
	{ src = gh("saghen/blink.cmp"), version = vim.version.range("1.x") },

	-- Git
	gh("tpope/vim-fugitive"),

	-- Debugging
	gh("mfussenegger/nvim-dap"),
	gh("nvim-neotest/nvim-nio"),
	gh("rcarriga/nvim-dap-ui"),
	gh("jay-babu/mason-nvim-dap.nvim"),
	gh("leoluz/nvim-dap-go"),
	gh("NicholasMata/nvim-dap-cs"),

	-- Languages
	gh("ray-x/guihua.lua"),
	gh("ray-x/go.nvim"),
	gh("seblyng/roslyn.nvim"), -- C# + Razor (rzls.nvim is superseded by this)
})
