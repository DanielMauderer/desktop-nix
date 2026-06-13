return {
	{
		"epwalsh/obsidian.nvim",
		version = "*", -- recommended, use latest release instead of latest commit
		lazy = true,
		ft = "markdown",
		dependencies = {
			-- Required.
			"nvim-lua/plenary.nvim",
		},
		cond = function()
			return vim.fn.isdirectory(vim.fn.expand("~/Cloud/Obsidian")) == 1
		end,
		opts = {
			workspaces = {
				{
					name = "Live",
					path = "~/Cloud/Obsidian/Life",
				},
			},
		},
	},
}
