# 📦 Pack-Manager.nvim

> A modern, fast, and lightweight plugin manager for Neovim built on vim.pack

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.8+-green.svg)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Made%20with-Lua-blueviolet.svg)](https://lua.org)

## ✨ Features

- 🚀 **Built on vim.pack** - Leverages Neovim's native plugin system
- ⚡ **Blazing fast** - Minimal overhead, maximum performance
- 🔄 **Lazy loading** - Load plugins on demand (events, commands, filetypes, keys)
- 📦 **Dependency resolution** - Automatic plugin ordering and dependency management
- 🎯 **GitHub shorthand** - Use simple `'user/repo'` format
- 🛠️ **Plugin configuration** - Built-in setup and config functions
- 📊 **Rich status display** - See what's loaded, lazy, or disabled
- 🔧 **User commands** - `:Pack status`, `:Pack update`, and more
- 🪝 **Hooks system** - Custom callbacks for install, update, and load events
- 🔌 **Drop-in replacement** - Easy migration from lazy.nvim, packer.nvim

## 🎯 Philosophy

Pack-Manager embraces Neovim's native capabilities while adding modern conveniences. It's designed to be:

- **Simple** - Minimal API surface, easy to understand
- **Fast** - No unnecessary abstractions or overhead
- **Reliable** - Built on battle-tested vim.pack foundation
- **Flexible** - Supports complex plugin configurations and lazy loading patterns

## 📋 Requirements

- **Neovim** >= 0.8.0 (for vim.pack support)
- **Git** >= 2.19.0 (for plugin installation)

## 🚀 Installation

### Method 1: Auto-install (Recommended)

Add this to your `init.lua`:

```lua
-- Auto-install pack-manager
local pack_path = vim.fn.stdpath('data') .. '/site/pack/core/start/pack-manager.nvim'
if not vim.uv.fs_stat(pack_path) then
  vim.notify("Installing pack-manager.nvim...")
  vim.fn.system({
    'git', 'clone', '--depth=1',
    'https://github.com/GlennMm/pack-manager.nvim.git',
    pack_path
  })
  vim.cmd('packloadall!')
  vim.notify("Pack-manager installed! Please restart Neovim.")
end
```

### Method 2: Manual Installation

```bash
git clone https://github.com/GlennMm/pack-manager.nvim.git \
  ~/.local/share/nvim/site/pack/core/start/pack-manager.nvim
```

### Method 3: Using Another Plugin Manager

```lua
-- With lazy.nvim
{
  'GlennMm/pack-manager.nvim',
  lazy = false,
  priority = 1000,
}

-- With packer.nvim
use 'GlennMm/pack-manager.nvim'
```

## 🏁 Quick Start

Create `lua/plugins.lua`:

```lua
local pack = require('pack-manager')

-- Configure pack-manager
pack.setup({
  auto_install = true,
  show_progress = true,
})

-- Add your plugins
pack.add({
  -- Simple plugins
  'nvim-lua/plenary.nvim',
  'nvim-tree/nvim-web-devicons',
  
  -- Plugin with configuration
  {
    src = 'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = { 'lua', 'vim', 'vimdoc' },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  },
  
  -- Lazy-loaded plugin
  {
    src = 'folke/which-key.nvim',
    keys = { '<leader>' },
    setup = {
      plugins = { spelling = true },
      triggers_blacklist = { i = { 'j', 'k' } }
    }
  },
  
  -- Plugin with dependencies and key mappings
  {
    src = 'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'Telescope',
    keys = {
      { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Find Files' },
      { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Live Grep' },
      { '<leader>fb', '<cmd>Telescope buffers<cr>', desc = 'Buffers' },
    },
    setup = {
      defaults = {
        file_ignore_patterns = { "node_modules", ".git/" }
      }
    }
  }
})
```

Then add to your `init.lua`:

```lua
require('plugins')
```

## ⚙️ Configuration

### Setup Options

```lua
require('pack-manager').setup({
  -- Auto-install missing plugins
  auto_install = true,
  
  -- Auto-update plugins on startup (not recommended)
  auto_update = false,
  
  -- Show progress notifications
  show_progress = true,
  
  -- Install plugins in parallel
  parallel_install = true,
  
  -- Git operation timeout (seconds)
  git_timeout = 60,
  
  -- Log level for messages
  log_level = vim.log.levels.INFO,
  
  -- Event hooks
  hooks = {
    pre_install = function(data)
      print('Installing: ' .. data.spec.src)
    end,
    post_install = function(data)
      vim.notify('✓ Installed: ' .. data.spec.src)
    end,
    pre_update = function(names)
      print('Updating plugins...')
    end,
    post_update = function(names)
      vim.notify('✓ Update complete')
    end,
    pre_load = function(name, plugin)
      -- Called before loading a lazy plugin
    end,
    post_load = function(name, plugin)
      -- Called after loading a lazy plugin
    end,
  },
  
  -- UI configuration
  ui = {
    icons = {
      loaded = "●",
      not_loaded = "○", 
      installed = "✓",
      error = "✗",
      pending = "⏳",
      update = "↑",
    }
  }
})
```

## 📖 Plugin Specification

### Basic Formats

```lua
-- String format (GitHub shorthand)
'user/repo'

-- Table format
{
  src = 'user/repo',           -- Required: GitHub repo or full URL
  -- ... options
}

-- Array format  
{ 'user/repo', lazy = true, event = 'BufRead' }
```

### All Available Options

```lua
{
  -- Required
  src = 'user/repo',           -- Plugin source (GitHub shorthand or full URL)
  
  -- Basic options
  name = 'custom-name',        -- Custom plugin name (auto-detected if not provided)
  version = 'v1.0.0',         -- Git tag, branch, or commit hash
  enabled = true,             -- Enable/disable plugin
  priority = 50,              -- Load priority (higher = earlier)
  
  -- Lazy loading
  lazy = false,               -- Enable lazy loading
  event = 'BufRead',          -- Event(s) to trigger loading
  cmd = 'Command',            -- Command(s) to trigger loading  
  ft = 'lua',                 -- Filetype(s) to trigger loading
  keys = '<leader>key',       -- Key mapping(s) to trigger loading
  
  -- Dependencies and building
  dependencies = { 'dep1', 'dep2' },  -- Plugin dependencies
  build = ':BuildCommand',    -- Build command (string, function, or vim command)
  
  -- Configuration
  setup = { option = true },  -- Config passed to plugin.setup()
  config = function()         -- Custom configuration function
    -- Configure plugin here
  end,
  
  -- Key mappings (for lazy loading)
  keys = {
    '<leader>f',              -- Simple key
    { '<leader>ff', '<cmd>Files<cr>', desc = 'Find Files' },  -- Key with command
    {                         -- Advanced key specification
      '<leader>fg',
      function() require('telescope.builtin').live_grep() end,
      mode = 'n',
      desc = 'Live Grep'
    }
  }
}
```

### GitHub URL Formats

```lua
pack.add({
  -- GitHub shorthand (recommended)
  'folke/lazy.nvim',
  'nvim-lua/plenary.nvim',
  
  -- Full GitHub URLs
  'https://github.com/folke/lazy.nvim',
  'https://github.com/nvim-lua/plenary.nvim.git',
  
  -- Other Git hosting
  'https://gitlab.com/user/repo.git',
  'https://codeberg.org/user/repo',
})
```

## 🔄 Lazy Loading

Pack-manager supports multiple lazy loading mechanisms:

### Event-based Loading

```lua
{
  src = 'plugin/repo',
  lazy = true,
  event = 'BufRead',                    -- Single event
  -- or
  event = { 'BufRead', 'BufNewFile' }   -- Multiple events
}
```

**Common events**: `BufRead`, `BufNewFile`, `InsertEnter`, `CmdlineEnter`, `VeryLazy`

### Command-based Loading

```lua
{
  src = 'plugin/repo', 
  lazy = true,
  cmd = 'PluginCommand',                -- Single command
  -- or
  cmd = { 'Cmd1', 'Cmd2' }             -- Multiple commands
}
```

### Filetype-based Loading

```lua
{
  src = 'plugin/repo',
  lazy = true, 
  ft = 'lua',                          -- Single filetype
  -- or
  ft = { 'lua', 'vim', 'python' }      -- Multiple filetypes
}
```

### Key-based Loading

```lua
{
  src = 'plugin/repo',
  lazy = true,
  keys = {
    '<leader>f',                       -- Simple key
    { '<leader>ff', '<cmd>Files<cr>', desc = 'Find Files' },
    {                                  -- Advanced configuration
      '<leader>fg', 
      function() require('telescope.builtin').live_grep() end,
      mode = { 'n', 'v' },
      desc = 'Live Grep'
    }
  }
}
```

### Combining Lazy Loading Methods

```lua
{
  src = 'nvim-telescope/telescope.nvim',
  lazy = true,
  cmd = { 'Telescope' },
  keys = {
    { '<leader>ff', '<cmd>Telescope find_files<cr>' },
    { '<leader>fg', '<cmd>Telescope live_grep<cr>' }
  },
  event = 'VeryLazy'  -- Fallback if not triggered by cmd/keys
}
```

## 🎛️ Commands

| Command | Description |
|---------|-------------|
| `:Pack status` | Show detailed plugin status |
| `:Pack update [names]` | Update all plugins or specific ones |
| `:Pack install` | Install missing plugins |
| `:Pack sync` | Install missing + update existing |
| `:Pack clean` | Remove unused plugins |

### Command Examples

```vim
:Pack status                    " Show all plugin status
:Pack update                    " Update all plugins  
:Pack update telescope plenary  " Update specific plugins
:Pack install                   " Install missing plugins
:Pack sync                      " Full synchronization
:Pack clean                     " Remove unused plugins
```

## 🔌 API Reference

### Core Functions

```lua
local pack = require('pack-manager')

-- Setup and configuration
pack.setup(config)              -- Configure pack-manager
pack.add(specs, opts)          -- Add plugins

-- Manual plugin management  
pack.load_plugin(name)         -- Load specific plugin
pack.status()                  -- Show status
pack.update(names, opts)       -- Update plugins
pack.install_missing()         -- Install missing
pack.sync()                    -- Install + update
pack.clean()                   -- Remove unused
pack.get_plugins()             -- Get plugin info
```

## 🔄 Migration Guide

### From lazy.nvim

Most lazy.nvim configurations work with minimal changes:

```lua
-- lazy.nvim
{
  'folke/which-key.nvim',
  lazy = true,
  keys = { '<leader>' },
  opts = { plugins = { spelling = true } }
}

-- pack-manager (change opts → setup)
{
  src = 'folke/which-key.nvim',
  lazy = true, 
  keys = { '<leader>' },
  setup = { plugins = { spelling = true } }
}
```

**Key differences**:
- `opts = {}` → `setup = {}`
- `init = function()` → `config = function()`
- Add `src =` field (or use array format)

### From packer.nvim

```lua
-- packer.nvim
use {
  'nvim-telescope/telescope.nvim',
  requires = { 'nvim-lua/plenary.nvim' },
  config = function() 
    require('telescope').setup({})
  end
}

-- pack-manager
{
  src = 'nvim-telescope/telescope.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('telescope').setup({})
  end
}
```

**Key differences**:
- `use { ... }` → add to `pack.add({ ... })`
- `requires = {}` → `dependencies = {}`
- `run = 'cmd'` → `build = 'cmd'`

### From vim-plug

```lua
-- vim-plug
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

-- pack-manager
pack.add({
  {
    src = 'junegunn/fzf', 
    build = function() vim.fn['fzf#install']() end
  },
  'junegunn/fzf.vim'
})
```

## 📊 Examples

### Complete Configuration Example

```lua
-- lua/plugins.lua
local pack = require('pack-manager')

pack.setup({
  auto_install = true,
  show_progress = false,  -- Silent operation
  hooks = {
    post_install = function(data)
      vim.notify('Installed: ' .. data.spec.src)
    end
  }
})

pack.add({
  -- Essential dependencies
  'nvim-lua/plenary.nvim',
  'nvim-tree/nvim-web-devicons',
  
  -- Treesitter
  {
    src = 'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'BufRead', 'BufNewFile' },
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = { 'lua', 'vim', 'vimdoc', 'query' },
        highlight = { enable = true },
        indent = { enable = true }
      })
    end
  },
  
  -- LSP Configuration
  {
    src = 'neovim/nvim-lspconfig',
    event = { 'BufRead', 'BufNewFile' },
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim'
    },
    config = function()
      require('lspconfig').lua_ls.setup({})
      require('lspconfig').pyright.setup({})
    end
  },
  
  -- Fuzzy Finder
  {
    src = 'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'Telescope',
    keys = {
      { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Find Files' },
      { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Live Grep' },
      { '<leader>fb', '<cmd>Telescope buffers<cr>', desc = 'Buffers' },
      { '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = 'Help Tags' }
    },
    setup = {
      defaults = {
        file_ignore_patterns = { "%.git/", "node_modules/" },
        layout_config = { horizontal = { preview_width = 0.5 } }
      }
    }
  },
  
  -- Git Integration  
  {
    src = 'lewis6991/gitsigns.nvim',
    event = { 'BufRead', 'BufNewFile' },
    setup = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' }
      }
    }
  },
  
  -- Status Line
  {
    src = 'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    setup = {
      options = { theme = 'auto', globalstatus = true },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { 'filename' },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' }
      }
    }
  },
  
  -- Which Key
  {
    src = 'folke/which-key.nvim',
    keys = { '<leader>', '<c-r>', '<c-w>', '"', "'", '`', 'c', 'v', 'g' },
    setup = {
      plugins = { spelling = true },
      triggers_blacklist = { i = { 'j', 'k' }, v = { 'j', 'k' } }
    }
  }
})
```

## 🐛 Troubleshooting

### Plugin Not Loading

1. Check plugin status: `:Pack status`
2. Verify configuration syntax
3. Check for lazy loading conflicts
4. Look at `:messages` for errors

### Performance Issues

1. Use lazy loading for non-essential plugins
2. Check startup time: `nvim --startuptime startup.log`
3. Review plugin priorities
4. Consider disabling unused plugins

### Installation Problems  

1. Verify Git installation: `git --version`
2. Check network connectivity
3. Ensure proper permissions in data directory
4. Review error messages in `:messages`

### Common Fixes

```lua
-- Plugin not found
pack.add({
  { src = 'user/repo' }  -- Make sure 'src' field exists
})

-- Setup vs config confusion
{
  setup = { option = true },      -- Calls require('plugin').setup(config)
  config = function()             -- Custom configuration function
    require('plugin').setup({ option = true })
  end
}

-- Lazy loading not working
{
  lazy = true,                    -- Must be explicitly set
  event = 'BufRead'              -- Ensure event is correct
}
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/GlennMm/pack-manager.nvim.git
cd pack-manager.nvim

# Install development tools
luarocks install luacheck
# Install StyLua from: https://github.com/JohnnyMorganz/StyLua

# Format and lint
make format
make lint
make check
```

### Running Tests

```bash
# Run all checks
make ci

# Development workflow
make dev
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Neovim team** for the excellent vim.pack foundation
- **lazy.nvim** for lazy loading inspiration  
- **packer.nvim** for plugin management concepts
- The **Neovim community** for feedback and contributions

## 📚 See Also

- [`:help pack-manager`](doc/pack-manager.txt) - Comprehensive help documentation
- [Neovim vim.pack documentation](https://neovim.io/doc/user/repeat.html#packages)
- [Plugin development guide](https://github.com/nanotee/nvim-lua-guide)

---

<div align="center">

**[⬆ Back to Top](#-pack-managernvim)**

Made with ❤️ for the Neovim community

</div>
