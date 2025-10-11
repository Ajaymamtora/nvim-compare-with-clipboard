local M = {}

M.default_opts = {
	-- split layout
	vertical_split = false,

	-- default source register for "clipboard" comparisons
	register = "+",

	-- auto-create user commands on setup()
	create_user_commands = true,

	-- floating input configuration (used by the "raw text (floating buffer)" option)
	float = {
		border = "rounded",
		width = 0.8, -- 80% of editor width
		height = 0.5, -- 50% of editor height
		title = "Compare with Clipboard — Input",
		submit_mapping = "<C-s>", -- press to submit from the floating buffer
	},
}

return M
