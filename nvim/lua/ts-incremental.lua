-- Minimal treesitter-based incremental selection.
--
-- Replaces the `incremental_selection` module that nvim-treesitter's `main`
-- branch removed in the 0.12-era rewrite. Keeps a per-buffer stack of nodes so
-- the visual selection can grow toward the root and shrink back along the
-- syntax tree.
--
-- Keymaps are wired in lua/plugins/treesitter.lua:
--   n <C-space>  init        x <C-space>  grow
--   x <C-s>      grow        x <M-space>  shrink

local M = {}

-- bufnr -> { node, node, ... }  (innermost first, outermost last)
local stack = {}

local function cur_buf()
	return vim.api.nvim_get_current_buf()
end

local function range_eq(a, b)
	local a1, a2, a3, a4 = a:range()
	local b1, b2, b3, b4 = b:range()
	return a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4
end

-- Select `node`'s range as a charwise visual selection.
local function visual_select(node)
	if not node then
		return
	end
	local s_row, s_col, e_row, e_col = node:range()
	-- A node's end column is exclusive; convert it to an inclusive cursor pos.
	if e_col == 0 then
		e_row = e_row - 1
		local line = vim.api.nvim_buf_get_lines(0, e_row, e_row + 1, false)[1] or ""
		e_col = math.max(#line - 1, 0)
	else
		e_col = e_col - 1
	end

	-- Leave any active visual selection so `v` starts a fresh one.
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		vim.cmd("normal! \27") -- <Esc>
	end

	vim.api.nvim_win_set_cursor(0, { s_row + 1, s_col })
	vim.cmd("normal! v")
	vim.api.nvim_win_set_cursor(0, { e_row + 1, e_col })
end

function M.init()
	local node = vim.treesitter.get_node()
	if not node then
		return
	end
	stack[cur_buf()] = { node }
	visual_select(node)
end

function M.grow()
	local buf = cur_buf()
	local s = stack[buf]
	if not s or #s == 0 then
		return M.init()
	end
	local node = s[#s]
	local parent = node:parent()
	-- Skip parents whose range is identical to the current node.
	while parent and range_eq(parent, node) do
		parent = parent:parent()
	end
	if parent then
		table.insert(s, parent)
		visual_select(parent)
	else
		visual_select(node) -- already at the root
	end
end

function M.shrink()
	local s = stack[cur_buf()]
	if not s or #s == 0 then
		return
	end
	if #s > 1 then
		table.remove(s)
	end
	visual_select(s[#s])
end

return M
