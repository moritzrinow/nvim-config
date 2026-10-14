-- blink.cmp + lazydev
--
-- Snippets use Neovim's built-in vim.snippet (blink's default); LuaSnip was
-- dropped since no custom snippets were loaded.

require("lazydev").setup({
	library = {
		-- Load luvit types when the `vim.uv` word is found
		{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
	},
})

require("blink.cmp").setup({
	keymap = {
		-- 'default': <C-y> accept, <C-space> open menu/docs, <C-e> hide,
		-- <Tab>/<S-Tab> snippet jump, <C-n>/<C-p> next/prev
		preset = "default",
		["<C-k>"] = { "select_prev", "fallback" },
		["<C-j>"] = { "select_next", "fallback" },
	},

	appearance = {
		nerd_font_variant = "mono",
	},

	completion = {
		documentation = { auto_show = false, auto_show_delay_ms = 500 },
	},

	sources = {
		default = { "lsp", "path", "snippets", "lazydev" },
		providers = {
			lazydev = { module = "lazydev.integrations.blink", score_offset = 100 },
		},
	},

	-- Pure-Lua matcher; no build step needed. Switch to "prefer_rust_with_warning"
	-- to download the prebuilt Rust matcher for faster fuzzy matching.
	fuzzy = { implementation = "lua" },

	signature = { enabled = true },
})
