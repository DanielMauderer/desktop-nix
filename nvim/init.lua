-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- disable netrw, we use own explorer
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.have_nerd_font = true

vim.o.conceallevel = 0

vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true

-- [[ Install `lazy.nvim` plugin manager ]]
--    https://github.com/folke/lazy.nvim
--    `:help lazy.nvim.txt` for more info
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- [[ Configure plugins ]]
-- NOTE: Here is where you install your plugins.
--  You can configure plugins using the `config` key.
--
--  You can also configure plugins after the setup call,
--    as they will be available in your neovim runtime.
require("lazy").setup("plugins")

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!

-- Show delta to current line
vim.o.relativenumber = true

-- Set highlight on search
vim.o.hlsearch = true

-- Make line numbers default
vim.o.number = true

-- Enable mouse mode
vim.o.mouse = "a"

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = "unnamedplus"

vim.opt.fillchars:append({ diff = "╱" })

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1 })
end, { desc = "Go to previous diagnostic message" })
vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1 })
end, { desc = "Go to next diagnostic message" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- [[ Highlight on yank ]]
-- See `:help vim.hl.on_yank()`
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

-- Setup neovim lua configuration
require("neodev").setup()

-- Julians personal edit
-- Enable wildmenu and configure wildmode
vim.o.wildmenu = true
vim.o.wildmode = "list:longest,full"

-- Automatically set yaml files to be of type helm if a parent fir has Chart.yaml
-- Function to check if Chart.yaml exists in parent directories
local function has_chart_yaml()
	local current_dir = vim.fn.expand("%:p:h")
	while current_dir ~= "/" do
		if vim.fn.filereadable(current_dir .. "/Chart.yaml") == 1 then
			return true
		end
		current_dir = vim.fn.fnamemodify(current_dir, ":h")
	end
	return false
end

-- Enable treesitter highlighting + indent per buffer (nvim-treesitter `main` has
-- no module system). If a parser isn't installed yet, install it async then
-- start — the replacement for the old `auto_install = true`. Only languages
-- treesitter actually ships are installed, so pseudo-filetypes (snacks_notif, …)
-- are silently ignored instead of spamming "unsupported language" warnings.
local ts_available -- memoized list of installable parsers
vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
		if not lang then
			return
		end

		local nts = require("nvim-treesitter")

		local function start()
			if vim.api.nvim_buf_is_valid(args.buf) and pcall(vim.treesitter.start, args.buf, lang) then
				vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end

		if vim.tbl_contains(nts.get_installed("parsers"), lang) then
			start()
			return
		end

		ts_available = ts_available or nts.get_available()
		if vim.tbl_contains(ts_available, lang) then
			nts.install({ lang }):await(vim.schedule_wrap(function(err)
				if not err then
					start()
				end
			end))
		end
	end,
})

-- Autocommand to set filetype to helm for yaml files in Helm charts
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = "*.yaml,*.tpl",
	callback = function()
		if has_chart_yaml() then
			vim.bo.filetype = "helm"
		end
	end,
})

local kitty_group = vim.api.nvim_create_augroup("KittyPadding", { clear = true })

local function set_kitty_padding(value)
	-- Only meaningful inside kitty; skip the shell-outs entirely on other
	-- terminals (they would otherwise fail twice per enter/leave).
	if not vim.env.KITTY_WINDOW_ID then
		return
	end
	-- Try direct kitten first (base system), fall back to host execution
	vim.fn.system("kitten @ set-spacing padding=" .. value)
	if vim.v.shell_error ~= 0 then
		vim.fn.system("flatpak-spawn --host kitten @ set-spacing padding=" .. value)
	end
end

vim.api.nvim_create_autocmd("VimEnter", {
	group = kitty_group,
	callback = function()
		set_kitty_padding(0)
	end,
})

vim.api.nvim_create_autocmd("VimLeave", {
	group = kitty_group,
	callback = function()
		set_kitty_padding(10)
	end,
})

-- Load LSP Manager
require("lsp-manager")

-- Create user command for LSP Manager
vim.api.nvim_create_user_command("LspManager", function()
	require("lsp-manager").open_lsp_picker()
end, { desc = "Open LSP Manager" })

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=4 sts=4 sw=4 et
