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
		prefix = "<leader>p",
		ask = "<leader>ap",
		toggle = "<leader>pp",
		expand = "<leader>pe",
		yank = "gy",
	},
	quick_actions = {
		{
			keymap = "<leader>pc",
			desc = "Generate commit message for staged changes",
			prompt = [[
      Check the staged changes and create a git commit message with a conventional commit message.
      Message should be for why the change, not what changed.
      Message should be plain text. Only output the commit message
      keep it simple to understand.
      ]],
			cmd = function(prompt)
				return { "opencode", "run", "-m", "anthropic/claude-haiku-4-5", prompt }
			end,
		},
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
