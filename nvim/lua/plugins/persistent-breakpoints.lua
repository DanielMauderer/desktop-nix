return {
	{
		"Weissle/persistent-breakpoints.nvim",
		opts = {
			load_breakpoints_event = { "BufReadPost" },
		},
		event = "BufReadPost",
		keys = {
			{
				"<leader>d",
				group = "Debugger",
				nowait = true,
				remap = false,
			},
			{
				"<leader>db",
				function()
					require("persistent-breakpoints.api").toggle_breakpoint()
				end,
			},
			{
				"<leader>dB",
				function()
					require("persistent-breakpoints.api").set_conditional_breakpoint()
				end,
			},
			{
				"<leader>dc",
				function()
					require("persistent-breakpoints.api").clear_all_breakpoints()
				end,
			},
		},
	},
}
