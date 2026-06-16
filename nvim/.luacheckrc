-- luacheck configuration for the Neovim Lua config.
-- Declares the Neovim runtime global (`vim`) and the plugin-provided globals
-- (Snacks, FzfLua) so luacheck reports real issues instead of hundreds of
-- "accessing undefined variable" false positives.
std = "lua54"

-- `vim` is writable: the config legitimately sets vim.o/vim.g/vim.opt fields.
globals = {
	"vim",
	"Snacks",
	"FzfLua",
}

-- Match stylua's column width (column_width default = 120).
max_line_length = 120
