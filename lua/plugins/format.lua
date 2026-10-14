-- conform.nvim: formatting

require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "isort", "black" },
		javascript = { "prettier" },
		typescript = { "prettier" },
		html = { "prettier" },
		cs = { "csharpier" },
		go = { "goimports", "gofmt" },
	},
	default_format_opts = {
		lsp_format = "fallback",
	},
	-- format_on_save = { timeout_ms = 500 },
	formatters = {
		shfmt = { prepend_args = { "-i", "2" } },
		csharpier = {
			command = "csharpier",
			args = { "format", "--write-stdout" },
		},
	},
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.keymap.set("", "<leader>f", function()
	require("conform").format({ async = true })
end, { desc = "[F]ormat buffer" })
