-- C# / Razor via roslyn.nvim.
--
-- roslyn.nvim provides lsp/roslyn.lua (cmd, root_dir, handlers) and calls
-- vim.lsp.enable("roslyn") itself. It finds the server at
-- $MASON/bin/roslyn-language-server, which the "roslyn" mason package from the
-- Crashdummyy registry provides (see plugins/lsp.lua). Razor/cshtml support is
-- built into the server now; rzls.nvim and the "rzls" mason package are no
-- longer needed.

require("roslyn").setup({
	-- "auto" | "roslyn" | "off"
	filewatching = "auto",
	-- Look for solutions above the current root as well
	broad_search = false,
	-- Keep the solution picked with :Roslyn target
	lock_target = false,
})

-- Settings sent to the server (merged on top of the plugin's lsp/roslyn.lua)
vim.lsp.config("roslyn", {
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
})
