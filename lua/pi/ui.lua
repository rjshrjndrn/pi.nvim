local M = {}
local config = require("pi.config")

local term_buf = nil
local term_win = nil
local term_job = nil

local function open_split(existing_buf)
	local width = math.floor(vim.o.columns * config.options.split.width)
	vim.cmd("botright vertical " .. width .. "split")
	if existing_buf then
		vim.api.nvim_set_current_buf(existing_buf)
	else
		local buf = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
		vim.api.nvim_set_current_buf(buf)
	end
	term_win = vim.api.nvim_get_current_win()
	vim.wo[term_win].number = false
	vim.wo[term_win].relativenumber = false
	vim.wo[term_win].signcolumn = "no"
end

function M.open(initial_prompt)
	-- If already running, just show the window
	if term_job and vim.fn.jobwait({ term_job }, 0)[1] == -1 then
		if not term_win or not vim.api.nvim_win_is_valid(term_win) then
			open_split(term_buf)
		end
		return true -- already running
	end

	-- Build command
	local cmd = { config.options.pi.bin }
	for _, arg in ipairs(config.options.pi.extra_args) do
		table.insert(cmd, arg)
	end
	if initial_prompt then
		table.insert(cmd, initial_prompt)
	end

	-- Open split and spawn pi TUI
	open_split()
	term_job = vim.fn.termopen(cmd, {
		cwd = vim.fn.getcwd(),
		on_exit = function()
			term_job = nil
			term_buf = nil
		end,
	})
	term_buf = vim.api.nvim_get_current_buf()
	vim.bo[term_buf].buflisted = false
	vim.api.nvim_buf_set_name(term_buf, "pi")
	vim.cmd("setlocal bufhidden=hide")

	-- Go back to code window
	vim.cmd("wincmd p")
	return false -- fresh start
end

function M.send(text)
	if term_job then
		vim.fn.chansend(term_job, text .. "\r")
	end
end

function M.close()
	if term_win and vim.api.nvim_win_is_valid(term_win) then
		vim.api.nvim_win_close(term_win, true)
	end
	term_win = nil
end

function M.toggle()
	if term_win and vim.api.nvim_win_is_valid(term_win) then
		M.close()
	else
		M.open()
	end
end

function M.stop()
	if term_job then
		vim.fn.jobstop(term_job)
	end
	M.close()
	term_job = nil
	term_buf = nil
end

function M.is_running()
	return term_job ~= nil
end

return M
