--- RPC handlers for pi agent to control parent Neovim.
---
--- When pi runs inside a Neovim terminal, $NVIM points to the parent's
--- Unix socket.  Pi can call these handlers via:
---
---   nvim --server "$NVIM" --remote-expr "luaeval('PiRpc.open_at(\"file.lua\", 42)')"
---
--- All functions are registered on _G.PiRpc so they're accessible from
--- any RPC caller without requiring module paths.

local M = {}

--- Find buffer number for a file path. Returns nil if not loaded.
---@param file string Absolute or relative path
---@return integer|nil
local function find_buf_for_file(file)
	local abs = vim.fn.fnamemodify(file, ":p")
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			if name == abs or vim.fn.fnamemodify(name, ":p") == abs then
				return buf
			end
		end
	end
	return nil
end

--- Find a non-terminal window to open files in (avoid hijacking pi's terminal).
---@return integer
local function find_code_win()
	local cur = vim.api.nvim_get_current_win()
	-- Prefer a window that's not a terminal
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype ~= "terminal" then
			return win
		end
	end
	return cur
end

--- Open file at line in the code window (not the terminal split).
---@param file string
---@param line? integer Line number (1-indexed), default 1
---@return string Status message
function M.open_at(file, line)
	line = line or 1
	local win = find_code_win()
	vim.api.nvim_set_current_win(win)
	vim.cmd("edit +" .. line .. " " .. vim.fn.fnameescape(file))
	vim.api.nvim_win_set_cursor(win, { line, 0 })
	-- Center the line on screen
	vim.cmd("normal! zz")
	return "opened " .. file .. ":" .. line
end

--- Read buffer lines (includes unsaved edits). Falls back to disk if not loaded.
---@param file string
---@param start_line? integer 1-indexed, default 1
---@param end_line? integer 1-indexed inclusive, default -1 (all)
---@return table Lines array
function M.buf_lines(file, start_line, end_line)
	local buf = find_buf_for_file(file)
	if not buf then
		-- Not loaded — read from disk
		local abs = vim.fn.fnamemodify(file, ":p")
		local f = io.open(abs, "r")
		if not f then
			return { "ERROR: file not found: " .. abs }
		end
		local content = f:read("*a")
		f:close()
		local lines = vim.split(content, "\n", { plain = true })
		start_line = start_line or 1
		end_line = (end_line and end_line > 0) and end_line or #lines
		return vim.list_slice(lines, start_line, end_line)
	end

	local total = vim.api.nvim_buf_line_count(buf)
	start_line = (start_line or 1) - 1 -- convert to 0-indexed
	end_line = (end_line and end_line > 0) and end_line or total
	if start_line < 0 then start_line = 0 end
	if end_line > total then end_line = total end
	return vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
end

--- Write lines to buffer directly (no disk write). Buffer must be loaded.
--- Creates an undo point so user can undo the change.
---@param file string
---@param start_line integer 1-indexed
---@param end_line integer 1-indexed inclusive
---@param new_lines table Array of strings
---@return string Status message
function M.buf_set_lines(file, start_line, end_line, new_lines)
	local buf = find_buf_for_file(file)
	if not buf then
		return "ERROR: buffer not loaded for " .. file .. ". Open file first with open_at()."
	end

	-- Ensure modifiable
	local was_modifiable = vim.bo[buf].modifiable
	vim.bo[buf].modifiable = true

	-- Set lines (0-indexed start, exclusive end)
	vim.api.nvim_buf_set_lines(buf, start_line - 1, end_line, false, new_lines)

	vim.bo[buf].modifiable = was_modifiable
	return string.format("wrote %d lines to %s:%d-%d", #new_lines, file, start_line, end_line)
end

--- Show lines in a floating preview window.
---@param file string
---@param start_line integer 1-indexed
---@param end_line integer 1-indexed inclusive
---@param title? string Window title
---@return string Status message
function M.preview(file, start_line, end_line, title)
	local lines = M.buf_lines(file, start_line, end_line)
	if #lines == 0 then
		return "ERROR: no lines to preview"
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	-- Detect filetype from extension
	local ext = vim.fn.fnamemodify(file, ":e")
	if ext and ext ~= "" then
		local ft = vim.filetype.match({ filename = file }) or ext
		vim.bo[buf].filetype = ft
	end

	local width = math.floor(vim.o.columns * 0.6)
	local height = math.min(#lines, math.floor(vim.o.lines * 0.6))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	title = title or string.format(" %s:%d-%d ", vim.fn.fnamemodify(file, ":t"), start_line, end_line)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
	})

	-- Close on q or Esc
	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buf })
	end

	return string.format("preview %s:%d-%d (%d lines)", file, start_line, end_line, #lines)
end

--- Show diff between current buffer content and new content in a split.
---@param file string
---@param new_lines table Array of new lines
---@return string Status message
function M.show_diff(file, new_lines)
	local win = find_code_win()
	vim.api.nvim_set_current_win(win)

	-- Open original file
	vim.cmd("edit " .. vim.fn.fnameescape(file))
	vim.cmd("diffthis")

	-- Create scratch buffer with new content
	vim.cmd("vnew")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"

	-- Match filetype
	local ext = vim.fn.fnamemodify(file, ":e")
	if ext and ext ~= "" then
		local ft = vim.filetype.match({ filename = file }) or ext
		vim.bo[buf].filetype = ft
	end

	vim.cmd("diffthis")
	return "showing diff for " .. file
end

--- Get info about current editor state (cursor position, open buffers, etc.)
---@return table
function M.editor_state()
	local win = find_code_win()
	local buf = vim.api.nvim_win_get_buf(win)
	local cursor = vim.api.nvim_win_get_cursor(win)
	local name = vim.api.nvim_buf_get_name(buf)
	return {
		file = name,
		line = cursor[1],
		col = cursor[2],
		total_lines = vim.api.nvim_buf_line_count(buf),
		modified = vim.bo[buf].modified,
		filetype = vim.bo[buf].filetype,
	}
end

--- Register all handlers on _G.PiRpc for RPC access.
function M.register()
	_G.PiRpc = {
		open_at = M.open_at,
		buf_lines = M.buf_lines,
		buf_set_lines = M.buf_set_lines,
		preview = M.preview,
		show_diff = M.show_diff,
		editor_state = M.editor_state,
	}
end

return M
