return {
	"psliwka/vim-dirtytalk",
	build = ":DirtytalkUpdate",
	config = function()
		vim.opt.spelllang = { "en", "de", "programming" }
	end,
}
