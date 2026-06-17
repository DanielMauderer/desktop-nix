return {
	{
		"stevearc/oil.nvim",
		---@module 'oil'
		---@type oil.SetupOpts
		opts = {
			default_file_explorer = false,
		},
		dependencies = { "nvim-tree/nvim-web-devicons" },
		-- Lazy-load on the :Oil command / keymap instead of eagerly at startup, so a
		-- config error here can't abort editor start (NV-ST-3). default_file_explorer
		-- is false, so nothing else needs oil loaded on boot.
		cmd = "Oil",
		keys = {
			{ "-", "<cmd>Oil<cr>", desc = "Open parent directory (oil)" },
		},
	},
}
