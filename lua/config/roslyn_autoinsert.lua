-- `///` doc-comment generation for C#, like Visual Studio / VS Code.
--
-- Roslyn implements this through its custom `textDocument/_vs_onAutoInsert`
-- request, which roslyn.nvim doesn't wire up. When the third `/` is typed on
-- an otherwise empty line, ask Roslyn for the doc-comment snippet
-- (<summary>, <param>, <returns>, ...) and expand it with vim.snippet.

local M = {}

local METHOD = "textDocument/_vs_onAutoInsert"
local SNIPPET_FORMAT = 2 -- lsp.InsertTextFormat.Snippet

---@param buf integer
---@param client vim.lsp.Client
---@param pos lsp.Position
---@return integer row, integer col 0-based row, byte col
local function to_byte_pos(buf, client, pos)
	local line = vim.api.nvim_buf_get_lines(buf, pos.line, pos.line + 1, false)[1] or ""
	local ok, col = pcall(vim.str_byteindex, line, client.offset_encoding, pos.character, false)
	return pos.line, ok and col or #line
end

---@param client vim.lsp.Client
---@param buf integer
local function on_slash(client, buf)
	if vim.api.nvim_get_current_buf() ~= buf or vim.fn.mode() ~= "i" then
		return
	end
	local col = vim.api.nvim_win_get_cursor(0)[2]
	if not vim.api.nvim_get_current_line():sub(1, col):match("^%s*///$") then
		return
	end

	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	local tick = vim.b[buf].changedtick

	client:request(METHOD, {
		_vs_textDocument = params.textDocument,
		_vs_position = params.position,
		_vs_ch = "/",
		_vs_options = {
			tabSize = vim.bo[buf].shiftwidth > 0 and vim.bo[buf].shiftwidth or vim.bo[buf].tabstop,
			insertSpaces = vim.bo[buf].expandtab,
		},
	}, function(err, result)
		if err or not result or not result._vs_textEdit then
			return
		end
		-- Bail out if the user kept typing or left insert mode meanwhile.
		if
			vim.b[buf].changedtick ~= tick
			or vim.api.nvim_get_current_buf() ~= buf
			or vim.fn.mode() ~= "i"
		then
			return
		end

		local edit = result._vs_textEdit
		local text = edit.newText:gsub("\r\n", "\n")

		if result._vs_textEditFormat ~= SNIPPET_FORMAT then
			vim.lsp.util.apply_text_edits({ edit }, buf, client.offset_encoding)
			return
		end

		local srow, scol = to_byte_pos(buf, client, edit.range.start)
		local erow, ecol = to_byte_pos(buf, client, edit.range["end"])
		vim.api.nvim_buf_set_text(buf, srow, scol, erow, ecol, {})
		vim.api.nvim_win_set_cursor(0, { srow + 1, scol })

		-- Roslyn's snippet already contains the indentation of follow-up lines,
		-- but vim.snippet.expand() adds the current line's indentation itself:
		-- strip it once so it isn't doubled.
		local indent = vim.api.nvim_get_current_line():match("^%s*") or ""
		if indent ~= "" then
			local lines = vim.split(text, "\n", { plain = true })
			for i = 2, #lines do
				if vim.startswith(lines[i], indent) then
					lines[i] = lines[i]:sub(#indent + 1)
				end
			end
			text = table.concat(lines, "\n")
		end

		vim.snippet.expand(text)
	end, buf)
end

local group = vim.api.nvim_create_augroup("user.roslyn_autoinsert", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
	group = group,
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client or client.name ~= "roslyn" or vim.b[ev.buf].roslyn_autoinsert then
			return
		end
		vim.b[ev.buf].roslyn_autoinsert = true

		vim.api.nvim_create_autocmd("InsertCharPre", {
			group = group,
			buf = ev.buf,
			callback = function()
				if vim.v.char == "/" then
					-- Runs after the character has been inserted.
					vim.schedule(function()
						on_slash(client, ev.buf)
					end)
				end
			end,
		})
	end,
})

return M
