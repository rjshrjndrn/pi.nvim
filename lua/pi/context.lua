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

function M.format_prompt(backend, ctx, question)
	return backend.format_prompt(ctx, question)
end

return M
