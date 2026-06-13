return {
	{
		"stevearc/aerial.nvim",
		opts = {},
		-- Optional dependencies
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		keys = {
			{
				"<leader>fa",
				function()
					require("aerial").fzf_lua_picker()
				end,
				desc = "[F]ind [A]erial (treesitter)",
			},
		},
	},
}
