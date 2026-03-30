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

-- Reload buffers changed on disk by pi
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "CursorHold" }, {
	command = "silent! checktime",
})
