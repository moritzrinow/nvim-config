-- Terminals and one-off shell commands, run in the directory you're looking
-- at: Oil's current directory, else the current file's directory, else the
-- working directory. Built on snacks.nvim's terminal (plugins/picker.lua).
--
--   <leader>tt  toggle a terminal in that directory (one per directory)
--   <leader>!   prompt for a command and run it there; output stays in a
--               bottom split (q closes it)
--
-- In a terminal: <Esc><Esc> for normal mode, q (normal mode) hides it.

--- Directory to run in: Oil's directory, the current file's, or the cwd.
local function target_dir()
	if vim.bo.filetype == "oil" then
		local ok, oil = pcall(require, "oil")
		local dir = ok and oil.get_current_dir()
		if dir then
			return vim.fs.normalize(dir)
		end
	end
	local name = vim.api.nvim_buf_get_name(0)
	if name ~= "" and vim.bo.buftype == "" then
		return vim.fs.dirname(vim.fs.normalize(name))
	end
	return vim.fs.normalize(vim.uv.cwd())
end

local split = { position = "bottom" }

vim.keymap.set("n", "<leader>tt", function()
	Snacks.terminal.toggle(nil, { cwd = target_dir(), win = split })
end, { desc = "[T]oggle [T]erminal in current directory" })

local last_cmd
vim.keymap.set("n", "<leader>!", function()
	local cwd = target_dir()
	vim.ui.input({
		prompt = "Run in " .. vim.fn.fnamemodify(cwd, ":~") .. ": ",
		default = last_cmd,
	}, function(cmd)
		if not cmd or vim.trim(cmd) == "" then
			return
		end
		last_cmd = cmd
		local term = Snacks.terminal.open(cmd, {
			cwd = cwd,
			-- keep the output: no auto insert, don't close when the command exits
			interactive = false,
			win = vim.tbl_extend("force", split, { bo = { bufhidden = "wipe" } }),
		})
		term:on("TermClose", function()
			local code = vim.v.event.status
			vim.notify(
				("`%s` exited with code %d"):format(cmd, code),
				code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
			)
			-- pick up files the command changed
			vim.cmd.checktime()
		end, { buf = true })
	end)
end, { desc = "Run shell command in current directory" })
