local M = {}
local config = require("pi.config")
local backends = require("pi.backends")
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

	-- Use vim.fn.input() directly instead of vim.ui.input() so that
	-- Neovim's native '@' (input) history is available.  Arrow-up / down
	-- recalls previously typed queries, and the history persists across
	-- sessions via shada.  vim.ui.input() is often overridden by plugins
	-- (snacks.nvim, dressing.nvim) whose floating-window replacements
	-- maintain their own in-memory history that may not behave the same.
	local ok, question = pcall(vim.fn.input, { prompt = "Ask pi: ", cancelreturn = vim.NIL })
	if not ok or question == vim.NIL or question == "" then
		return
	end
	local prompt = context.format_prompt(backend, ctx, question)
	local cwd = context.resolve_cwd(ctx.file)

	-- Always send via ui.send() so the prompt flows through the TUI's
	-- input field and appears in its command history (arrow-up recall).
	-- For a fresh start the TUI needs time to initialize first.
	ui.open(nil, backend, cwd)
	ui.send(prompt)
	ui.focus()
end

function M.quick_action(action)
	local prompt = type(action.prompt) == "function" and action.prompt() or action.prompt
	if not prompt or prompt == "" then
		vim.notify("pi: nothing to send (empty prompt)", vim.log.levels.WARN)
		return
	end

	if action.cmd then
		-- Oneshot: user-defined command, plugin runs it and shows output in a popup
		local cmd = type(action.cmd) == "function" and action.cmd(prompt) or action.cmd

		vim.notify("pi: running...", vim.log.levels.INFO)

		vim.system(cmd, { cwd = vim.fn.getcwd(), text = true }, function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					local msg = (result.stderr ~= "" and result.stderr) or ("exited with code " .. result.code)
					vim.notify("pi: " .. msg, vim.log.levels.ERROR)
					return
				end
				local lines = vim.split(result.stdout or "", "\n", { plain = true })
				ui.popup(lines)
			end)
		end)
		return
	end

	-- TUI flow via backend
	local backend
	if action.backend then
		backend = backends.resolve(action.backend, action.backend_opts or {})
	else
		backend = config.get_backend()
	end

	local cwd = context.resolve_cwd(vim.api.nvim_buf_get_name(0))
	ui.open(nil, backend, cwd)
	ui.send(prompt)
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

	vim.keymap.set("n", config.options.keymaps.expand, function()
		ui.toggle_maximize()
	end, { desc = "Expand/restore pi panel" })

	for _, action in ipairs(config.options.quick_actions or {}) do
		vim.keymap.set("n", action.keymap, function()
			M.quick_action(action)
		end, { desc = action.desc or "Pi quick action" })
	end

	vim.schedule(function()
		local ok, wk = pcall(require, "which-key")
		if ok and config.options.keymaps.prefix then
			wk.add({ { config.options.keymaps.prefix, group = "pi" } })
		end
	end)
end

return M
