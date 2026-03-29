local M = {}
local config = require("pi.config")
local buf = nil
local win = nil

-- Create a chat buffer ( once, reused)
local function create_buf()
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return
	end
	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
end

function M.open()
	create_buf()
	if win and vim.api.nvim_win_is_valid(win) then
		return
	end
	local width = math.floor(vim.o.columns * config.options.split.width)
	vim.cmd("botright vertical " .. width .. "split")
	win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	-- Go back to previous window
	vim.cmd("wincmd p")
end

function M.close()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	win = nil
end

function M.toggle()
	if win and vim.api.nvim_win_is_valid(win) then
		M.close()
	else
		M.open()
	end
end

function M.is_open()
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

-- Append test to chat buffer
local function append(text)
	create_buf()
	vim.bo[buf].modifiable = true
	local lines = vim.split(text, "\n")
	local line_cout = vim.api.nvim_buf_line_count(buf)
	--If buffer is empty (single empty line), replace; otherwise append
	local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
	if line_cout == 1 and first_line == "" then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	else
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
	end
	vim.bo[buf].modifiable = false
	M.scroll_bottom()
end

function M.append_user(prompt_text)
	append("## You\n\n" .. prompt_text .. "\n\n---\n")
end

function M.start_response()
	append("\n## Pi\n\n")
end

-- Append streaming text delta (no newline prefix — continues current line)
function M.append_delta(text)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.bo[buf].modifiable = true

	local lines = vim.split(text, "\n", { plain = true })
	local line_count = vim.api.nvim_buf_line_count(buf)
	local last_line = vim.api.nvim_buf_get_lines(buf, line_count - 1, line_count, false)[1] or ""

	-- First chunk continues the last line
	lines[1] = last_line .. lines[1]
	vim.api.nvim_buf_set_lines(buf, line_count - 1, line_count, false, lines)

	vim.bo[buf].modifiable = false
	M.scroll_bottom()
end

function M.append_tool(tool_name, args)
	local info = "🔧 *" .. tool_name .. "*"
	if tool_name == "bash" and args and args.command then
		info = "🔧 *running:* `" .. args.command .. "`"
	elseif tool_name == "read" and args and args.path then
		info = "🔧 *reading:* `" .. args.path .. "`"
	elseif tool_name == "edit" and args and args.path then
		info = "🔧 *editing:* `" .. args.path .. "`"
	end
	append(info)
end

function M.end_response()
	append("\n\n---\n")
end

function M.scroll_bottom()
	if win and vim.api.nvim_win_is_valid(win) then
		local line_count = vim.api.nvim_buf_line_count(buf)
		vim.api.nvim_win_set_cursor(win, { line_count, 0 })
	end
end

return M

