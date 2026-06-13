return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons", -- optional, but recommended
			-- Very fancy window picker
			{
				"s1n7ax/nvim-window-picker",
				name = "window-picker",
				event = "VeryLazy",
				version = "2.*",
				opts = {
					hint = "floating-big-letter",
					filter_rules = {
						-- Which buffers to ignore
						bo = {
							filetype = { "NvimTree", "neo-tree", "notify", "snacks_notif", "trouble" },
							buftype = { "terminal" },
						},
					},
				},
			},
		},
		lazy = false, -- neo-tree will lazily load itself
		---@module 'neo-tree'
		---@type neotree.Config
		opts = {
			sources = { "filesystem", "document_symbols", "buffers", "git_status" },
			close_if_last_window = false,
			popup_border_style = "rounded",
			enable_git_status = true,
			enable_diagnostics = true,
			-- This is the key setting you tried
			follow_current_file = {
				enabled = true, -- This will find and focus the file in the active buffer every time
				leave_dirs_open = true, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
			},
			-- Auto-expand directories when following files
			filesystem = {
				follow_current_file = {
					enabled = true,
					leave_dirs_open = true,
				},
				-- Use system commands for file operations
				use_libuv_file_watcher = true,
				window = {
					mappings = {
						["<2-LeftMouse>"] = "open_with_window_picker",
						["<cr>"] = "open_with_window_picker",
						["+"] = "open",
					},
				},
			},
		},
		keys = {
			{
				"<leader>tt",
				function()
					vim.cmd("Neotree left filesystem toggle")
				end,
				desc = "[T]ree [t]oggle",
			},
			{
				"<leader>tT",
				function()
					vim.cmd("Neotree float filesystem")
				end,
				desc = "[T]ree floating",
			},
			{
				"<leader>tg",
				function()
					vim.cmd("Neotree float git_status")
				end,
				desc = "[T]ree floating [G]it status",
			},
			{
				"<leader>tb",
				function()
					vim.cmd("Neotree float buffers")
				end,
				desc = "[T]ree floating [B]uffers",
			},
		},
	},
}
