return {
	"psliwka/vim-dirtytalk",
	event = "VeryLazy",
	build = ":DirtytalkUpdate",
	config = function()
		vim.opt.spelllang = { "en", "de" }
	end,
}
