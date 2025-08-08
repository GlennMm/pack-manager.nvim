-- Plugin registry and state
local M = {}
local plugins = {}
local config = {}
local loading_plugins = {}

-- Default configuration
local default_config = {
	auto_install = true,
	auto_update = true,
	show_progress = true,
	parallel_install = true,
	git_timeout = 60,
	log_level = vim.log.levels.INFO,
	hooks = {
		pre_install = nil,
		post_install = nil,
		pre_update = nil,
		post_update = nil,
		pre_load = nil,
		post_load = nil,
	},
	ui = {
		icons = {
			loaded = "●",
			not_loaded = "○",
			installed = "✓",
			error = "✗",
			pending = "⏳",
			update = "↑",
		},
	},
}

-- Utility functions
local function notify(msg, level)
	if config.show_progress then
		-- vim.notify("[PackManager] " .. msg, level or config.log_level)
	end
end

local function get_plugin_name(spec)
	if spec.name then
		return spec.name
	end

	local name = spec.src:match("([^/]+)$"):gsub("%.git$", "")
	-- Handle common plugin naming patterns
	name = name:gsub("%.nvim$", ""):gsub("^nvim%-", "")
	return name
end

local function parse_plugin_spec(spec)
	if type(spec) == "string" then
		return { src = spec }
	elseif type(spec) == "table" then
		if not spec.src and not spec[1] then
			error("Plugin spec must have 'src' field or be a URL string: " .. vim.inspect(spec))
		end

		-- Handle array-style specs: { "user/repo", config = ... }
		if spec[1] and not spec.src then
			spec.src = spec[1]
			spec[1] = nil
		end

		return spec
	else
		error("Invalid plugin spec type: " .. type(spec))
	end
end

local function normalize_github_url(src)
	-- Convert GitHub shorthand to full URL
	if src:match("^[%w-_%.]+/[%w-_%.]+$") and not src:match("://") then
		return "https://github.com/" .. src
	end
	return src
end

local function normalize_specs(user_specs)
	local normalized = {}

	for _, spec in ipairs(user_specs) do
		local parsed = parse_plugin_spec(spec)
		parsed.src = normalize_github_url(parsed.src)

		local name = get_plugin_name(parsed)

		-- Create vim.pack compatible spec
		local vim_pack_spec = {
			src = parsed.src,
			name = parsed.name, -- Keep explicit name if provided
			version = parsed.version,
		}

		-- Store metadata separately
		local metadata = {
			dependencies = parsed.dependencies or parsed.requires or {},
			config = parsed.config,
			setup = parsed.setup,
			lazy = parsed.lazy or false,
			event = parsed.event,
			cmd = parsed.cmd,
			ft = parsed.ft,
			keys = parsed.keys,
			keymaps = parsed.keymaps,
			enabled = parsed.enabled ~= false,
			priority = parsed.priority or 50,
			build = parsed.build or parsed.run,
		}

		table.insert(normalized, vim_pack_spec)
		plugins[name] = {
			spec = vim_pack_spec,
			metadata = metadata,
			loaded = false,
			configured = false,
		}
	end

	return normalized
end

-- Dependency resolution
local function resolve_dependencies()
	local resolved = {}
	local visited = {}
	local visiting = {}

	local function visit(name)
		if visiting[name] then
			error("Circular dependency detected involving: " .. name)
		end
		if visited[name] then
			return
		end

		visiting[name] = true

		local plugin = plugins[name]
		if plugin and plugin.metadata.dependencies then
			for _, dep in ipairs(plugin.metadata.dependencies) do
				local dep_name = type(dep) == "string" and get_plugin_name({ src = dep }) or get_plugin_name(dep)
				if plugins[dep_name] then
					visit(dep_name)
				end
			end
		end

		visiting[name] = nil
		visited[name] = true
		table.insert(resolved, name)
	end

	-- Sort by priority first
	local plugin_names = {}
	for name, plugin in pairs(plugins) do
		if plugin.metadata.enabled then
			table.insert(plugin_names, { name = name, priority = plugin.metadata.priority })
		end
	end

	table.sort(plugin_names, function(a, b)
		return a.priority > b.priority
	end)

	for _, item in ipairs(plugin_names) do
		visit(item.name)
	end

	return resolved
end

-- Lazy loading setup
local function setup_lazy_keymaps(name, keys)
	local keymaps = type(keys) == "table" and keys[1] and keys or { keys }

	for _, keymap in ipairs(keymaps) do
		if type(keymap) == "string" then
			vim.keymap.set("n", keymap, function()
				-- Remove the temporary keymap first
				vim.keymap.del("n", keymap)
				M.load_plugin(name)
				-- Schedule the key re-trigger to happen after plugin configuration
				vim.schedule(function()
					vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keymap, true, false, true), "n", false)
				end)
			end, { desc = "Load " .. name })
		elseif type(keymap) == "table" then
			local key = keymap[1] or keymap.key
			local cmd = keymap[2] or keymap.cmd
			local mode = keymap.mode or "n"
			local opts = vim.tbl_extend("force", {
				desc = keymap.desc or ("Load " .. name),
				silent = keymap.silent ~= false,
			}, keymap.opts or {})

			vim.keymap.set(mode, key, function()
				-- Remove the temporary keymap first
				vim.keymap.del(mode, key)
				M.load_plugin(name)
				if type(cmd) == "string" then
					-- Schedule command execution after plugin loads
					vim.schedule(function()
						vim.cmd(cmd)
					end)
				elseif type(cmd) == "function" then
					-- Schedule function execution after plugin loads
					vim.schedule(function()
						cmd()
					end)
				else
					-- Schedule key feeding after plugin loads
					vim.schedule(function()
						vim.api.nvim_feedkeys(
							vim.api.nvim_replace_termcodes(key, true, false, true),
							mode == "n" and "n" or "m",
							false
						)
					end)
				end
			end, opts)
		end
	end
end

local function setup_lazy_commands(name, commands)
	local cmds = type(commands) == "table" and commands or { commands }

	for _, cmd in ipairs(cmds) do
		vim.api.nvim_create_user_command(cmd, function(opts)
			M.load_plugin(name)
			vim.cmd(cmd .. " " .. (opts.args or ""))
		end, { nargs = "*", desc = "Load " .. name })
	end
end

local function setup_lazy_events(name, events)
	local event_list = type(events) == "table" and events or { events }

	-- Convert lazy.nvim events to real Neovim events
	local converted_events = {}
	for _, event in ipairs(event_list) do
		if event == "VeryLazy" then
			-- VeryLazy -> load after UI is ready
			table.insert(converted_events, "User")
			vim.api.nvim_create_autocmd("UIEnter", {
				callback = function()
					vim.schedule(function()
						M.load_plugin(name)
					end)
				end,
				once = true,
				desc = "Load " .. name .. " (VeryLazy)",
			})
		else
			table.insert(converted_events, event)
		end
	end

	-- Only create autocmd if we have real events
	if #converted_events > 0 and not vim.tbl_contains(converted_events, "User") then
		vim.api.nvim_create_autocmd(converted_events, {
			callback = function()
				M.load_plugin(name)
			end,
			once = true,
			desc = "Load " .. name,
		})
	end
end

local function setup_lazy_filetypes(name, filetypes)
	local ft_list = type(filetypes) == "table" and filetypes or { filetypes }

	vim.api.nvim_create_autocmd("FileType", {
		pattern = ft_list,
		callback = function()
			M.load_plugin(name)
		end,
		once = true,
		desc = "Load " .. name,
	})
end

local function setup_lazy_loading()
	for name, plugin in pairs(plugins) do
		local meta = plugin.metadata

		if meta.lazy and meta.enabled then
			if meta.event then
				setup_lazy_events(name, meta.event)
			end

			if meta.cmd then
				setup_lazy_commands(name, meta.cmd)
			end

			if meta.ft then
				setup_lazy_filetypes(name, meta.ft)
			end

			if meta.keys then
				setup_lazy_keymaps(name, meta.keys)
			end
		end
	end
end

-- Plugin configuration
local function setup_keymaps(name)
	local plugin = plugins[name]
	if not plugin or not plugin.metadata.keymaps then
		return
	end

	local keymaps = plugin.metadata.keymaps
	for _, keymap in ipairs(keymaps) do
		local key = keymap[1] or keymap.key
		local cmd = keymap[2] or keymap.cmd
		local mode = keymap.mode or "n"
		local opts = vim.tbl_extend("force", {
			desc = keymap.desc,
			silent = keymap.silent ~= false,
			buffer = keymap.buffer,
		}, keymap.opts or {})

		vim.keymap.set(mode, key, cmd, opts)
	end
end

local function run_build_command(name, build_cmd)
	if not build_cmd then
		return
	end

	local plugin = plugins[name]
	if not plugin then
		return
	end

	local plugin_path = vim.fn.stdpath("data") .. "/site/pack/core/opt/" .. name

	if type(build_cmd) == "string" then
		if build_cmd:match("^:") then
			-- Vim command
			vim.cmd(build_cmd:sub(2))
		else
			-- Shell command
			vim.fn.system("cd " .. plugin_path .. " && " .. build_cmd)
		end
	elseif type(build_cmd) == "function" then
		build_cmd()
	end
end

function M.configure_plugin(name)
	local plugin = plugins[name]
	if not plugin or plugin.configured then
		return
	end

	local meta = plugin.metadata

	-- Call pre-load hook
	if config.hooks.pre_load then
		config.hooks.pre_load(name, plugin)
	end

	local ok, err = pcall(function()
		-- Run build command
		if meta.build then
			run_build_command(name, meta.build)
		end

		-- Setup plugin with config
		if meta.setup then
			local setup_config = meta.setup
			if type(setup_config) == "table" or setup_config == true then
				local module_ok, mod = pcall(require, name)
				if module_ok and mod and mod.setup then
					mod.setup(type(setup_config) == "table" and setup_config or {})
				end
			elseif type(setup_config) == "function" then
				setup_config()
			end
		end

		-- Run config function
		if meta.config and type(meta.config) == "function" then
			meta.config()
		end

		-- Setup keymaps
		setup_keymaps(name)

		plugin.configured = true
	end)

	if not ok then
		notify("Failed to configure " .. name .. ": " .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	-- Call post-load hook
	if config.hooks.post_load then
		config.hooks.post_load(name, plugin)
	end

	local config_type = meta.setup and " with setup" or (meta.config and " with config" or " default")
	-- notify("✓ Configured " .. name .. config_type)
	return true
end

-- Main functions
function M.setup(user_config)
	config = vim.tbl_deep_extend("force", default_config, user_config or {})

	-- Setup autocmds for hooks if provided
	local hook_events = {
		{ "PackChangedPre", "install", config.hooks.pre_install },
		{ "PackChanged", "install", config.hooks.post_install },
		{ "PackChangedPre", "update", config.hooks.pre_update },
		{ "PackChanged", "update", config.hooks.post_update },
	}

	for _, hook in ipairs(hook_events) do
		local event, kind, callback = hook[1], hook[2], hook[3]
		if callback then
			vim.api.nvim_create_autocmd(event, {
				callback = function(args)
					if args.data and args.data.kind == kind then
						callback(args.data)
					end
				end,
			})
		end
	end

	-- Create user commands
	vim.api.nvim_create_user_command("PackInstall", function(opts)
		if opts.args and opts.args ~= "" then
			M.install_plugin(opts.args)
		else
			M.install_missing()
		end
	end, { nargs = "?", desc = "Install plugin(s)" })

	vim.api.nvim_create_user_command("PackUpdate", function(opts)
		local names = opts.args ~= "" and vim.split(opts.args, "%s+") or nil
		M.update(names)
	end, { nargs = "*", desc = "Update plugin(s)" })

	vim.api.nvim_create_user_command("PackStatus", function()
		M.status()
	end, { desc = "Show plugin status" })

	vim.api.nvim_create_user_command("PackClean", function()
		M.clean()
	end, { desc = "Remove unused plugins" })

	vim.api.nvim_create_user_command("PackSync", function()
		M.sync()
	end, { desc = "Install missing and update all" })

end

function M.add(user_specs, opts)
	opts = opts or {}
	local load_plugins = opts.load ~= false

	-- notify("Processing " .. #user_specs .. " plugin specifications...")

	local specs = normalize_specs(user_specs)

	-- Install plugins via vim.pack
	-- notify("Installing/loading plugins via vim.pack...")
	vim.pack.add(specs, { load = load_plugins })

	-- Resolve load order
	local load_order = resolve_dependencies()

	-- Setup lazy loading for all plugins first
	setup_lazy_loading()

	-- Configure non-lazy plugins in dependency order
	-- notify("Configuring plugins...")
	for _, name in ipairs(load_order) do
		local plugin = plugins[name]
		if plugin and plugin.metadata.enabled and not plugin.metadata.lazy then
			M.configure_plugin(name)
			plugin.loaded = true
		end
	end

end

function M.load_plugin(name)
	if loading_plugins[name] then
		return -- Prevent infinite loops
	end

	local plugin = plugins[name]
	if not plugin then
		notify("Plugin not found: " .. name, vim.log.levels.WARN)
		return false
	end

	if plugin.loaded then
		return true
	end

	loading_plugins[name] = true

	-- Load dependencies first
	for _, dep in ipairs(plugin.metadata.dependencies or {}) do
		local dep_name = type(dep) == "string" and get_plugin_name({ src = dep }) or get_plugin_name(dep)
		M.load_plugin(dep_name)
	end

	-- Load the plugin
	local spec_name = plugin.spec.name or name
	vim.cmd("packadd " .. spec_name)

	-- Configure it
	M.configure_plugin(name)
	plugin.loaded = true

	loading_plugins[name] = nil
	notify("Loaded " .. name)
	return true
end

function M.update(names, opts)
	opts = opts or {}

	if config.hooks.pre_update then
		config.hooks.pre_update(names)
	end

	notify("Updating plugins...")
	vim.pack.update(names, opts)

	if config.hooks.post_update then
		config.hooks.post_update(names)
	end
end

function M.install_missing()
	local vim_pack_plugins = vim.pack.get()
	local existing = {}

	for _, p in ipairs(vim_pack_plugins) do
		local name = get_plugin_name(p.spec)
		existing[name] = true
	end

	local missing = {}
	for name, plugin in pairs(plugins) do
		if plugin.metadata.enabled and not existing[name] then
			table.insert(missing, plugin.spec)
		end
	end

	if #missing > 0 then
		notify("Installing " .. #missing .. " missing plugins...")
		vim.pack.add(missing)
	else
		notify("No missing plugins")
	end
end

-- Alias for compatibility  
M.install = M.install_missing

function M.sync()
	M.install_missing()
	M.update()
end

function M.status()
	local vim_pack_plugins = vim.pack.get()
	local icons = config.ui.icons

	print("PackManager Status")
	print("==================")
	print(string.format("Plugins managed: %d", vim.tbl_count(plugins)))
	print(string.format("Plugins on disk: %d", #vim_pack_plugins))
	print()

	-- Group plugins by status
	local loaded, not_loaded, disabled = {}, {}, {}

	for name, plugin in pairs(plugins) do
		if not plugin.metadata.enabled then
			table.insert(disabled, name)
		elseif plugin.loaded then
			table.insert(loaded, name)
		else
			table.insert(not_loaded, name)
		end
	end

	local function print_group(title, list, icon)
		if #list > 0 then
			print(title .. " (" .. #list .. "):")
			table.sort(list)
			for _, name in ipairs(list) do
				print("  " .. icon .. " " .. name)
			end
			print()
		end
	end

	print_group("Loaded", loaded, icons.loaded)
	print_group("Not Loaded", not_loaded, icons.not_loaded)
	print_group("Disabled", disabled, icons.error)
end

function M.clean()
	local vim_pack_plugins = vim.pack.get()
	local to_remove = {}

	for _, p in ipairs(vim_pack_plugins) do
		local name = get_plugin_name(p.spec)
		if not plugins[name] or not plugins[name].metadata.enabled then
			table.insert(to_remove, name)
		end
	end

	if #to_remove > 0 then
		notify("Removing " .. #to_remove .. " unused plugins...")
		vim.pack.del(to_remove)
	else
		notify("No plugins to clean")
	end
end

function M.get_plugins()
	return plugins
end


-- UI Integration
function M.ui()
	local success, ui = pcall(require, 'pack-manager.ui')
	if not success then
		print("Error loading UI module: " .. ui)
		return
	end
	
	local ok, err = pcall(ui.open)
	if not ok then
		print("Error opening UI: " .. err)
	end
end

-- Pack command is defined in plugin/pack-manager.lua to avoid loading issues

-- Dashboard shortcut compatibility
vim.api.nvim_create_user_command('PackUpdate', function() M.update() end, {})
vim.api.nvim_create_user_command('PackInstall', function() M.install() end, {})
vim.api.nvim_create_user_command('PackSync', function() M.sync() end, {})
vim.api.nvim_create_user_command('PackClean', function() M.clean() end, {})
vim.api.nvim_create_user_command('PackStatus', function() M.status() end, {})

-- Compatibility with other plugin managers
M.lazy = M.add
M.packer = M.add

return M
