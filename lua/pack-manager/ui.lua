local M = {}

-- Dependencies
local api = vim.api
local fn = vim.fn

-- UI Configuration
M.config = {
  size = { width = 0.8, height = 0.8 },
  border = "rounded",
  backdrop = 60, -- transparency
  keymaps = {
    close = "q",
    install = "I",
    update = "U",
    sync = "S",
    clean = "X",
    check = "C",
    restore = "R",
    profile = "P",
    debug = "D",
    help = "?",
    details = "<CR>",
    next_plugin = "]]",
    prev_plugin = "[[",
    hover = "K",
    logs = "L",
  },
  icons = {
    loaded = "●",
    not_loaded = "○", 
    installed = "✓",
    not_installed = "✗",
    update_available = "↑",
    pending = "⏳",
    error = "✗",
    warning = "⚠",
    info = "ⓘ",
  }
}

-- UI State
local ui_state = {
  buf = nil,
  win = nil,
  mode = "home", -- home, profile, debug, help
  selected = 1,
  expanded = {},
  cursor_plugin = nil,
  plugins_data = {},
}

-- Progress tracking
local progress_state = {
  active = false,
  current = 0,
  total = 0,
  message = "",
}

-- Highlight groups
local highlights = {
  PackManagerH1 = { fg = "#ff9e64", bold = true },
  PackManagerH2 = { fg = "#7aa2f7", bold = true },
  PackManagerComment = { fg = "#565f89" },
  PackManagerSpecial = { fg = "#bb9af7" },
  PackManagerButton = { bg = "#3b4261" },
  PackManagerButtonActive = { bg = "#7aa2f7", fg = "#1a1b26" },
  PackManagerProgressDone = { fg = "#9ece6a" },
  PackManagerProgressTodo = { fg = "#565f89" },
  PackManagerLoaded = { fg = "#9ece6a" },
  PackManagerNotLoaded = { fg = "#565f89" },
  PackManagerError = { fg = "#f7768e" },
  PackManagerWarning = { fg = "#e0af68" },
  PackManagerInfo = { fg = "#7dcfff" },
}

-- Initialize highlight groups
local function setup_highlights()
  for name, opts in pairs(highlights) do
    api.nvim_set_hl(0, name, opts)
  end
end

-- Calculate window dimensions
local function get_win_config()
  local width = math.floor(vim.o.columns * M.config.size.width)
  local height = math.floor(vim.o.lines * M.config.size.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = M.config.border,
    style = "minimal",
    zindex = 50,
  }
end

-- Create floating window
local function create_window()
  if ui_state.win and api.nvim_win_is_valid(ui_state.win) then
    api.nvim_win_close(ui_state.win, true)
  end
  
  if ui_state.buf and api.nvim_buf_is_valid(ui_state.buf) then
    api.nvim_buf_delete(ui_state.buf, { force = true })
  end
  
  ui_state.buf = api.nvim_create_buf(false, true)
  ui_state.win = api.nvim_open_win(ui_state.buf, true, get_win_config())
  
  -- Buffer options
  api.nvim_buf_set_option(ui_state.buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(ui_state.buf, "filetype", "packmanager")
  api.nvim_buf_set_option(ui_state.buf, "buftype", "nofile")
  api.nvim_buf_set_option(ui_state.buf, "modifiable", true)
  api.nvim_buf_set_option(ui_state.buf, "readonly", false)
  
  -- Window options
  api.nvim_win_set_option(ui_state.win, "wrap", false)
  api.nvim_win_set_option(ui_state.win, "cursorline", true)
  api.nvim_win_set_option(ui_state.win, "number", false)
  api.nvim_win_set_option(ui_state.win, "relativenumber", false)
  api.nvim_win_set_option(ui_state.win, "signcolumn", "no")
  api.nvim_win_set_option(ui_state.win, "foldcolumn", "0")
  
  return ui_state.buf, ui_state.win
end

-- Progress bar rendering
local function render_progress_bar(width)
  if not progress_state or not progress_state.active or progress_state.total == 0 then
    return ""
  end
  
  local bar_width = width - 4 -- account for brackets and spaces
  local completed = math.floor((progress_state.current / progress_state.total) * bar_width)
  local remaining = bar_width - completed
  
  local bar = "["
  bar = bar .. string.rep("═", completed)
  bar = bar .. string.rep("─", remaining)
  bar = bar .. "]"
  
  return bar
end

-- Header with action buttons
local function render_header()
  local actions = {
    { key = "I", name = "Install", desc = "Install missing plugins" },
    { key = "U", name = "Update", desc = "Update all plugins" },
    { key = "?", name = "Help", desc = "Show help" },
  }
  
  local header_lines = {}
  
  -- Title
  table.insert(header_lines, "")
  table.insert(header_lines, "  📦 Pack Manager")
  table.insert(header_lines, "")
  
  -- Action buttons
  local buttons = "  "
  for i, action in ipairs(actions) do
    buttons = buttons .. "[" .. action.key .. "] " .. action.name
    if i < #actions then
      buttons = buttons .. "   "
    end
  end
  table.insert(header_lines, buttons)
  table.insert(header_lines, "")
  
  -- Progress bar
  if progress_state and progress_state.active then
    local win_width = api.nvim_win_get_width(ui_state.win or 0)
    local progress_bar = render_progress_bar(win_width - 4)
    table.insert(header_lines, "  " .. progress_bar)
    
    if progress_state.message ~= "" then
      table.insert(header_lines, "  " .. progress_state.message)
    end
    table.insert(header_lines, "")
  end
  
  return header_lines
end

-- Plugin sections based on status
local function get_plugin_sections()
  local pack_manager = require('pack-manager')
  local plugins = pack_manager.get_plugins()
  
  local sections = {
    { name = "Loaded", plugins = {} },
    { name = "Not Loaded", plugins = {} },
    { name = "Updates Available", plugins = {} },
    { name = "Not Installed", plugins = {} },
    { name = "Errors", plugins = {} },
  }
  
  for name, plugin in pairs(plugins) do
    local plugin_data = {
      name = name,
      loaded = plugin.loaded or false,
      spec = plugin.spec,
      status = plugin.status or "unknown",
      error = plugin.error,
    }
    
    if plugin_data.error then
      table.insert(sections[5].plugins, plugin_data)
    elseif plugin_data.loaded then
      table.insert(sections[1].plugins, plugin_data)
    else
      table.insert(sections[2].plugins, plugin_data)
    end
  end
  
  return sections
end

-- Render plugin entry
local function render_plugin(plugin, is_expanded)
  local lines = {}
  local icon = plugin.loaded and M.config.icons.loaded or M.config.icons.not_loaded
  local status_color = plugin.loaded and "PackManagerLoaded" or "PackManagerNotLoaded"
  
  if plugin.error then
    icon = M.config.icons.error
    status_color = "PackManagerError"
  end
  
  local main_line = string.format("  %s %s", icon, plugin.name)
  
  -- Add lazy loading reasons
  if plugin.spec.event then
    main_line = main_line .. "  event"
  end
  if plugin.spec.keys then
    main_line = main_line .. "  keys"
  end
  if plugin.spec.cmd then
    main_line = main_line .. "  cmd"
  end
  if plugin.spec.ft then
    main_line = main_line .. "  ft"
  end
  
  table.insert(lines, main_line)
  
  -- Expanded details
  if is_expanded then
    if plugin.spec.src then
      table.insert(lines, "      ├─ url: " .. plugin.spec.src)
    end
    if plugin.spec.lazy ~= nil then
      table.insert(lines, "      ├─ lazy: " .. tostring(plugin.spec.lazy))
    end
    if plugin.error then
      table.insert(lines, "      └─ error: " .. plugin.error)
    else
      table.insert(lines, "      └─ status: " .. (plugin.status or "ok"))
    end
  end
  
  return lines
end

-- Render home view
local function render_home()
  local lines = {}
  local sections = get_plugin_sections()
  
  for _, section in ipairs(sections) do
    if #section.plugins > 0 then
      table.insert(lines, "")
      table.insert(lines, "▸ " .. section.name .. " (" .. #section.plugins .. ")")
      table.insert(lines, "")
      
      for _, plugin in ipairs(section.plugins) do
        local is_expanded = ui_state.expanded[plugin.name] or false
        local plugin_lines = render_plugin(plugin, is_expanded)
        for _, line in ipairs(plugin_lines) do
          table.insert(lines, line)
        end
      end
    end
  end
  
  return lines
end

-- Render help view
local function render_help()
  return {
    "",
    "Keyboard Shortcuts:",
    "",
    "  Navigation:",
    "    ]] / [[     Next/Previous plugin",
    "    <Enter>     Toggle plugin details",
    "",
    "  Management:",
    "    I           Install missing plugins",
    "    U           Update all plugins",
    "    X           Delete plugin at cursor (with confirmation)",
    "",
    "  General:",
    "    ?           This help",
    "    q           Close window",
    "",
    "  Plugin Operations:",
    "    - Navigate to a plugin using arrow keys or ]] / [[",
    "    - Press X on any plugin to delete it",
    "    - Press <Enter> to see plugin details",
    "",
  }
end

-- Render content based on current mode
local function render_content()
  if ui_state.mode == "help" then
    return render_help()
  else
    return render_home()
  end
end

-- Update buffer content
local function update_display()
  if not ui_state.buf or not api.nvim_buf_is_valid(ui_state.buf) then
    return
  end
  
  local lines = {}
  
  -- Add header
  for _, line in ipairs(render_header()) do
    table.insert(lines, line)
  end
  
  -- Add content
  for _, line in ipairs(render_content()) do
    table.insert(lines, line)
  end
  
  -- Update buffer
  api.nvim_buf_set_option(ui_state.buf, "modifiable", true)
  api.nvim_buf_set_lines(ui_state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(ui_state.buf, "modifiable", false)
end

-- Find plugin name at cursor
local function get_plugin_at_cursor()
  local line = api.nvim_get_current_line()
  -- Try different patterns to match plugin lines
  local plugin_name = line:match("  [●○✓✗⏳⚠ⓘ↑] (%S+)")
  if not plugin_name then
    -- More flexible pattern - any single character followed by space and plugin name
    plugin_name = line:match("  . (%S+)")
  end
  if not plugin_name then
    -- Even more flexible - look for pattern starting with spaces
    plugin_name = line:match("^  %S+ (%S+)")
  end
  
  -- Debug: print what we found
  if plugin_name then
    print("Found plugin: " .. plugin_name)
  else
    print("No plugin found in line: " .. line)
  end
  
  return plugin_name
end

-- Delete plugin with confirmation
local function delete_plugin()
  local plugin_name = get_plugin_at_cursor()
  if not plugin_name then
    print("No plugin found at cursor")
    return
  end
  
  -- Ask for confirmation
  local choice = vim.fn.confirm(
    "Delete plugin '" .. plugin_name .. "'?\nThis will:\n- Uninstall the plugin\n- Remove it from your config",
    "&Yes\n&No",
    2
  )
  
  if choice == 1 then -- Yes
    -- Close the UI temporarily
    local was_open = ui_state.win and api.nvim_win_is_valid(ui_state.win)
    if was_open then
      M.close()
    end
    
    -- Get pack manager and delete the plugin
    local pack_manager = require('pack-manager')
    local success, err = pcall(pack_manager.remove_plugin, plugin_name)
    
    if success then
      print("Plugin '" .. plugin_name .. "' deleted successfully")
    else
      print("Error deleting plugin '" .. plugin_name .. "': " .. (err or "unknown error"))
    end
    
    -- Reopen the UI if it was open
    if was_open then
      vim.schedule(function()
        M.open()
      end)
    end
  end
end

-- Toggle plugin details
local function toggle_details()
  local plugin_name = get_plugin_at_cursor()
  if plugin_name then
    ui_state.expanded[plugin_name] = not ui_state.expanded[plugin_name]
    update_display()
  end
end

-- Navigation functions
local function next_plugin()
  local lines = api.nvim_buf_get_lines(ui_state.buf, 0, -1, false)
  local current_line = api.nvim_win_get_cursor(ui_state.win)[1]
  
  for i = current_line + 1, #lines do
    if lines[i]:match("  [●○✓✗⏳] %S+") then
      api.nvim_win_set_cursor(ui_state.win, { i, 0 })
      return
    end
  end
end

local function prev_plugin()
  local lines = api.nvim_buf_get_lines(ui_state.buf, 0, -1, false)
  local current_line = api.nvim_win_get_cursor(ui_state.win)[1]
  
  for i = current_line - 1, 1, -1 do
    if lines[i]:match("  [●○✓✗⏳] %S+") then
      api.nvim_win_set_cursor(ui_state.win, { i, 0 })
      return
    end
  end
end

-- Progress notification callback
local function on_progress(current, total, message)
  if not progress_state then return end
  
  progress_state.active = total > 0
  progress_state.current = current or 0
  progress_state.total = total or 0
  progress_state.message = message or ""
  
  if ui_state.buf and api.nvim_buf_is_valid(ui_state.buf) then
    update_display()
  end
end

-- Action handlers
local function handle_install()
  local pack_manager = require('pack-manager')
  if progress_state then
    progress_state.active = true
    progress_state.message = "Installing plugins..."
    update_display()
  end
  
  vim.schedule(function()
    pack_manager.install()
    if progress_state then
      progress_state.active = false
      update_display()
    end
  end)
end

local function handle_update()
  local pack_manager = require('pack-manager')
  if progress_state then
    progress_state.active = true
    progress_state.message = "Updating plugins..."
    update_display()
  end
  
  vim.schedule(function()
    pack_manager.update()
    if progress_state then
      progress_state.active = false
      update_display()
    end
  end)
end

local function handle_sync()
  local pack_manager = require('pack-manager')
  if progress_state then
    progress_state.active = true
    progress_state.message = "Syncing plugins..."
    update_display()
  end
  
  vim.schedule(function()
    pack_manager.sync()
    if progress_state then
      progress_state.active = false
      update_display()
    end
  end)
end

local function handle_clean()
  local pack_manager = require('pack-manager')
  if progress_state then
    progress_state.active = true
    progress_state.message = "Cleaning plugins..."
    update_display()
  end
  
  vim.schedule(function()
    pack_manager.clean()
    if progress_state then
      progress_state.active = false
      update_display()
    end
  end)
end

-- Setup keymaps
local function setup_keymaps()
  local keymaps = {
    [M.config.keymaps.close] = function() M.close() end,
    [M.config.keymaps.install] = handle_install,
    [M.config.keymaps.update] = handle_update,
    [M.config.keymaps.details] = toggle_details,
    [M.config.keymaps.next_plugin] = next_plugin,
    [M.config.keymaps.prev_plugin] = prev_plugin,
    [M.config.keymaps.help] = function() ui_state.mode = "help"; update_display() end,
    ["X"] = delete_plugin, -- Add X key for deleting plugins
  }
  
  for key, func in pairs(keymaps) do
    api.nvim_buf_set_keymap(ui_state.buf, "n", key, "", {
      noremap = true,
      silent = true,
      callback = func,
    })
  end
  
end

-- Main functions
function M.open()
  setup_highlights()
  create_window()
  setup_keymaps()
  update_display()
end

function M.close()
  if ui_state.win and api.nvim_win_is_valid(ui_state.win) then
    api.nvim_win_close(ui_state.win, true)
  end
  ui_state.win = nil
  ui_state.buf = nil
end

function M.toggle()
  if ui_state.win and api.nvim_win_is_valid(ui_state.win) then
    M.close()
  else
    M.open()
  end
end

function M.refresh()
  if ui_state.buf and api.nvim_buf_is_valid(ui_state.buf) then
    update_display()
  end
end

return M