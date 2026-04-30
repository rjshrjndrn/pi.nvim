local M = {}

function M.get_visual_selection()
	local start_line = vim.fn.getpos("'<")[2]
	local end_line = vim.fn.getpos("'>")[2]
	local buf = vim.api.nvim_buf_get_name(0)
	local file = vim.fn.fnamemodify(buf, ":p")

	return {
		file = file,
		start_line = start_line,
		end_line = end_line,
	}
end

function M.get_buffer_info()
	local bufname = vim.api.nvim_buf_get_name(0)
	return {
		file = vim.fn.fnamemodify(bufname, ":p"),
	}
end

--- Resolve the working directory for spawning the backend process.
--- Walks up from the file's directory to find a git root; falls back to :h.
--- SYNC version kept for backwards compat — prefer resolve_cwd_async.
---@param file string Absolute path to the file.
---@return string
function M.resolve_cwd(file)
	local dir = vim.fn.fnamemodify(file, ":h")
	local result = vim.fn.system("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel 2>/dev/null")
	if vim.v.shell_error == 0 then
		return vim.trim(result)
	end
	return dir
end

--- Async version of resolve_cwd. Uses vim.system() so the main thread is
--- never blocked by the git subprocess.
---@param file string Absolute path to the file.
---@param callback fun(cwd: string)
function M.resolve_cwd_async(file, callback)
	local dir = vim.fn.fnamemodify(file, ":h")
	vim.system(
		{ "git", "-C", dir, "rev-parse", "--show-toplevel" },
		{ text = true },
		function(result)
			vim.schedule(function()
				if result.code == 0 then
					callback(vim.trim(result.stdout))
				else
					callback(dir)
				end
			end)
		end
	)
end

function M.format_prompt(backend, ctx, question)
	return backend.format_prompt(ctx, question)
end

return M
