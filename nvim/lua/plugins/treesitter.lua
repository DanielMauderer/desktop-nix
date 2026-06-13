return {
	-- Treesitter — `main` branch (the 0.12-era rewrite). There is no module/opts
	-- system anymore: parsers are installed explicitly here, and highlight + indent
	-- are enabled per-buffer by the FileType autocmd in `init.lua`
	-- (`vim.treesitter.start` + `indentexpr`), which also auto-installs missing parsers.
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			-- `:TSUpdate` only updates already-installed parsers; install() is what
			-- populates them. Safe to call every startup — installed langs are skipped.
			require("nvim-treesitter").install({
				"angular",
				"bash",
				"c",
				"cpp",
				"css",
				"diff",
				"dockerfile",
				"go",
				"gomod",
				"gosum",
				"html",
				"javascript",
				"json",
				"lua",
				"luadoc",
				"markdown",
				"markdown_inline",
				"python",
				"query",
				"regex",
				"rust",
				"scss",
				"toml",
				"tsx",
				"typescript",
				"vim",
				"vimdoc",
				"yaml",
			})

			-- Incremental selection — the `main` branch dropped the built-in module,
			-- so this is a small local replacement (see lua/ts-incremental.lua).
			local inc = require("ts-incremental")
			vim.keymap.set("n", "<C-space>", inc.init, { desc = "TS: start incremental selection" })
			vim.keymap.set("x", "<C-space>", inc.grow, { desc = "TS: grow node" })
			vim.keymap.set("x", "<C-s>", inc.grow, { desc = "TS: grow scope" })
			vim.keymap.set("x", "<M-space>", inc.shrink, { desc = "TS: shrink node" })
		end,
	},

	-- Treesitter text objects — also on its own `main` branch, with a new
	-- manual-keymap API (the `.select` / `.move` / `.swap` submodules).
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		lazy = false,
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = { lookahead = true },
				move = { set_jumps = true },
			})

			-- Select (visual / operator-pending)
			local select = require("nvim-treesitter-textobjects.select")
			local selections = {
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
			}
			for key, query in pairs(selections) do
				vim.keymap.set({ "x", "o" }, key, function()
					select.select_textobject(query, "textobjects")
				end, { desc = "TS select " .. query })
			end

			-- Movement
			local move = require("nvim-treesitter-textobjects.move")
			local moves = {
				goto_next_start = { ["]m"] = "@function.outer", ["]]"] = "@class.outer" },
				goto_next_end = { ["]M"] = "@function.outer", ["]["] = "@class.outer" },
				goto_previous_start = { ["[m"] = "@function.outer", ["[["] = "@class.outer" },
				goto_previous_end = { ["[M"] = "@function.outer", ["[]"] = "@class.outer" },
			}
			for fn, maps in pairs(moves) do
				for key, query in pairs(maps) do
					vim.keymap.set({ "n", "x", "o" }, key, function()
						move[fn](query, "textobjects")
					end, { desc = "TS " .. fn .. " " .. query })
				end
			end

			-- Swap parameters
			local swap = require("nvim-treesitter-textobjects.swap")
			vim.keymap.set("n", "<leader>a", function()
				swap.swap_next("@parameter.inner")
			end, { desc = "Swap next parameter" })
			vim.keymap.set("n", "<leader>A", function()
				swap.swap_previous("@parameter.inner")
			end, { desc = "Swap previous parameter" })
		end,
	},
}
