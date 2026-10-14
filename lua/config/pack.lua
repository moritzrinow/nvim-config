-- Plugin list and build hooks for vim.pack (:h vim.pack).
--
-- vim.pack has no lazy-loading: every plugin here is on the runtimepath after
-- this file runs, and their plugin/ scripts are sourced once init.lua finishes.
-- Startup stays fast anyway thanks to vim.loader; everything is "lazy" at the
-- require() level.
--
-- Versioning policy (stability first):
--   * Plugins that tag releases are locked to their current major with
--     vim.version.range("N.x"): vim.pack.update() moves to the newest N.y.z
--     tag and never crosses into N+1. Bumping a major is a deliberate edit here.
--   * Plugins with stale or no tags follow their default branch; the lockfile
--     (nvim-pack-lock.json) plus the vim.pack.update() review buffer are the
--     gate. Read the commit log before :write.
--   * nvim-treesitter (main) only supports the latest stable/nightly Neovim:
--     update it together with Neovim upgrades, not in the regular batch.

local gh = function(repo)
	return "https://github.com/" .. repo
end
local major = function(n)
	return vim.version.range(n .. ".x")
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
	gh("aktersnurra/no-clown-fiesta.nvim"), -- colorscheme; untagged
	{ src = gh("nvim-mini/mini.icons"), version = "stable" }, -- mini.* release branch
	{ src = gh("folke/which-key.nvim"), version = major(3) },
	{ src = gh("j-hui/fidget.nvim"), version = major(2) },

	-- Core editing
	gh("nvim-lua/plenary.nvim"), -- tags are ancient (v0.1.4); follow master
	{ src = gh("folke/snacks.nvim"), version = major(2) }, -- picker, vim.ui.select, zen, input
	{ src = gh("stevearc/oil.nvim"), version = major(2) },
	{ src = gh("ThePrimeagen/harpoon"), version = "harpoon2" }, -- untagged
	gh("windwp/nvim-autopairs"), -- single stale tag; follow master
	gh("NMAC427/guess-indent.nvim"), -- untagged
	gh("psliwka/vim-dirtytalk"), -- untagged
	{ src = gh("folke/trouble.nvim"), version = major(3) },

	-- Treesitter (main branch; master is frozen and doesn't work on 0.12).
	-- Untagged on main: update together with Neovim upgrades.
	{ src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
	{ src = gh("OXY2DEV/markview.nvim"), version = major(29) }, -- majors are breaking; bump deliberately

	-- LSP / tooling
	{ src = gh("neovim/nvim-lspconfig"), version = major(2) },
	{ src = gh("mason-org/mason.nvim"), version = major(2) },
	{ src = gh("mason-org/mason-lspconfig.nvim"), version = major(2) },
	gh("WhoIsSethDaniel/mason-tool-installer.nvim"), -- untagged
	{ src = gh("folke/lazydev.nvim"), version = major(1) },
	{ src = gh("stevearc/conform.nvim"), version = major(9) },

	-- Completion (2.x is still breaking things)
	{ src = gh("saghen/blink.cmp"), version = major(1) },

	-- Git
	gh("tpope/vim-fugitive"), -- untagged, effectively frozen

	-- Debugging
	gh("mfussenegger/nvim-dap"), -- tags lag far behind fixes; follow master
	{ src = gh("nvim-neotest/nvim-nio"), version = major(1) },
	gh("rcarriga/nvim-dap-ui"), -- last tag 2024; follow master
	{ src = gh("jay-babu/mason-nvim-dap.nvim"), version = major(2) },
	gh("leoluz/nvim-dap-go"), -- untagged
	gh("NicholasMata/nvim-dap-cs"), -- untagged

	-- Languages
	gh("ray-x/guihua.lua"), -- untagged
	gh("ray-x/go.nvim"), -- tags lag far behind fixes; follow master
	gh("seblyng/roslyn.nvim"), -- untagged; C# + Razor (rzls.nvim is superseded by this)
})
