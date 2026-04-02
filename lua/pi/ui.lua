local M = {}
local config = require("pi.config")

local term_buf = nil
local term_win = nil
local term_job = nil
local augroup = vim.api.nvim_create_augroup("PiTerminal", { clear = true })

--- Join continuation lines caused by terminal hard-wrapping.
--- Lines whose display width equals the terminal width are wraps, not real newlines.
local function join_wrapped_lines(lines, term_width)
	local result = {}
	local current = ""
	for _, line in ipairs(lines) do
		current = current .. line
		if vim.fn.strdisplaywidth(line) < term_width then
			table.insert(result, current)
			current = ""
		end
	end
	if current ~= "" then
		table.insert(result, current)
	end
	return result
end

local function setup_term_keymaps(buf)
	vim.keymap.set("x", config.options.keymaps.yank, function()
		-- Yank the visual selection normally
		vim.cmd('normal! y')

		local reg = vim.fn.getreg('"')
		local lines = vim.split(reg, "\n", { plain = true })
		local term_width = vim.api.nvim_win_get_width(0)

		local joined = join_wrapped_lines(lines, term_width)
		local text = table.concat(joined, "\n")

		vim.fn.setreg('"', text)
		vim.fn.setreg("+", text)
	end, { buffer = buf, desc = "Smart yank (unwrap terminal lines)" })
end

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

function M.open(initial_prompt, backend)
	-- If already running, just show the window
	if term_job and vim.fn.jobwait({ term_job }, 0)[1] == -1 then
		if not term_win or not vim.api.nvim_win_is_valid(term_win) then
			open_split(term_buf)
		end
		return true -- already running
	end

	-- Build command via backend
	backend = backend or require("pi.config").get_backend()
	local cmd = backend.build_cmd(backend.bin, backend.extra_args, initial_prompt)

	-- Open split and spawn pi TUI
	open_split()
	term_job = vim.fn.termopen(cmd, {
		cwd = vim.fn.getcwd(),
		env = {
			-- OpenCode checks process.env.TMUX / process.env.STY to decide whether
			-- to wrap its OSC 52 clipboard write in a DCS tmux passthrough sequence
			-- (\x1bPtmux;\x1b...\x1b\\).  When those vars are inherited from the
			-- outer tmux/screen session, Neovim's libvterm mishandles the DCS frame
			-- and the base64 payload ends up routed back to OpenCode's stdin, where
			-- Bubble Tea types it into the input area.
			-- Forcing both to "" makes the JS `TMUX || STY` check falsy, so OpenCode
			-- emits a plain OSC 52 sequence instead, which libvterm handles cleanly.
			-- OpenCode's native clipboard path (wl-copy / xclip / xsel) is unaffected.
			TMUX = "",
			STY = "",
		},
		on_exit = function()
			term_job = nil
			term_buf = nil
		end,
	})
	term_buf = vim.api.nvim_get_current_buf()
	vim.bo[term_buf].buflisted = false
	vim.api.nvim_buf_set_name(term_buf, "pi")
	vim.cmd("setlocal bufhidden=hide")

	-- Smart yank keymap for copying without terminal wraps
	setup_term_keymaps(term_buf)

	-- Auto-enter insert mode when focusing the terminal buffer
	vim.api.nvim_create_autocmd("BufEnter", {
		group = augroup,
		buffer = term_buf,
		callback = function()
			if vim.bo.buftype == "terminal" then
				vim.cmd("startinsert")
			end
		end,
	})

	-- Go back to code window
	vim.cmd("wincmd p")
	return false -- fresh start
end

function M.send(text)
	if term_job then
		-- Wrap in bracketed-paste markers so OpenCode's Bubble Tea input does not
		-- treat individual characters as keystrokes.  Without this, the '@' in the
		-- formatted prompt (e.g. "Refer @file lines N-M.") triggers OpenCode's
		-- mention-autocomplete, which replaces the typed file path with whatever
		-- agent name is highlighted in the dropdown (e.g. "@coder-v2").
		-- Bubble Tea honours \x1b[200~ / \x1b[201~ and inserts the whole block as
		-- literal text, bypassing all key-event callbacks.
		vim.fn.chansend(term_job, "\x1b[200~" .. text .. "\x1b[201~\r")
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
		-- Focus the pi window (open() jumps back to code window)
		if term_win and vim.api.nvim_win_is_valid(term_win) then
			vim.api.nvim_set_current_win(term_win)
			vim.cmd("startinsert")
		end
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
