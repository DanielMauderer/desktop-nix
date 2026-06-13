return {
	{
		"NeogitOrg/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"sindrets/diffview.nvim", -- optional - Diff integration
			"folke/snacks.nvim", -- optional
		},
		cmd = "Neogit",
		keys = {
			{
				"<leader>gg",
				function()
					require("neogit").open()
				end,
				desc = "Neo[g]it",
			},
			{
				"<leader>gp",
				function()
					require("neogit").open({ "pull", "--rebase" })
				end,
				desc = "[G]it [p]ull",
			},
		},
	},
}
