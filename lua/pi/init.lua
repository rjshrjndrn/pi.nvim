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

function M.quick_action(action)
	local prompt = type(action.prompt) == "function" and action.prompt() or action.prompt
	if not prompt or prompt == "" then
		vim.notify("pi: nothing to send (empty prompt)", vim.log.levels.WARN)
		return
	end

	if action.cmd then
		-- Oneshot: user-defined command, plugin runs it and shows output in a popup
		local cmd = type(action.cmd) == "function" and action.cmd(prompt) or action.cmd
		local lines = {}
		vim.fn.jobstart(cmd, {
			cwd = vim.fn.getcwd(),
			stdout_buffered = true,
			on_stdout = function(_, data)
				if data then
					vim.list_extend(lines, data)
				end
			end,
			on_exit = function(_, code)
				if code ~= 0 then
					vim.notify("pi: command exited with code " .. code, vim.log.levels.WARN)
				end
				vim.schedule(function()
					ui.popup(lines)
				end)
			end,
		})
		return
	end

	-- TUI flow via backend
	local backend
	if action.backend then
		backend = backends.resolve(action.backend, action.backend_opts or {})
	else
		backend = config.get_backend()
	end

	local already_running = ui.open(prompt, backend)
	if already_running then
		ui.send(prompt)
	end
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

	for _, action in ipairs(config.options.quick_actions or {}) do
		vim.keymap.set("n", action.keymap, function()
			M.quick_action(action)
		end, { desc = action.desc or "Pi quick action" })
	end

	local ok, wk = pcall(require, "which-key")
	if ok and config.options.keymaps.prefix then
		wk.add({ { config.options.keymaps.prefix, group = "pi" } })
	end
end

return M
