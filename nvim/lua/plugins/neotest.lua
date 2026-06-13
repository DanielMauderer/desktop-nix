return {
	{
		"nvim-neotest/neotest",
		ft = { "rust" },
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
			"mrcjkb/rustaceanvim",
		},
		config = function()
			require("neotest").setup({
				-- Use rustaceanvim's built-in neotest adapter (backed by
				-- cargo-nextest). Do NOT also add neotest-rust — they conflict.
				adapters = {
					require("rustaceanvim.neotest"),
				},
			})
		end,
		keys = {
			{
				"<leader>rtt",
				function()
					require("neotest").run.run()
				end,
				desc = "[T]est nearest",
				ft = "rust",
			},
			{
				"<leader>rtf",
				function()
					require("neotest").run.run(vim.fn.expand("%"))
				end,
				desc = "Test [f]ile",
				ft = "rust",
			},
			{
				"<leader>rtl",
				function()
					require("neotest").run.run_last()
				end,
				desc = "Test [l]ast",
				ft = "rust",
			},
			{
				"<leader>rts",
				function()
					require("neotest").summary.toggle()
				end,
				desc = "Test [s]ummary",
				ft = "rust",
			},
			{
				"<leader>rto",
				function()
					require("neotest").output.open({ enter = true })
				end,
				desc = "Test [o]utput",
				ft = "rust",
			},
			{
				"<leader>rtd",
				function()
					require("neotest").run.run({ strategy = "dap" })
				end,
				desc = "[D]ebug nearest test",
				ft = "rust",
			},
		},
	},
}
