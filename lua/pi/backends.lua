local M = {}

local presets = {}

presets.pi = {
	bin = "pi",
	extra_args = {},
	build_cmd = function(bin, extra_args, prompt)
		local cmd = { bin }
		for _, a in ipairs(extra_args) do
			cmd[#cmd + 1] = a
		end
		if prompt then
			cmd[#cmd + 1] = prompt
		end
		return cmd
	end,
	format_prompt = function(ctx, question)
		if ctx.start_line then
			return string.format("Refer `%s` lines %d-%d. %s", ctx.file, ctx.start_line, ctx.end_line, question)
		end
		return string.format("Refer `%s`. %s", ctx.file, question)
	end,
}

presets.opencode = {
	bin = "opencode",
	extra_args = {},
	build_cmd = function(bin, extra_args, prompt)
		local cmd = { bin }
		for _, a in ipairs(extra_args) do
			cmd[#cmd + 1] = a
		end
		if prompt then
			cmd[#cmd + 1] = "--prompt"
			cmd[#cmd + 1] = prompt
		end
		return cmd
	end,
	format_prompt = function(ctx, question)
		if ctx.start_line then
			return string.format("Refer @%s lines %d-%d. %s", ctx.file, ctx.start_line, ctx.end_line, question)
		end
		return string.format("Refer @%s. %s", ctx.file, question)
	end,
}

--- Register a custom backend preset. Only `bin` is required; all other
--- fields fall back to the built-in `pi` preset.
---@param name string
---@param backend table Must contain `bin`; `extra_args`, `build_cmd`, `format_prompt` are optional.
function M.register(name, backend)
	assert(type(name) == "string" and name ~= "", "pi.nvim: backend name must be a non-empty string")
	assert(type(backend) == "table" and type(backend.bin) == "string" and backend.bin ~= "", "pi.nvim: backend must be a table with a non-empty 'bin'")
	presets[name] = vim.tbl_deep_extend("keep", backend, presets.pi)
end

--- Resolve a backend from a name or custom table, with optional overrides.
---@param name_or_table string|table
---@param opts table|nil
---@return table
function M.resolve(name_or_table, opts)
	opts = opts or {}
	local backend

	if type(name_or_table) == "table" then
		backend = vim.tbl_deep_extend("force", { extra_args = {} }, name_or_table)
	elseif type(name_or_table) == "string" then
		backend = presets[name_or_table]
		if not backend then
			error(
				string.format(
					"pi.nvim: unknown backend '%s'. Available: %s",
					name_or_table,
					table.concat(vim.tbl_keys(presets), ", ")
				)
			)
		end
		backend = vim.tbl_deep_extend("force", {}, backend)
	else
		error("pi.nvim: backend must be a string or table")
	end

	-- Apply overrides from backend_opts
	if opts.bin then
		backend.bin = opts.bin
	end
	if opts.extra_args then
		backend.extra_args = opts.extra_args
	end

	return backend
end

return M
