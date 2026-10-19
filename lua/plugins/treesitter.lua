-- nvim-treesitter (main branch).
--
-- On `main` the plugin only installs parsers/queries; highlighting, indentation
-- and folding are enabled with core Neovim APIs per filetype.
-- Requirements on the machine: tree-sitter CLI (>= 0.26), a C compiler, tar, curl.

local ts = require("nvim-treesitter")
ts.setup({})

-- Parsers to keep installed (no-op if already present).
-- markview.nvim needs markdown, markdown_inline, html, latex, yaml.
-- easy-dotnet's language injections (//language=sql|json|xml) need sql, json, xml;
-- json5 is its filetype for appsettings.json / launchSettings.json.
local ensure_installed = {
	"bash",
	"c",
	"c_sharp",
	"diff",
	"go",
	"gomod",
	"gosum",
	"gowork",
	"html",
	"javascript",
	"json",
	"json5",
	"latex",
	"lua",
	"luadoc",
	"markdown",
	"markdown_inline",
	"python",
	"query",
	"razor",
	"regex",
	"sql",
	"terraform",
	"hcl",
	"templ",
	"typescript",
	"tsx",
	"vim",
	"vimdoc",
	"xml",
	"yaml",
}

local installed = ts.get_installed()
local missing = vim.iter(ensure_installed)
	:filter(function(lang)
		return not vim.tbl_contains(installed, lang)
	end)
	:totable()
if #missing > 0 then
	ts.install(missing)
end

-- Enable treesitter features for every buffer that has a parser.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("user.treesitter", { clear = true }),
	callback = function(ev)
		local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
		if not vim.treesitter.language.add(lang) then
			return
		end
		vim.treesitter.start(ev.buf, lang)
		-- Only let treesitter drive indentation when it has indent queries for
		-- the language; otherwise keep Neovim's own indent/<ft>.vim (e.g. C#
		-- has no indents.scm on nvim-treesitter main, but indent/cs.vim works).
		if vim.treesitter.query.get(lang, "indents") then
			vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})
