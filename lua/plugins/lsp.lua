-- LSP: mason for installing servers/tools, nvim-lspconfig for server configs,
-- vim.lsp.config/enable (core) for wiring them up.

-- Keymaps and per-buffer behaviour -------------------------------------
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("user.lsp_attach", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc, mode)
			vim.keymap.set(mode or "n", keys, func, { buf = event.buf, desc = "LSP: " .. desc })
		end
		local picker = Snacks.picker

		-- Neovim already provides: grn (rename), gra (code action), grr, gri,
		-- grt, gO, K, <C-s> (signature help). Override the list-returning ones
		-- with the picker; keep the rest.
		map("grr", function() picker.lsp_references() end, "[G]oto [R]eferences")
		map("gri", function() picker.lsp_implementations() end, "[G]oto [I]mplementation")
		map("grd", function() picker.lsp_definitions() end, "[G]oto [D]efinition")
		map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
		map("grt", function() picker.lsp_type_definitions() end, "[G]oto [T]ype Definition")
		map("gO", function() picker.lsp_symbols() end, "Open Document Symbols")
		map("gW", function() picker.lsp_workspace_symbols() end, "Open Workspace Symbols")

		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if not client then
			return
		end

		-- Highlight references of the symbol under the cursor while it rests there
		if client:supports_method("textDocument/documentHighlight", event.buf) then
			local group = vim.api.nvim_create_augroup("user.lsp_highlight", { clear = false })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buf = event.buf,
				group = group,
				callback = vim.lsp.buf.document_highlight,
			})
			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buf = event.buf,
				group = group,
				callback = vim.lsp.buf.clear_references,
			})
			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("user.lsp_detach", { clear = true }),
				callback = function(ev)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = "user.lsp_highlight", buf = ev.buf })
				end,
			})
		end

		if client:supports_method("textDocument/inlayHint", event.buf) then
			map("<leader>th", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
			end, "[T]oggle Inlay [H]ints")
		end

		if client:supports_method("textDocument/codeLens", event.buf) then
			vim.lsp.codelens.enable(true, { bufnr = event.buf })
		end
	end,
})

-- Diagnostics -------------------------------------------------------------
vim.diagnostic.config({
	severity_sort = true,
	float = { source = "if_many" },
	underline = { severity = vim.diagnostic.severity.ERROR },
	signs = vim.g.have_nerd_font and {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
	} or {},
	virtual_text = {
		source = "if_many",
		spacing = 2,
	},
})

-- Server configuration ---------------------------------------------------
-- nvim-lspconfig ships defaults for each server (lsp/<name>.lua on the
-- runtimepath); vim.lsp.config() merges overrides on top.
vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			completion = { callSnippet = "Replace" },
			-- diagnostics = { disable = { "missing-fields" } },
		},
	},
})

-- Servers installed through mason and enabled automatically by mason-lspconfig
-- (names are nvim-lspconfig names). roslyn is handled by roslyn.nvim.
local servers = {
	"gopls",
	"templ",
	"terraformls",
	"ts_ls",
	"html",
	"pylsp",
	"lua_ls",
}

-- Non-LSP tools (formatters, linters, debuggers) installed through mason.
local tools = {
	"stylua",
	"prettier",
	"csharpier",
	"golangci-lint",
	"delve",
	"netcoredbg",
	"roslyn", -- from the Crashdummyy registry; same build as VS Code
}

-- Mason -------------------------------------------------------------------
require("mason").setup({
	registries = {
		"github:mason-org/mason-registry",
		"github:Crashdummyy/mason-registry",
	},
})

require("mason-lspconfig").setup({
	ensure_installed = servers,
	automatic_enable = true, -- vim.lsp.enable() for every mason-installed server
})

require("mason-tool-installer").setup({
	ensure_installed = tools,
})
