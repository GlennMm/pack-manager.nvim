-- Luacheck configuration for Pack-Manager.nvim

-- Lua version
std = "luajit"

-- Global variables
globals = {
  -- Vim globals
  "vim",
  
  -- Test globals (if you add tests later)
  "describe",
  "it",
  "before_each",
  "after_each",
  "setup", 
  "teardown",
  "assert",
  "stub",
  "mock",
}

-- Read globals (allowed to be read but not set)
read_globals = {
  "vim",
}

-- Ignore certain warnings
ignore = {
  "212", -- Unused argument (common in callbacks)
  "213", -- Unused loop variable  
  "631", -- Line is too long (handled by stylua)
}

-- File-specific configurations
files = {
  ["lua/pack-manager/init.lua"] = {
    ignore = {
      "212", -- Unused arguments in plugin specs
    }
  },
  
  ["plugin/pack-manager.lua"] = {
    ignore = {
      "111", -- Setting non-standard global variable (vim.g.loaded_pack_manager)
    }
  },
  
  -- Test files (if you add them)
  ["tests/"] = {
    std = "+busted",
    globals = {
      "describe",
      "it", 
      "before_each",
      "after_each",
      "setup",
      "teardown",
      "assert",
      "stub", 
      "mock",
    }
  }
}

-- Maximum line length (sync with stylua)
max_line_length = 100

-- Exclude certain patterns
exclude_files = {
  "*.min.lua",
  "**/vendor/**",
  "**/node_modules/**",
}

-- Allow unused self
unused_secondaries = false

-- Allow unused arguments starting with underscore
unused = false
