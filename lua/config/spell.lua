-- Programming-aware spell dictionary built from vim-dirtytalk's word lists.
--
-- vim-dirtytalk's own :DirtytalkUpdate relies on the Vimscript spellfile
-- plugin, which Neovim 0.12 replaced with a Lua implementation, so we build
-- the spell file ourselves from the plugin's wordlists/ directory.

local M = {}

local function spell_dir()
	return vim.fs.joinpath(vim.fn.stdpath("data"), "site", "spell")
end

function M.spell_file()
	return vim.fs.joinpath(spell_dir(), "programming." .. vim.o.encoding .. ".spl")
end

--- Append "programming" to 'spelllang' if the spell file exists.
function M.enable()
	if vim.uv.fs_stat(M.spell_file()) and not vim.tbl_contains(vim.opt.spelllang:get(), "programming") then
		vim.opt.spelllang:append("programming")
	end
end

--- (Re)build the "programming" spell file. Blacklist word lists by their
--- basename, e.g. { "brands", "kubernetes" }.
---@param blacklist? string[]
function M.build(blacklist)
	blacklist = blacklist or {}
	local plugin = vim.api.nvim_get_runtime_file("wordlists/", false)[1]
	if not plugin then
		vim.notify("vim-dirtytalk wordlists not found on runtimepath", vim.log.levels.WARN)
		return
	end

	local words = {}
	for name, kind in vim.fs.dir(plugin) do
		local base = name:match("^(.*)%.words$")
		if kind == "file" and base and not vim.tbl_contains(blacklist, base) then
			vim.list_extend(words, vim.fn.readfile(vim.fs.joinpath(plugin, name)))
		end
	end

	local tmp = vim.fn.tempname()
	vim.fn.writefile(words, tmp)
	vim.fn.mkdir(spell_dir(), "p")
	vim.cmd(string.format("silent mkspell! %s %s", vim.fn.fnameescape(vim.fs.joinpath(spell_dir(), "programming")), vim.fn.fnameescape(tmp)))
	vim.fn.delete(tmp)
	M.enable()
	vim.notify("Built programming spell file (" .. #words .. " words)")
end

vim.api.nvim_create_user_command("DirtytalkBuild", function()
	M.build()
end, { desc = "Rebuild the programming spell dictionary" })

return M
