local M = {}

function M.get_visual_selection()
	local start_line = vim.fn.line("'<")[2]
	local end_line = vim.fn.line("'>")[2]
	local buf = vim.api.nvim_buf_get_name(0)
	local file = vim.fn.fnamemodify(buf, ":.")

	return {
		file = file,
		start_line = start_line,
		end_line = end_line,
	}
end

function M.get_buffer_info()
	local bufname = vim.api.nvim_buf_get_name(0)
	return {
		file = vim.fn.fnamemodify(bufname, ":."),
	}
end

function M.format_prompt(ctx, question)
	if ctx and ctx.start_line then
		return string.format("`%s` lines %d-%d. %s", ctx.file, ctx.start_line, ctx.end_line, question)
	else
		return string.format("I'm working in `%s`. %s", ctx.file, question)
	end
end

return M
