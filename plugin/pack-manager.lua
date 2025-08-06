-- Auto-loaded plugin setup file
if vim.g.loaded_pack_manager then
	return
end
vim.g.loaded_pack_manager = 1

-- Set up default user commands immediately
vim.api.nvim_create_user_command("Pack", function(opts)
	local subcommand = opts.fargs[1]
	local pack_manager = require("pack-manager")

	if subcommand == "status" then
		pack_manager.status()
	elseif subcommand == "update" then
		pack_manager.update()
	elseif subcommand == "install" then
		pack_manager.install_missing()
	elseif subcommand == "sync" then
		pack_manager.sync()
	elseif subcommand == "clean" then
		pack_manager.clean()
	else
		print("Available commands: status, update, install, sync, clean")
	end
end, {
	nargs = "+",
	complete = function()
		return { "status", "update", "install", "sync", "clean" }
	end,
	desc = "Pack-Manager commands",
})
