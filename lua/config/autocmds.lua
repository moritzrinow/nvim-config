local augroup = function(name)
	return vim.api.nvim_create_augroup("user." .. name, { clear = true })
end

-- Highlight when yanking (copying) text. Try it with `yap` in normal mode.
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking text",
	group = augroup("highlight_yank"),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- Razor / cshtml filetypes (roslyn.nvim handles the LSP side)
vim.filetype.add({
	extension = {
		razor = "razor",
		cshtml = "razor",
	},
})
