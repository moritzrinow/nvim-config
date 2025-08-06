This is my personal Neovim config for 0.11+.

Plugins are managed via [lazy.nvim](https://github.com/folke/lazy.nvim).

Global stuff is configured in [init.lua](init.lua).

Plugins are configured in the [plugins](lua/plugins) directory.

Features:
- [Rose Pine](https://github.com/rose-pine/neovim) theme.
- Syntax highlighting with [Treesitter](https://github.com/nvim-treesitter/nvim-treesitter).
- Fuzzy finding with [Telescope](https://github.com/nvim-telescope/telescope.nvim).
- Filesystem navigation with [Neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) and [Harpoon](https://github.com/ThePrimeagen/harpoon).
- Completion with [Blink Completion](https://github.com/Saghen/blink.cmp).
- Formatting via [Conform](https://github.com/stevearc/conform.nvim).
- Automatic indentation detection with [Guess Indent](https://github.com/NMAC427/guess-indent.nvim).
- Focus mode with [Zen Mode](https://github.com/folke/zen-mode.nvim).
- Easily remembered keybindings with [Which Key](https://github.com/folke/which-key.nvim).
- Diagnostics listing with [Trouble](https://github.com/folke/trouble.nvim).
- Inline Markdown preview via [Markview](https://github.com/OXY2DEV/markview.nvim).
- [Mason](https://github.com/mason-org/mason.nvim) for managing LSPs, formatters and Co.
- Preinstalled external tools via [mason-tool-installer](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim) for development with:
    - Terraform
    - Go
    - HTML, CSS, JS, TS
    - .NET
    - Lua
