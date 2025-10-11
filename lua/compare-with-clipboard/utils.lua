local config = require("compare-with-clipboard.config")

local M = {}

M.setup_current_buffer = function(name, lines)
	vim.cmd.edit(name)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	vim.bo.buftype = "nofile"
	vim.bo.buflisted = false
	vim.cmd.diffthis()
end

M.get_lsp_range_lines = function(bufnr, lsp_range)
	if lsp_range == nil or bufnr == nil then
		return {}
	end
	return vim.api.nvim_buf_get_text(
		bufnr,
		lsp_range.start.line,
		lsp_range.start.character,
		lsp_range["end"].line,
		lsp_range["end"].character,
		{}
	)
end

M.get_register_lines = function(reg_name)
	local lines = {}
	local reg = vim.fn.getreg(reg_name)
	if reg == nil then
		return lines
	end
	for line in tostring(reg):gmatch("[^\n]+") do
		table.insert(lines, line)
	end
	-- Special-case empty register: keep at least one empty line so diff buffers render
	if #lines == 0 then
		lines = { "" }
	end
	return lines
end

M.get_current_buffer_lines = function(bufnr)
	bufnr = bufnr or 0
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if #lines == 0 then
		lines = { "" }
	end
	return lines
end

-- Best effort: get the *current* visual selection as text lines.
-- Works reliably when invoked from Visual mode mappings (preferred),
-- but also supports :'<,'> ranges. Falls back to range lines if marks are missing.
M.get_visual_selection_lines = function(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()

	-- First try marks `'<` and `'>` (char-accurate)
	local p1 = vim.fn.getpos("'<")
	local p2 = vim.fn.getpos("'>")

	local have_marks = p1[2] ~= 0 and p2[2] ~= 0
	if have_marks then
		local l1, c1 = p1[2], p1[3]
		local l2, c2 = p2[2], p2[3]
		if l1 > l2 or (l1 == l2 and c1 > c2) then
			l1, l2 = l2, l1
			c1, c2 = c2, c1
		end

		-- Determine selection kind
		local vmode = vim.fn.visualmode() -- 'v', 'V', or CTRL-V (block)
		if vmode == "V" then
			-- linewise
			local last_line_text = vim.api.nvim_buf_get_lines(bufnr, l2 - 1, l2, false)[1] or ""
			local end_col0 = #last_line_text -- 0-based exclusive
			local lines = vim.api.nvim_buf_get_text(bufnr, l1 - 1, 0, l2 - 1, end_col0, {})
			if #lines == 0 then
				lines = { "" }
			end
			return lines
		elseif vmode == "\022" then
			-- blockwise: take rectangular slice (bytes-based)
			local cmin = math.min(c1, c2)
			local cmax = math.max(c1, c2)
			local out = {}
			for row = l1, l2 do
				local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
				if #line == 0 then
					table.insert(out, "")
				else
					local start_col0 = math.max(cmin - 1, 0)
					local end_col0 = math.min(cmax, #line)
					local chunk = vim.api.nvim_buf_get_text(bufnr, row - 1, start_col0, row - 1, end_col0, {})[1] or ""
					table.insert(out, chunk)
				end
			end
			if #out == 0 then
				out = { "" }
			end
			return out
		else
			-- charwise
			local end_col0 = c2 -- 1-based inclusive -> 0-based exclusive
			local lines = vim.api.nvim_buf_get_text(bufnr, l1 - 1, c1 - 1, l2 - 1, end_col0, {})
			if #lines == 0 then
				lines = { "" }
			end
			return lines
		end
	end

	-- Fallback: if a :'<,'> range was supplied, use it (linewise)
	if opts.range and opts.range[1] and opts.range[2] then
		local l1, l2 = opts.range[1], opts.range[2]
		local lines = vim.api.nvim_buf_get_lines(bufnr, l1 - 1, l2, false)
		if #lines == 0 then
			lines = { "" }
		end
		return lines
	end

	-- Nothing selected
	return {}
end

M.open_split = function(opts)
	if opts.vertical_split then
		vim.cmd.vnew()
	else
		vim.cmd.new()
	end
end

M.split_lines = function(str)
	if not str or str == "" then
		return { "" }
	end
	local out = {}
	for line in tostring(str):gmatch("[^\n]+") do
		table.insert(out, line)
	end
	if #out == 0 then
		out = { "" }
	end
	return out
end

-- Floating scratch input to enter multi-line text and submit with a fixed keymap
-- Options:
--   title    : string
--   on_submit: fun(lines: string[])
M.open_text_input_float = function(opts)
	opts = opts or {}
	local float_cfg = config.default_opts.float or {}
	local columns, lines = vim.o.columns, vim.o.lines

	local function rel(v, total)
		if type(v) == "number" and v > 0 and v < 1 then
			return math.max(1, math.floor(total * v))
		end
		return v
	end

	local width = rel(float_cfg.width or 0.8, columns)
	local height = rel(float_cfg.height or 0.5, lines)
	local row = math.floor((lines - height) / 2 - 1)
	local col = math.floor((columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = float_cfg.border or "rounded",
		title = opts.title or float_cfg.title or "Compare — input",
		title_pos = "center",
	})

	-- buffer options
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype = "compare_clipboard_input"

	-- helpful header
	local header = {
		"Type or paste text to compare with the clipboard.",
		"Submit: " .. (float_cfg.submit_mapping or "<C-s>") .. "   Cancel: <Esc>",
		"-----------------------------------------------",
		"",
	}
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, header)
	vim.api.nvim_win_set_cursor(win, { #header, 1 })

	local submitted = false
	local function submit()
		if submitted then
			return
		end
		submitted = true
		local all = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		-- drop the header if it wasn't edited
		local content = {}
		local start_idx = 1
		if #all >= #header then
			local matches_header = true
			for i = 1, #header do
				if all[i] ~= header[i] then
					matches_header = false
					break
				end
			end
			if matches_header then
				start_idx = #header + 1
			end
		end
		for i = start_idx, #all do
			table.insert(content, all[i])
		end
		if #content == 0 then
			content = { "" }
		end
		if opts.on_submit then
			opts.on_submit(content)
		end
		pcall(vim.api.nvim_win_close, win, true)
	end

	local function cancel()
		if submitted then
			return
		end
		pcall(vim.api.nvim_win_close, win, true)
	end

	-- keymaps (both normal and insert)
	local submit_map = float_cfg.submit_mapping or "<C-s>"
	vim.keymap.set({ "n", "i" }, submit_map, submit, { buffer = buf, nowait = true, silent = true })
	vim.keymap.set({ "n", "i" }, "<Esc>", cancel, { buffer = buf, nowait = true, silent = true })
end

return M
