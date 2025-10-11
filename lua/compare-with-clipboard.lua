local config = require("compare-with-clipboard.config")
local utils = require("compare-with-clipboard.utils")

local M = {}

-- public: setup
M.setup = function(opts)
	config.default_opts = vim.tbl_deep_extend("force", config.default_opts, opts or {})
	if config.default_opts.create_user_commands then
		M._create_user_commands()
	end
end

-- keep original API
M.compare_registers = require("compare-with-clipboard.compare-registers").compare_registers

-- new: compare current visual selection with a register (default system "+")
M.compare_visual_selection_with_register = function(reg_name, opts)
	opts = vim.tbl_deep_extend("force", config.default_opts, opts or {})
	reg_name = reg_name or opts.register or "+"

	local selection = utils.get_visual_selection_lines(opts) -- from marks/range
	if not selection or #selection == 0 then
		vim.notify("[compare-with-clipboard] No visual selection detected", vim.log.levels.WARN)
		return
	end

	vim.cmd.tabnew()
	utils.setup_current_buffer("[clipboard " .. reg_name .. "]", utils.get_register_lines(reg_name))
	utils.open_split(opts)
	utils.setup_current_buffer("[selection]", selection)
end

-- new: interactive compare — system register vs user-chosen target
M.compare_clipboard_with_prompt = function(opts)
	opts = vim.tbl_deep_extend("force", config.default_opts, opts or {})
	local src_reg = opts.register or "+"

	local items = {
		{ key = "buffer", label = "Current buffer (entire file)" },
		{ key = "register", label = "Another register…" },
		{ key = "prompt", label = "Raw text (single-line prompt)…" },
		{ key = "float", label = "Raw text (floating buffer)…" },
	}

	local function run_with_lines(lines, label)
		vim.cmd.tabnew()
		utils.setup_current_buffer("[clipboard " .. src_reg .. "]", utils.get_register_lines(src_reg))
		utils.open_split(opts)
		utils.setup_current_buffer("[" .. label .. "]", lines)
	end

	vim.ui.select(items, {
		prompt = "Compare clipboard (" .. src_reg .. ") with:",
		format_item = function(it)
			return it.label
		end,
	}, function(choice)
		if not choice then
			return
		end

		if choice.key == "buffer" then
			run_with_lines(utils.get_current_buffer_lines(0), "current buffer")
			return
		end

		if choice.key == "register" then
			vim.ui.input({ prompt = 'Register name (e.g. +, *, ", 0-9, a-z): ' }, function(input)
				if not input or input == "" then
					return
				end
				run_with_lines(utils.get_register_lines(input), "register " .. input)
			end)
			return
		end

		if choice.key == "prompt" then
			vim.ui.input({ prompt = "Enter text to compare with clipboard: " }, function(text)
				if text == nil then
					return
				end
				run_with_lines(utils.split_lines(text), "raw text")
			end)
			return
		end

		if choice.key == "float" then
			utils.open_text_input_float({
				title = config.default_opts.float.title or "Compare with Clipboard — Input",
				on_submit = function(lines)
					run_with_lines(lines, "raw text")
				end,
			})
			return
		end
	end)
end

-- helper: register completion list
local _register_candidates = (function()
	local t = { "+", "*", '"' }
	for i = 0, 9 do
		table.insert(t, tostring(i))
	end
	for c = string.byte("a"), string.byte("z") do
		table.insert(t, string.char(c))
	end
	for c = string.byte("A"), string.byte("Z") do
		table.insert(t, string.char(c))
	end
	return t
end)()

local function _complete_registers(ArgLead, _)
	local lead = ArgLead or ""
	local res = {}
	for _, r in ipairs(_register_candidates) do
		if r:find("^" .. vim.pesc(lead)) then
			table.insert(res, r)
		end
	end
	return res
end

-- user commands
M._create_user_commands = function()
	-- Compare two registers directly: :CompareRegisters {reg1} {reg2}
	vim.api.nvim_create_user_command("CompareRegisters", function(args)
		local a, b = string.match(args.args, "^%s*(%S+)%s+(%S+)%s*$")
		if not a or not b then
			vim.notify("Usage: :CompareRegisters {reg1} {reg2}", vim.log.levels.ERROR)
			return
		end
		M.compare_registers(a, b, {})
	end, {
		desc = "Compare contents of two Vim registers",
		nargs = "+",
		complete = function(ArgLead, CmdLine)
			return _complete_registers(ArgLead, CmdLine)
		end,
	})

	-- Visual: compare the current visual selection with a register (default "+").
	-- Supports :'<,'>CompareSelectionWithRegister [reg]
	vim.api.nvim_create_user_command("CompareSelectionWithRegister", function(args)
		local reg = args.args ~= "" and args.args or config.default_opts.register
		-- Pass range for fallback if marks are unavailable
		local range = (args.range > 0) and { args.line1, args.line2 } or nil
		M.compare_visual_selection_with_register(reg, { range = range })
	end, {
		desc = "Compare current visual selection with a register (default '+')",
		nargs = "?",
		range = true,
		complete = function(ArgLead, CmdLine)
			return _complete_registers(ArgLead, CmdLine)
		end,
	})

	-- Normal: prompt the user what to compare the clipboard with
	-- Optional arg: :CompareClipboardWith [reg] to override source register (default '+')
	vim.api.nvim_create_user_command("CompareClipboardWith", function(args)
		local reg = args.args ~= "" and args.args or config.default_opts.register
		M.compare_clipboard_with_prompt({ register = reg })
	end, {
		desc = "Interactive: compare system register with buffer / another register / raw text",
		nargs = "?",
		complete = function(ArgLead, CmdLine)
			return _complete_registers(ArgLead, CmdLine)
		end,
	})
end

return M
