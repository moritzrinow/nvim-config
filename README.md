# nvim config

Neovim **0.12+** configuration using the built-in package manager (`vim.pack`),
no lazy.nvim.

## Layout

```
init.lua                 entry point; requires everything below in order
lua/config/options.lua   editor options
lua/config/keymaps.lua   global keymaps
lua/config/autocmds.lua  global autocommands / filetype additions
lua/config/pack.lua      plugin list + PackChanged build hooks (only vim.pack.add call)
lua/plugins/*.lua        per-plugin setup
nvim-pack-lock.json      vim.pack lockfile (generated; commit it, don't edit it)
```

## Machine requirements

- Neovim >= 0.12
- `git`, `curl`, `tar`
- [`tree-sitter` CLI](https://github.com/tree-sitter/tree-sitter) >= 0.26 and a C
  compiler (nvim-treesitter `main` compiles parsers locally)
  - Windows: `winget install tree-sitter.tree-sitter` (or scoop/cargo) and e.g.
    `zig`/`clang`/MSVC on `PATH`
- `dotnet` SDK plus the easy-dotnet server: `dotnet tool install -g EasyDotnet`
  (easy-dotnet installs `roslyn-language-server` itself on first use)
- `go` (gopls, delve, go.nvim tools), `node` (prettier, ts_ls, html; optionally
  `npm install -g vscode-langservers-extracted` for HTML features in Razor files)
- A Nerd Font

## First start

1. Start `nvim`. `vim.pack` asks once to confirm installing the plugins (`y`, or `a` for all).
2. Restart (`:restart`). Mason installs the LSP servers and tools, treesitter installs parsers.
3. `:checkhealth vim.pack`, `:checkhealth nvim-treesitter`, `:checkhealth vim.lsp`.

## Versioning policy

Plugins that tag releases are locked to their current major in `lua/config/pack.lua`
(`version = vim.version.range("N.x")`): updates stay within `N.y.z`, a major bump is a
deliberate edit. Plugins with stale or no tags follow their default branch and are gated
by the lockfile + the update review buffer. nvim-treesitter (`main`) is updated together
with Neovim upgrades, not in the regular batch. Stay on Neovim stable patch releases.

## Day-to-day plugin management

| action | how |
| --- | --- |
| update everything | `<leader>pu` or `:lua vim.pack.update()` → review tab → `:write` to apply, `:quit` to discard |
| see what is installed | `<leader>pl` or `:lua vim.pack.update(nil, { offline = true })` |
| add a plugin | add it to `lua/config/pack.lua`, restart |
| remove a plugin | delete it from `pack.lua`, restart, `:lua vim.pack.del({ "name" })` |
| pin / unpin | set `version = "<tag|branch|commit>"` in `pack.lua`, restart, `vim.pack.update({ "name" })` |
| revert an update | `git checkout -- nvim-pack-lock.json`, restart, `:lua vim.pack.update(nil, { target = "lockfile" })` |
| new machine | clone, start nvim: everything installs at the lockfile revisions |

## Notes

- `:DirtytalkBuild` rebuilds the "programming" spell dictionary from vim-dirtytalk's
  word lists (its own `:DirtytalkUpdate` is broken on 0.12). It runs automatically
  when the plugin is installed or updated.
- .NET is handled by [easy-dotnet.nvim](https://github.com/GustavEikaas/easy-dotnet.nvim)
  (`lua/plugins/csharp.lua`): Roslyn LSP (client `easy_dotnet`, settings in
  `lsp/easy_dotnet.lua`), debugger, test runner, NuGet and project-file tooling,
  `///` doc comments. `:Dotnet` lists all commands; `:checkhealth easy-dotnet`.
  Updates: `:Dotnet _server update` (server), `dotnet-easydotnet roslyn update` (Roslyn).
- `:CsNew {class|interface|enum|record|struct} Name` creates a C# file and makes sure
  Roslyn adds it to its project first (works around a Roslyn bug on Windows where new
  files stay in "Miscellaneous Files"). `<leader>nn` is easy-dotnet's picker-based
  alternative.
- Treesitter parsers are compiled locally; `:checkhealth nvim-treesitter` shows what's
  missing on the machine.

## Keymaps

Leader is `<space>`. `<leader>sk` searches all keymaps, `<leader>?` shows buffer-local ones.

Highlights: `<leader>sf/sg/sw/s.` find files / grep / grep word / recent (snacks picker),
`<leader><leader>` buffers, `\` Oil, `<leader>a`/`<C-e>` harpoon, `<leader>f` format,
`<leader>xx` Trouble, `<leader>z` zen, `<F5>/<F1>/<F2>/<F3>/<leader>b` debugging
(`<F5>` in a C# buffer opens easy-dotnet's project / launch-profile picker).

.NET (`<leader>n`): `na`/`nr` add/remove NuGet package, `no` show outdated packages
(then `nu`/`nU` upgrade one/all), `nR` add project reference (in project files),
`nb` build with errors in quickfix, `ns` user secrets, `nn` new item.
Tests (`<leader>r`): `rr` toggle test runner; in test files `rt` run test,
`rf` run file, `rp` peek stack trace, and `<leader>dt` debug test.

LSP uses Neovim's default `gr*` mappings (`grn` rename, `gra` code action, `grr`
references, `gri` implementation, `grd` definition, `grt` type definition, `gO`
symbols) with the picker for list results, plus `<leader>th` for inlay hints.
