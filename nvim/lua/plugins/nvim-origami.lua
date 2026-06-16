return {
	{
		"chrisgrieser/nvim-origami",
		event = "VeryLazy",
		opts = {
			foldtext = {
				lineCount = {
					template = "󰘞 %d", -- `%d` is replaced with the number of folded lines
					hlgroup = "Comment",
				},
			},
			autoFold = {
				enabled = false,
			},
		},

		-- recommended: disable vim's auto-folding
		init = function()
			vim.opt.foldlevel = 99
			vim.opt.foldlevelstart = 99
		end,
	},
}
