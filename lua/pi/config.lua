local M = {}
local backends = require("pi.backends")

M.defaults = {
	backend = "pi",
	backend_opts = {},
	split = {
		position = "right",
		width = 0.35,
	},
	keymaps = {
		ask = "<leader>ap",
		toggle = "<leader>pp",
		yank = "gy",
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--- Resolve the active backend from config.
---@return table
function M.get_backend()
	return backends.resolve(M.options.backend, M.options.backend_opts)
end

return M
