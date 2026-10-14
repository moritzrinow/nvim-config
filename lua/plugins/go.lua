-- go.nvim (gopls itself is installed/enabled via mason in plugins/lsp.lua)
-- Go binaries used by go.nvim are installed by the PackChanged hook in
-- lua/config/pack.lua; run :GoInstallBinaries to (re)install manually.

require("go").setup({
	-- lsp_cfg = false is the default: gopls is configured by nvim-lspconfig/mason.
	-- lsp_keymaps = false,
})
