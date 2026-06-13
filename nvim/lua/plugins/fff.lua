return {
	{
		"dmtrKovalenko/fff.nvim",
		build = "cargo build --release",
		opts = {
			-- pass here all the options
		},
		keymaps = {
			close = {"<Esc>"},
		},
		keys = {
			{
				"<leader>ff", -- try it if you didn't it is a banger keybinding for a picker
				function()
					require("fff").find_files()
				end,
				desc = "Open file picker",
			},
			{
				"<leader>Ff", -- try it if you didn't it is a banger keybinding for a picker
				function()
					require("fff").find_in_git_root()
				end,
				desc = "Open file picker",
			},
		},
	},
}
