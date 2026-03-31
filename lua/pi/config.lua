local M = {}

M.defaults = {
	split = {
		position = "right",
		width = 0.35,
	},
	keymaps = {
		ask = "<leader>ap",
		toggle = "<leader>pp",
		yank = "gy",
	},
	pi = {
		bin = "pi",
		extra_args = {},
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
