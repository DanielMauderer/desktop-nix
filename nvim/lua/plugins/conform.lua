return {
	{ -- Autoformat
		"stevearc/conform.nvim",
		lazy = false,
		keys = {
			{
				"<leader>fo",
				function()
					require("conform").format({ async = true, lsp_fallback = true })
				end,
				mode = "",
				desc = "[F]ormat buffer with conform",
			},
			{
				"<leader>fs",
				function()
					require("conform").format({
						formatters = {
							"sqruff",
							-- "sqlfluff",
							-- "pg_format",
							-- "sql_formatter",
							-- "sqlfmt",
							stop_after_first = true,
						},
						range = {
							start = vim.api.nvim_buf_get_mark(0, "<"),
							["end"] = vim.api.nvim_buf_get_mark(0, ">"),
						},
					})
				end,
				mode = "v",
				desc = "[F]ormat [S]QL of current visual selection",
			},
		},
		---@module "conform"
		---@type conform.setupOpts
		opts = {
			default_format_opts = {
				lsp_format = "prefer",
				async = true,
			},
			notify_on_error = true,
			formatters = {
				sqruff = {
					-- cargo install --locked sqruff
					prepend_args = { "--dialect", "postgres" },
				},
			},
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "isort", "ruff_format", "ruff_organize_imports" },
				rust = { "rustfmt", "inject", lsp_format = "fallback" },
				javascript = { "inject", "prettierd", "prettier" },
				typescript = { "inject", "prettierd", "prettier" },
				json = { "jq" },
				xml = { "xmlformatter" },
				sql = { "sqlfluff", "pg_format", lsp_format = "fallback" },
			},
		},
	},
}
