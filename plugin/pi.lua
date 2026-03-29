vim.api.nvim_create_user_command("PiAsk", function()
	require("pi").ask()
end, {})

vim.api.nvim_create_user_command("PiToggle", function()
	require("pi").toggle()
end, {})

vim.api.nvim_create_user_command("PiStop", function()
	require("pi").stop()
end, {})

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		require("pi").stop()
	end,
})
