return {
	{
		"saecki/crates.nvim",
		tag = "stable",
		event = { "BufRead Cargo.toml" },
		opts = {},
		keys = {
			{
				"<leader>rv",
				function()
					require("crates").show_versions_popup()
				end,
				desc = "Crate [v]ersions",
				ft = "toml",
			},
			{
				"<leader>ru",
				function()
					require("crates").upgrade_crate()
				end,
				desc = "Crate [u]pgrade",
				ft = "toml",
			},
			{
				"<leader>rU",
				function()
					require("crates").upgrade_all_crates()
				end,
				desc = "Crate [U]pgrade all",
				ft = "toml",
			},
		},
	},
}
