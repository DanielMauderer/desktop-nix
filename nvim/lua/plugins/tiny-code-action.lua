return {
	"rachartier/tiny-code-action.nvim",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
	},
	event = "LspAttach",
	opts = {
		picker = {
			"buffer",
			opts = {
				hotkeys = true,
				auto_preview = true,
				auto_accept = true,
				custom_keys = {
					{ key = "i", pattern = "import" },
				},
			},
		},
		format_title = function(action, client)
			return string.format("%s (%s)", action.title, client.name)
		end,
	},
	keys = {
		{
			"<leader>ca",
			function()
				require("tiny-code-action").code_action({})
			end,
			desc = "Code Action",
			mode = "n",
		},
	},
}
