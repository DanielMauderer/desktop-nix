return {
	{
		"folke/trouble.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			modes = {
				cascade = {
					mode = "diagnostics", -- inherit from diagnostics mode
					filter = function(items)
						local severity = vim.diagnostic.severity.HINT
						for _, item in ipairs(items) do
							severity = math.min(severity, item.severity)
						end
						return vim.tbl_filter(function(item)
							return item.severity == severity
						end, items)
					end,
				},
			},
			keys = {
				["n"] = "next",
				["P"] = "next",
				["p"] = "prev",
				["N"] = "prev",
			}
		},
		keys = {
			{
				"<leader>xx",
				"<cmd>Trouble cascade open focus=true<cr>",
				desc = "Diagnostics (Trouble)",
			},
			{
				"<leader>xq",
				"<cmd>Trouble close<cr>",
				desc = "Diagnostics (Trouble)",
			},
			{
				"<leader>xX",
				function()
					require("trouble").open({
						mode = "cascade",
						focus = true,
						filter = { buf = 0, severity = vim.diagnostic.severity.ERROR },
					})
				end,
				desc = "Buffer Diagnostics (Trouble)",
			},
			{
				"<leader>cs",
				"<cmd>Trouble symbols toggle focus=false<cr>",
				desc = "Symbols (Trouble)",
			},
			{
				"<leader>cl",
				"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
				desc = "LSP Definitions / references / ... (Trouble)",
			},
			{
				"<leader>xL",
				"<cmd>Trouble loclist toggle<cr>",
				desc = "Location List (Trouble)",
			},
			{
				"<leader>xQ",
				"<cmd>Trouble qflist toggle<cr>",
				desc = "Quickfix List (Trouble)",
			},
		},
	},
}
