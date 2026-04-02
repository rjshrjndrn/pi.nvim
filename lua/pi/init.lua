local M = {}
local config = require("pi.config")
local ui = require("pi.ui")
local context = require("pi.context")

function M.ask(opts)
	opts = opts or {}
	local ctx
	local backend = config.get_backend()

	if opts.visual then
		ctx = context.get_visual_selection()
	else
		ctx = context.get_buffer_info()
	end

	vim.ui.input({ prompt = "Ask pi: " }, function(question)
		if not question or question == "" then
			return
		end
		local prompt = context.format_prompt(backend, ctx, question)

		local already_running = ui.open(prompt, backend)
		-- If backend was already running, send as follow-up
		if already_running then
			ui.send(prompt)
		end
		-- If fresh start, prompt was passed as CLI arg
	end)
end

function M.toggle()
	ui.toggle()
end

function M.stop()
	ui.stop()
end

function M.setup(opts)
	config.setup(opts)

	vim.keymap.set("n", config.options.keymaps.ask, function()
		M.ask()
	end, { desc = "Ask pi" })

	vim.keymap.set("x", config.options.keymaps.ask, function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
		M.ask({ visual = true })
	end, { desc = "Ask pi about selection" })

	vim.keymap.set("n", config.options.keymaps.toggle, function()
		M.toggle()
	end, { desc = "Toggle pi panel" })
end

return M
