local M = {}
local config = require("pi.config")
local rpc = require("pi.rpc")
local ui = require("pi.ui")
local context = require("pi.context")

local listening = false

local function start_listening()
	if listening then
		return
	end
	listening = true

	rpc.on_event(function(event)
		vim.schedule(function()
			local t = event.type
			if t == "message_update" then
				local delta = event.assistantMessageEvent
				if delta and delta.type == "text_delta" then
					ui.append_delta(delta.delta)
				end
			elseif t == "message_start" then
				ui.start_response()
			elseif t == "tool_execution_start" then
				ui.append_tool(event.toolName, event.args)
			elseif t == "agent_end" then
				ui.end_response()
			end
		end)
	end)
end

function M.ask(opts)
	opts = opts or {}
	local ctx

	-- Capture context before any async UI
	if opts.visual then
		ctx = context.get_visual_selection()
	else
		ctx = context.get_buffer_info()
	end
	vim.ui.input({ prompt = "Ask pi: " }, function(question)
		if not question or question == "" then
			return
		end
		local prompt = context.format_prompt(ctx, question)

		-- Lazy start
		rpc.start()
		start_listening()
		ui.open()

		-- Show user message in panel
		ui.append_user(prompt)

		-- Send to pi
		rpc.send({ type = "prompt", message = prompt })
	end)
end

function M.toggle()
	ui.toggle()
end

function M.stop()
	rpc.stop()
	ui.close()
	listening = false
end

function M.setup(opts)
	config.setup(opts)

	-- Keymaps
	vim.keymap.set("n", config.options.keymaps.ask, function()
		M.ask()
	end, { desc = "Ask pi" })
	vim.keymap.set("x", config.options.keymaps.ask, function()
		-- Exit visual mode first so '< '> marks are set
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
		M.ask({ visual = true })
	end, { desc = "Ask pi about selection" })
	vim.keymap.set("n", config.options.keymaps.toggle, function()
		M.toggle()
	end, { desc = "Toggle pi panel" })
end

return M
