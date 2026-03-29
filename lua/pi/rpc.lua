local M = {}
local config = require("pi.config")

-- State
local job_id = nil
local stdout_buffer = ""
local listeners = {}

-- Parse complete JSONL lines and dispatch to listners
local function process_line(line)
	if line == "" then
		return
	end
	local ok, event = pcall(vim.json.decode, line)
	if not ok then
		return
	end
	for _, cb in ipairs(listeners) do
		cb(event)
	end
end

function M.start()
	if job_id then
		return
	end

	local cmd = { config.options.pi.bin, "--mode", "rpc", "--no-session" }
	for _, arg in ipairs(config.options.pi.extra_args) do
		table.insert(cmd, arg)
	end
	stdout_buffer = ""

	job_id = vim.fn.jobstart(cmd, {
		--JSONL buffering: data[1] continues previous partial line,
		--data[2..n] are new lines (last is usually "" after trailing \n)
		on_stdout = function(_, data, _)
			stdout_buffer = stdout_buffer .. data[1]
			for i = 2, #data do
				process_line(stdout_buffer)
				stdout_buffer = data[i]
			end
		end,

		on_exit = function(_, exit_code, _)
			job_id = nil
			stdout_buffer = ""
		end,
	})
end

function M.send(cmd_obj)
	if not job_id then
		return
	end
	local json = vim.json.encode(cmd_obj)
	vim.fn.chansend(job_id, json .. "\n")
end

function M.stop()
	if not job_id then
		return
	end
	vim.fn.jobstop(job_id)
	job_id = nil
	stdout_buffer = ""
end

-- Register even listner. Returns a function to unsubscribe.

function M.on_event(callback)
	table.insert(listeners, callback)
	return function()
		for i, cb in ipairs(listeners) do
			if cb == callback then
				table.remove(listeners, i)
				break
			end
		end
	end
end

return M
