-- conform.nvim: formatting

require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "isort", "black" },
		javascript = { "prettier" },
		javascriptreact = { "prettier" },
		typescript = { "prettier" },
		typescriptreact = { "prettier" },
		html = { "prettier" },
		css = { "prettier" },
		scss = { "prettier" },
		json = { "prettier" },
		jsonc = { "prettier" },
		yaml = { "prettier" },
		markdown = { "prettier" },
		-- C#: Roslyn (LSP) only; if Roslyn isn't attached, nothing runs.
		cs = { lsp_format = "prefer" },
		go = { "goimports", "gofmt" },
		-- Fallback for filetypes without a formatter of their own (built-in).
		["_"] = { "trim_whitespace" },
	},
	default_format_opts = {
		lsp_format = "fallback",
	},
	-- format_on_save = { timeout_ms = 500 },
	formatters = {
		shfmt = { prepend_args = { "-i", "2" } },
	},
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.keymap.set("", "<leader>f", function()
	require("conform").format({ async = true })
end, { desc = "[F]ormat buffer" })
