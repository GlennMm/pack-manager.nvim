# Pack-Manager.nvim

A modern plugin manager for Neovim built on top of vim.pack.

## Features

- 🚀 Built on vim.pack - Uses Neovim's native plugin system
- 🔄 Lazy Loading - Load plugins on demand (events, commands, filetypes, keys)
- 📦 Dependency Resolution - Automatic plugin ordering
- 🎯 GitHub Shorthand - Use `'user/repo'` format
- ⚡ Performance - Fast startup with smart loading
- 🛠️ User Commands - `:Pack status`, `:Pack update`, etc.

## Installation

### Using vim.pack directly
```bash
git clone https://github.com/GlennMm/pack-manager.nvim \
  ~/.local/share/nvim/site/pack/core/start/pack-manager
