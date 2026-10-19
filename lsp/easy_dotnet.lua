-- Settings for easy-dotnet's Roslyn client ("easy_dotnet").
-- Merged on top of easy-dotnet's defaults (see lua/plugins/csharp.lua).

-- Roslyn reports projects it can't load (invalid .csproj, unsupported SDK,
-- failed restore) only as window/logMessage, which Neovim writes to lsp.log
-- and nowhere else. Keep that, and also notify about project-load errors,
-- once per message and session (Roslyn repeats them on every reload).
local seen = {}
local function log_message(err, params, ctx)
	vim.lsp.handlers["window/logMessage"](err, params, ctx)
	if not params or params.type ~= vim.lsp.protocol.MessageType.Error then
		return
	end
	local project, reason = (params.message or ""):match("Error while loading (.-%.%a+proj): (.*)")
	if not project or seen[params.message] then
		return
	end
	seen[params.message] = true
	vim.schedule(function()
		vim.notify(
			("Roslyn could not load %s:\n%s"):format(vim.fs.basename((project:gsub("\\", "/"))), vim.trim(reason)),
			vim.log.levels.ERROR,
			{ title = "Roslyn" }
		)
	end)
end

---@type vim.lsp.Config
return {
	handlers = {
		["window/logMessage"] = log_message,
	},
	settings = {
		["csharp|inlay_hints"] = {
			csharp_enable_inlay_hints_for_implicit_object_creation = true,
			csharp_enable_inlay_hints_for_implicit_variable_types = false,
			csharp_enable_inlay_hints_for_lambda_parameter_types = true,
			csharp_enable_inlay_hints_for_types = false,
			dotnet_enable_inlay_hints_for_indexer_parameters = true,
			dotnet_enable_inlay_hints_for_literal_parameters = true,
			dotnet_enable_inlay_hints_for_object_creation_parameters = true,
			dotnet_enable_inlay_hints_for_other_parameters = true,
			dotnet_enable_inlay_hints_for_parameters = false,
			dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
			dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
			dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
		},
		["csharp|code_lens"] = {
			dotnet_enable_references_code_lens = true,
		},
		["csharp|completion"] = {
			dotnet_show_completion_items_from_unimported_namespaces = true,
			dotnet_show_name_completion_suggestions = true,
		},
		-- Analyse the whole solution so workspace diagnostics (<leader>xw)
		-- cover unopened files too. Costs CPU/memory on big solutions;
		-- switch back to "openFiles" if the server gets heavy.
		["csharp|background_analysis"] = {
			dotnet_analyzer_diagnostics_scope = "fullSolution",
			dotnet_compiler_diagnostics_scope = "fullSolution",
		},
	},
}
