return {
	{
		"coder/claudecode.nvim",
		dependencies = { "folke/snacks.nvim" },
		opts = {
			-- Run Claude inside a snacks terminal split that connects back to
			-- Neovim over the same WebSocket/MCP protocol the official IDE
			-- extensions use (selection, buffer and diagnostics sharing,
			-- inline diff accept/deny).
			terminal = {
				provider = "snacks",
				split_side = "right",
				split_width_percentage = 0.35,
			},
			-- Open diffs in their own tab so they get the full editor width
			-- instead of being squished beside the file tree and Claude split.
			diff_opts = {
				layout = "vertical",
				open_in_new_tab = true,
				-- Keep the Claude terminal in the diff tab so the diff sits next
				-- to the chat and edits can be accepted from there.
				hide_terminal_in_new_tab = false,
			},
		},
		config = function(_, opts)
			require("claudecode").setup(opts)

			-- The diff opens in its own tab (see diff_opts above). neo-tree
			-- shows up there too and eats horizontal space, so close any
			-- neo-tree window living in the diff tab. It's per-tabpage, so this
			-- never touches the tree in the original tab.
			vim.api.nvim_create_autocmd("BufWinEnter", {
				group = vim.api.nvim_create_augroup("ClaudeCodeDiffNeotree", { clear = true }),
				callback = function(args)
					-- Matches both "… (proposed)" and "… (NEW FILE - proposed)".
					if not vim.api.nvim_buf_get_name(args.buf):match("proposed%)") then
						return
					end
					vim.schedule(function()
						for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
							local buf = vim.api.nvim_win_get_buf(win)
							if vim.bo[buf].filetype == "neo-tree" then
								pcall(vim.api.nvim_win_close, win, true)
							end
						end
					end)
				end,
			})
		end,
		keys = {
			{ "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Toggle [C]laude" },
			{ "<leader>cf", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude [f]ocus" },
			{ "<leader>cr", "<cmd>ClaudeCode --resume<cr>", desc = "Claude [r]esume" },
			{ "<leader>cC", "<cmd>ClaudeCode --continue<cr>", desc = "Claude [C]ontinue" },
			{ "<leader>cm", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Claude select [m]odel" },
			{ "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude add [b]uffer" },
			{ "<leader>cv", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude send selection" },
			{ "<leader>cy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude accept diff ([y]es)" },
			{ "<leader>cn", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude deny diff ([n]o)" },
		},
	},
}
