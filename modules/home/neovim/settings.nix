# nixvim settings for modules/home/neovim/default.nix, split out as a plain function
# returning the `programs.nixvim` value so it can be built standalone (nixvim's
# makeNixvimWithModule) as well as consumed by the home-manager module. The three
# unpackaged plugins are passed in as built derivations; claudecode uses pkgs.
{
  pkgs,
  ember,
  pretty-hover,
  tiny-code-action,
}:
{
  enable = true;
  viAlias = true;
  vimAlias = true;

  # Only the python3 provider (pynvim) is kept — nothing uses Ruby/Node/Perl,
  # so drop them to trim the closure and :checkhealth noise.
  withPython3 = true;
  withRuby = false;
  withNodeJs = false;
  withPerl = false;
  extraPython3Packages = ps: [ ps.pynvim ];

  # ── Editor tooling on Neovim's PATH (was home.packages) ──────────────────
  extraPackages = with pkgs; [
    # LSP servers
    lua-language-server # lua_ls
    gopls # go
    clang-tools # clangd + clang-format
    vscode-langservers-extracted # html / cssls / jsonls
    yaml-language-server # yamlls
    rust-analyzer # for rustaceanvim (excludes itself from lspconfig)
    # Formatters
    stylua # lua
    prettierd # js / ts / json / yaml / ...
    python3Packages.isort # python import sorter
    ruff # python linter + formatter
    gofumpt # go
    jq # json
    sqruff # sql (conform <leader>fs)
    # Debuggers / DAP adapters
    gdb # C / C++ / Rust via gdb DAP
    vscode-js-debug # js-debug-adapter for TS / JS
    # Pickers / clipboard
    fzf # fzf-lua backend binary
    wl-clipboard # clipboard = "unnamedplus" on Wayland
  ];

  # ── ember colorscheme (the editor's look) ────────────────────────────────
  colorscheme = "ember";

  # ── Options (init.lua vim.o/vim.opt) ─────────────────────────────────────
  opts = {
    conceallevel = 0;
    tabstop = 4;
    shiftwidth = 4;
    expandtab = true;
    relativenumber = true;
    hlsearch = true;
    number = true;
    mouse = "a";
    clipboard = "unnamedplus";
    breakindent = true;
    undofile = true;
    ignorecase = true;
    smartcase = true;
    signcolumn = "yes";
    updatetime = 250;
    timeoutlen = 300;
    completeopt = "menuone,noselect";
    termguicolors = true;
    wildmenu = true;
    wildmode = "list:longest,full";
    # nvim-origami disables vim auto-folding by keeping folds fully open.
    foldlevel = 99;
    foldlevelstart = 99;
  };

  # ── Globals (init.lua vim.g) ─────────────────────────────────────────────
  globals = {
    mapleader = " ";
    maplocalleader = " ";
    # We use our own explorer; disable netrw.
    loaded_netrw = 1;
    loaded_netrwPlugin = 1;
    have_nerd_font = true;
  };

  # ── Base keymaps (init.lua) ──────────────────────────────────────────────
  keymaps = [
    {
      mode = [
        "n"
        "v"
      ];
      key = "<Space>";
      action = "<Nop>";
      options.silent = true;
    }
    {
      mode = "n";
      key = "[d";
      action.__raw = "function() vim.diagnostic.jump({ count = -1 }) end";
      options.desc = "Go to previous diagnostic message";
    }
    {
      mode = "n";
      key = "]d";
      action.__raw = "function() vim.diagnostic.jump({ count = 1 }) end";
      options.desc = "Go to next diagnostic message";
    }
    {
      mode = "n";
      key = "<leader>e";
      action.__raw = "vim.diagnostic.open_float";
      options.desc = "Open floating diagnostic message";
    }
    {
      mode = "n";
      key = "<leader>q";
      action.__raw = "vim.diagnostic.setloclist";
      options.desc = "Open diagnostics list";
    }
  ];

  # ── Treesitter (main branch, grammars from Nix) ──────────────────────────
  # nixvim's highlight.enable/indent.enable generate the same per-buffer
  # FileType autocmd (vim.treesitter.start + indentexpr) the old init.lua had;
  # all grammars are installed via Nix so nothing compiles at runtime.
  # Incremental selection + textobjects (main-branch API) are wired in Lua.
  plugins.treesitter = {
    enable = true;
    highlight.enable = true;
    indent.enable = true;
  };

  # ── Everything else: plugins from Nix + the ported Lua config ────────────
  extraPlugins =
    (with pkgs.vimPlugins; [
      # libraries / dependencies
      plenary-nvim
      nui-nvim
      nvim-web-devicons
      nvim-nio
      luasnip
      SchemaStore-nvim
      diffview-nvim
      nvim-window-picker
      neodev-nvim
      nvim-treesitter-textobjects
      # editor plugins
      comment-nvim
      lualine-nvim
      gitsigns-nvim
      which-key-nvim
      trouble-nvim
      aerial-nvim
      oil-nvim
      fzf-lua
      grug-far-nvim
      neo-tree-nvim
      neogit
      nvim-autopairs
      nvim-surround
      conform-nvim
      blink-cmp
      crates-nvim
      fidget-nvim
      snacks-nvim
      rustaceanvim
      neotest
      nvim-dap
      nvim-dap-ui
      nvim-dap-python
      nvim-dap-virtual-text
      nvim-lspconfig
      venv-selector-nvim
      vim-fugitive
      vim-rhubarb
      vim-sleuth
      persistent-breakpoints-nvim
      nvim-origami
    ])
    ++ [
      ember
      pretty-hover
      tiny-code-action
      pkgs.vimPlugins.claudecode-nvim
    ];

  extraConfigLua = ''
    -- ══ Base autocmds / functions (init.lua) ═════════════════════════════════
    vim.opt.fillchars:append({ diff = "╱" })

    require("neodev").setup()

    -- Highlight on yank
    local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
    vim.api.nvim_create_autocmd("TextYankPost", {
      callback = function()
        vim.hl.on_yank()
      end,
      group = highlight_group,
      pattern = "*",
    })

    -- Set yaml/tpl files to helm when a parent dir has Chart.yaml
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

    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
      pattern = "*.yaml,*.tpl",
      callback = function()
        if has_chart_yaml() then
          vim.bo.filetype = "helm"
        end
      end,
    })

    -- kitty padding: 0 inside nvim, restored on leave
    local kitty_group = vim.api.nvim_create_augroup("KittyPadding", { clear = true })
    local function set_kitty_padding(value)
      if not vim.env.KITTY_WINDOW_ID then
        return
      end
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

    -- ══ Simple plugin setups ════════════════════════════════════════════════
    require("Comment").setup()
    require("nvim-autopairs").setup({})
    require("nvim-surround").setup({})
    require("fidget").setup({})
    require("pretty_hover").setup({})
    require("grug-far").setup({})
    require("aerial").setup({})
    require("oil").setup({ default_file_explorer = false })
    require("crates").setup({})
    require("venv-selector").setup({})

    require("lualine").setup({
      options = {
        icons_enabled = true,
        theme = "auto",
        component_separators = "|",
        section_separators = "",
      },
    })

    -- ══ which-key ════════════════════════════════════════════════════════════
    require("which-key").setup({
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {},
      },
      spec = {
        { "<leader>c", group = "[C]laude", mode = { "n", "x" } },
        { "<leader>d", group = "[D]ocument" },
        { "<leader>r", group = "[R]ust" },
        { "<leader>s", group = "[S]earch" },
        { "<leader>w", group = "[W]orkspace" },
        { "<leader>t", group = "[T]oggle" },
        { "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
        { "<leader>x", group = "Trouble", mode = { "n", "v" } },
      },
    })

    -- ══ gitsigns ═════════════════════════════════════════════════════════════
    require("gitsigns").setup({
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buf = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        map({ "n", "v" }, "]c", function()
          if vim.wo.diff then
            return "]c"
          end
          vim.schedule(function()
            gs.next_hunk()
          end)
          return "<Ignore>"
        end, { expr = true, desc = "Jump to next hunk" })
        map({ "n", "v" }, "[c", function()
          if vim.wo.diff then
            return "[c"
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return "<Ignore>"
        end, { expr = true, desc = "Jump to previous hunk" })

        map("v", "<leader>hs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "stage git hunk" })
        map("v", "<leader>hr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "reset git hunk" })
        map("n", "<leader>hs", gs.stage_hunk, { desc = "git stage hunk" })
        map("n", "<leader>hr", gs.reset_hunk, { desc = "git reset hunk" })
        map("n", "<leader>hS", gs.stage_buffer, { desc = "git Stage buffer" })
        map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "undo stage hunk" })
        map("n", "<leader>hR", gs.reset_buffer, { desc = "git Reset buffer" })
        map("n", "<leader>hp", gs.preview_hunk, { desc = "preview git hunk" })
        map("n", "<leader>hb", function()
          gs.blame_line({ full = false })
        end, { desc = "git blame line" })
        map("n", "<leader>hd", gs.diffthis, { desc = "git diff against index" })
        map("n", "<leader>hD", function()
          gs.diffthis("~")
        end, { desc = "git diff against last commit" })
        map("n", "<leader>TB", gs.toggle_current_line_blame, { desc = "[T]oggle git [b]lame line" })
        map("n", "<leader>Td", gs.toggle_deleted, { desc = "[T]oggle git show [d]eleted" })
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "select git hunk" })
      end,
    })

    -- ══ trouble ══════════════════════════════════════════════════════════════
    require("trouble").setup({
      modes = {
        cascade = {
          mode = "diagnostics",
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
      },
    })
    vim.keymap.set("n", "<leader>xx", "<cmd>Trouble cascade open focus=true<cr>", { desc = "Diagnostics (Trouble)" })
    vim.keymap.set("n", "<leader>xq", "<cmd>Trouble close<cr>", { desc = "Diagnostics (Trouble)" })
    vim.keymap.set("n", "<leader>xX", function()
      require("trouble").open({
        mode = "cascade",
        focus = true,
        filter = { buf = 0, severity = vim.diagnostic.severity.ERROR },
      })
    end, { desc = "Buffer Diagnostics (Trouble)" })
    vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols (Trouble)" })
    vim.keymap.set("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP (Trouble)" })
    vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List (Trouble)" })
    vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List (Trouble)" })

    -- ══ aerial / oil / crates / grug-far keymaps ═════════════════════════════
    vim.keymap.set("n", "<leader>fa", function()
      require("aerial").fzf_lua_picker()
    end, { desc = "[F]ind [A]erial (treesitter)" })
    vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory (oil)" })
    vim.keymap.set("n", "<leader>rv", function()
      require("crates").show_versions_popup()
    end, { desc = "Crate [v]ersions" })
    vim.keymap.set("n", "<leader>ru", function()
      require("crates").upgrade_crate()
    end, { desc = "Crate [u]pgrade" })
    vim.keymap.set("n", "<leader>rU", function()
      require("crates").upgrade_all_crates()
    end, { desc = "Crate [U]pgrade all" })
    vim.keymap.set("n", ",v", "<cmd>VenvSelect<cr>", { desc = "Select venv" })

    -- ══ fzf-lua ══════════════════════════════════════════════════════════════
    require("fzf-lua").setup({
      keymap = {
        fzf = {
          ["ctrl-d"] = "half-page-down",
          ["ctrl-u"] = "half-page-up",
        },
      },
    })
    vim.keymap.set("n", "<leader>sr", function()
      FzfLua.registers()
    end, { desc = "[S]earch [R]egisters" })
    vim.keymap.set("n", "<leader>z", function()
      FzfLua.zoxide()
    end, { desc = "Jump with [Z]oxide" })
    vim.keymap.set("n", "<leader>Rg", function()
      require("fzf-lua").files({
        prompt = "Select Directory> ",
        cmd = "find . -type d -maxdepth 5 2>/dev/null",
        file_icons = false,
        actions = {
          ["default"] = function(selected, _opts)
            local dir = selected[1]
            if dir then
              require("fzf-lua").live_grep({
                search_paths = { dir },
                prompt = "Rg in " .. dir .. "> ",
              })
            else
              print("No directory selected")
            end
          end,
        },
      })
    end, { desc = "Ripgrep in selected directory" })

    -- ══ neo-tree (+ window-picker) ═══════════════════════════════════════════
    require("window-picker").setup({
      hint = "floating-big-letter",
      filter_rules = {
        bo = {
          filetype = { "NvimTree", "neo-tree", "notify", "snacks_notif", "trouble" },
          buftype = { "terminal" },
        },
      },
    })
    require("neo-tree").setup({
      sources = { "filesystem", "document_symbols", "buffers", "git_status" },
      close_if_last_window = false,
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
      filesystem = {
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        },
        use_libuv_file_watcher = true,
        window = {
          mappings = {
            ["<2-LeftMouse>"] = "open_with_window_picker",
            ["<cr>"] = "open_with_window_picker",
            ["+"] = "open",
          },
        },
      },
    })
    vim.keymap.set("n", "<leader>tt", function()
      vim.cmd("Neotree left filesystem toggle")
    end, { desc = "[T]ree [t]oggle" })
    vim.keymap.set("n", "<leader>tT", function()
      vim.cmd("Neotree float filesystem")
    end, { desc = "[T]ree floating" })
    vim.keymap.set("n", "<leader>tg", function()
      vim.cmd("Neotree float git_status")
    end, { desc = "[T]ree floating [G]it status" })
    vim.keymap.set("n", "<leader>tb", function()
      vim.cmd("Neotree float buffers")
    end, { desc = "[T]ree floating [B]uffers" })

    -- ══ neogit ═══════════════════════════════════════════════════════════════
    require("neogit").setup({})
    vim.keymap.set("n", "<leader>gg", function()
      require("neogit").open()
    end, { desc = "Neo[g]it" })
    vim.keymap.set("n", "<leader>gp", function()
      require("neogit").open({ "pull", "--rebase" })
    end, { desc = "[G]it [p]ull" })

    -- ══ conform ══════════════════════════════════════════════════════════════
    require("conform").setup({
      default_format_opts = {
        lsp_format = "prefer",
        async = true,
      },
      notify_on_error = true,
      formatters = {
        sqruff = {
          prepend_args = { "--dialect", "postgres" },
        },
      },
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "isort", "ruff_format", "ruff_organize_imports" },
        rust = { "rustfmt", lsp_format = "fallback" },
        javascript = { "prettierd" },
        typescript = { "prettierd" },
        json = { "jq" },
        sql = { "sqruff", lsp_format = "fallback" },
      },
    })
    vim.keymap.set("", "<leader>fo", function()
      require("conform").format({ async = true, lsp_fallback = true })
    end, { desc = "[F]ormat buffer with conform" })
    vim.keymap.set("v", "<leader>fs", function()
      require("conform").format({
        formatters = { "sqruff", stop_after_first = true },
        range = {
          start = vim.api.nvim_buf_get_mark(0, "<"),
          ["end"] = vim.api.nvim_buf_get_mark(0, ">"),
        },
      })
    end, { desc = "[F]ormat [S]QL of current visual selection" })

    -- ══ blink.cmp ════════════════════════════════════════════════════════════
    require("blink.cmp").setup({
      keymap = {
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide" },
        ["<C-y>"] = { "select_and_accept" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<Tab>"] = { "select_next", "select_and_accept", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      completion = {
        list = {
          selection = {
            preselect = function(ctx)
              return ctx.mode ~= "cmdline"
            end,
            auto_insert = function(ctx)
              return ctx.mode ~= "cmdline"
            end,
          },
        },
        documentation = {
          auto_show = true,
        },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          toml = { "lsp", "path", "snippets", "buffer", "crates" },
        },
        providers = {
          crates = {
            name = "crates",
            module = "crates.src.blink",
          },
        },
      },
    })

    -- ══ snacks ═══════════════════════════════════════════════════════════════
    require("snacks").setup({
      bigfile = { enabled = true },
      dashboard = { enabled = false },
      explorer = { enabled = false },
      indent = { enabled = false },
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
        enabled = true,
        matcher = { fuzzy = true },
      },
      quickfile = { enabled = true },
      rename = { enabled = true },
      scope = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = true },
      words = { enabled = false },
    })

    local snacks_keys = {
      { "<leader><space>", function() Snacks.picker.smart() end, "Smart Find Files" },
      { "<leader>,", function() Snacks.picker.buffers() end, "Buffers" },
      { "<leader>/", function() Snacks.picker.grep() end, "Grep" },
      { "<leader>:", function() Snacks.picker.command_history() end, "Command History" },
      { "<leader>n", function() Snacks.picker.notifications() end, "Notification History" },
      { "<leader>rb", function() Snacks.terminal.toggle("bacon", { win = { position = "right", width = 0.35 } }) end, "[B]acon (cargo watch)" },
      { "<leader>fb", function() Snacks.picker.buffers() end, "Buffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, "Find Config File" },
      { "<leader>fF", function() Snacks.picker.files() end, "Find Files" },
      { "<leader>fg", function() Snacks.picker.git_files() end, "Find Git Files" },
      { "<leader>fp", function() Snacks.picker.projects() end, "Projects" },
      { "<leader>fr", function() Snacks.picker.registers() end, "Registers" },
      { '<leader>s"', function() Snacks.picker.registers() end, "Registers" },
      { "<leader>s/", function() Snacks.picker.search_history() end, "Search History" },
      { "<leader>sa", function() Snacks.picker.autocmds() end, "Autocmds" },
      { "<leader>sg", function() Snacks.picker.grep() end, "Grep" },
      { "<leader>sb", function() Snacks.picker.lines() end, "Buffer Lines" },
      { "<leader>sc", function() Snacks.picker.command_history() end, "Command History" },
      { "<leader>sC", function() Snacks.picker.commands() end, "Commands" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, "Diagnostics" },
      { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, "Buffer Diagnostics" },
      { "<leader>sh", function() Snacks.picker.help() end, "Help Pages" },
      { "<leader>sH", function() Snacks.picker.highlights() end, "Highlights" },
      { "<leader>si", function() Snacks.picker.icons() end, "Icons" },
      { "<leader>sj", function() Snacks.picker.jumps() end, "Jumps" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, "Keymaps" },
      { "<leader>sl", function() Snacks.picker.loclist() end, "Location List" },
      { "<leader>sm", function() Snacks.picker.marks() end, "Marks" },
      { "<leader>sM", function() Snacks.picker.man() end, "Man Pages" },
      { "<leader>sp", function() Snacks.picker.lazy() end, "Search for Plugin Spec" },
      { "<leader>sq", function() Snacks.picker.qflist() end, "Quickfix List" },
      { "<leader>sR", function() Snacks.picker.resume() end, "Resume" },
      { "<leader>su", function() Snacks.picker.undo() end, "Undo History" },
      { "<leader>uC", function() Snacks.picker.colorschemes() end, "Colorschemes" },
      { "<leader>s?", function() Snacks.picker() end, "Meta super search" },
      { "gd", function() Snacks.picker.lsp_definitions() end, "Goto Definition" },
      { "gD", function() Snacks.picker.lsp_declarations() end, "Goto Declaration" },
      { "grI", function() Snacks.picker.lsp_implementations() end, "Goto Implementation" },
      { "gri", function() Snacks.picker.lsp_implementations() end, "Goto Implementation" },
      { "grt", function() Snacks.picker.lsp_type_definitions() end, "Goto [T]ype Definition" },
      { "grc", function() Snacks.picker.lsp_incoming_calls() end, "Goto incoming [C]alls" },
      { "grC", function() Snacks.picker.lsp_outgoing_calls() end, "Goto outgoing [C]alls" },
      { "grr", function() Snacks.picker.lsp_references() end, "[G]oto [R]eferences" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, "LSP Symbols" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, "LSP Workspace Symbols" },
      { "<leader>gW", function() Snacks.picker.lsp_workspace_symbols() end, "LSP Workspace Symbols" },
      { "<leader>gd", function() Snacks.picker.git_log_file() end, "[G]it [D]eltas on buffer" },
      { "<leader>gb", function() Snacks.picker.git_branches() end, "[G]it [B]ranches" },
      { "<leader>gf", function() Snacks.picker.git_diff() end, "[G]it Di[f]fs" },
    }
    for _, m in ipairs(snacks_keys) do
      vim.keymap.set("n", m[1], m[2], { desc = m[3] })
    end

    -- snacks debug globals + toggle maps (init body, run at startup)
    _G.dd = function(...)
      Snacks.debug.inspect(...)
    end
    _G.bt = function()
      Snacks.debug.backtrace()
    end
    vim.print = _G.dd
    Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
    Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
    Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
    Snacks.toggle.diagnostics():map("<leader>ud")
    Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>uc")
    Snacks.toggle.treesitter():map("<leader>uT")
    Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
    Snacks.toggle.inlay_hints():map("<leader>uh")
    Snacks.toggle.indent():map("<leader>ug")
    Snacks.toggle.dim():map("<leader>uD")

    -- ══ claudecode ═══════════════════════════════════════════════════════════
    require("claudecode").setup({
      terminal = {
        provider = "snacks",
        split_side = "right",
        split_width_percentage = 0.35,
      },
      diff_opts = {
        layout = "vertical",
        open_in_new_tab = true,
        hide_terminal_in_new_tab = false,
      },
    })
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = vim.api.nvim_create_augroup("ClaudeCodeDiffNeotree", { clear = true }),
      callback = function(args)
        if not vim.api.nvim_buf_get_name(args.buf):match("proposed%)") then
          return
        end
        vim.schedule(function()
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "neo-tree" then
              pcall(vim.api.nvim_win_close, win, true)
            end
          end
        end)
      end,
    })
    vim.keymap.set("n", "<leader>cc", "<cmd>ClaudeCode<cr>", { desc = "Toggle [C]laude" })
    vim.keymap.set("n", "<leader>cf", "<cmd>ClaudeCodeFocus<cr>", { desc = "Claude [f]ocus" })
    vim.keymap.set("n", "<leader>cr", "<cmd>ClaudeCode --resume<cr>", { desc = "Claude [r]esume" })
    vim.keymap.set("n", "<leader>cC", "<cmd>ClaudeCode --continue<cr>", { desc = "Claude [C]ontinue" })
    vim.keymap.set("n", "<leader>cm", "<cmd>ClaudeCodeSelectModel<cr>", { desc = "Claude select [m]odel" })
    vim.keymap.set("n", "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Claude add [b]uffer" })
    vim.keymap.set("v", "<leader>cv", "<cmd>ClaudeCodeSend<cr>", { desc = "Claude send selection" })
    vim.keymap.set("n", "<leader>cy", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Claude accept diff ([y]es)" })
    vim.keymap.set("n", "<leader>cn", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Claude deny diff ([n]o)" })

    -- ══ tiny-code-action ═════════════════════════════════════════════════════
    require("tiny-code-action").setup({
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
    })
    vim.keymap.set("n", "<leader>ca", function()
      require("tiny-code-action").code_action({})
    end, { desc = "Code Action" })

    -- ══ rustaceanvim ═════════════════════════════════════════════════════════
    vim.g.rustaceanvim = function()
      return {
        server = {
          capabilities = require("blink.cmp").get_lsp_capabilities(),
          settings = function(project_root, default_settings)
            local settings = vim.tbl_deep_extend("force", default_settings, {
              ["rust-analyzer"] = {
                checkOnSave = true,
                check = { command = "clippy" },
                cargo = { allFeatures = true },
                procMacro = { enable = true },
                diagnostics = {
                  enable = true,
                  experimental = { enable = true },
                },
              },
            })
            -- Per-project override, read through vim.secure (prompts once).
            local override = project_root .. "/rust-analyzer.json"
            if vim.uv.fs_stat(override) then
              local contents = vim.secure.read(override)
              if contents then
                local ok, data = pcall(vim.json.decode, contents)
                if ok and type(data) == "table" then
                  settings = vim.tbl_deep_extend("force", settings, data)
                end
              end
            end
            return settings
          end,
        },
        dap = {
          adapter = {
            type = "executable",
            command = "gdb",
            args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
            name = "gdb",
          },
        },
      }
    end
    vim.keymap.set("n", "<leader>rr", function()
      vim.cmd.RustLsp("runnables")
    end, { desc = "[R]ust runnables" })
    vim.keymap.set("n", "<leader>rd", function()
      vim.cmd.RustLsp("debuggables")
    end, { desc = "Rust [d]ebuggables" })
    vim.keymap.set("n", "<leader>rm", function()
      vim.cmd.RustLsp("expandMacro")
    end, { desc = "Rust expand [m]acro" })
    vim.keymap.set("n", "<leader>re", function()
      vim.cmd.RustLsp("explainError")
    end, { desc = "Rust [e]xplain error" })

    -- ══ neotest ══════════════════════════════════════════════════════════════
    require("neotest").setup({
      adapters = {
        require("rustaceanvim.neotest"),
      },
    })
    vim.keymap.set("n", "<leader>rtt", function()
      require("neotest").run.run()
    end, { desc = "[T]est nearest" })
    vim.keymap.set("n", "<leader>rtf", function()
      require("neotest").run.run(vim.fn.expand("%"))
    end, { desc = "Test [f]ile" })
    vim.keymap.set("n", "<leader>rtl", function()
      require("neotest").run.run_last()
    end, { desc = "Test [l]ast" })
    vim.keymap.set("n", "<leader>rts", function()
      require("neotest").summary.toggle()
    end, { desc = "Test [s]ummary" })
    vim.keymap.set("n", "<leader>rto", function()
      require("neotest").output.open({ enter = true })
    end, { desc = "Test [o]utput" })
    vim.keymap.set("n", "<leader>rtd", function()
      require("neotest").run.run({ strategy = "dap" })
    end, { desc = "[D]ebug nearest test" })

    -- ══ DAP ══════════════════════════════════════════════════════════════════
    require("nvim-dap-virtual-text").setup({})
    do
      local dap = require("dap")

      dap.adapters.gdb = {
        type = "executable",
        command = "gdb",
        args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
      }
      dap.adapters["pwa-node"] = {
        type = "server",
        host = "::1",
        port = "''${port}",
        executable = {
          command = "js-debug-adapter",
          args = { "''${port}" },
        },
      }

      local binary_picker = function()
        local co = coroutine.running()
        vim.schedule(function()
          local cwd = vim.fn.getcwd()
          local handle = io.popen(
            "find " .. vim.fn.shellescape(cwd) .. " -type f -executable | grep -v .git 2>/dev/null"
          )
          local items = {}
          if handle then
            for line in handle:lines() do
              table.insert(items, { file = line, text = line:gsub(cwd .. "/", "") })
            end
            handle:close()
          end
          require("snacks").picker.pick({
            title = "Select Executable",
            items = items,
            format = function(item)
              return { { item.text, "Normal" } }
            end,
            confirm = function(picker, item)
              picker:close()
              if item then
                coroutine.resume(co, item.file)
              end
            end,
          })
        end)
        return coroutine.yield()
      end

      local cargo_target_picker = function()
        local co = coroutine.running()
        vim.schedule(function()
          local handle = io.popen("cargo metadata --no-deps --format-version 1 2>/dev/null")
          local items = {}
          if handle then
            local output = handle:read("*a")
            handle:close()
            local ok, metadata = pcall(vim.json.decode, output)
            if ok and metadata then
              for _, package in ipairs(metadata.packages or {}) do
                for _, target in ipairs(package.targets or {}) do
                  local kind = target.kind and target.kind[1]
                  if kind == "bin" then
                    table.insert(items, { kind = "bin", name = target.name })
                  elseif kind == "example" then
                    table.insert(items, { kind = "example", name = target.name })
                  end
                end
              end
            end
          end
          require("snacks").picker.pick({
            title = "Select Cargo Target",
            items = items,
            format = function(item)
              return { { string.format("%s - %s", item.kind, item.name), "Normal" } }
            end,
            confirm = function(picker, item)
              picker:close()
              if item then
                coroutine.resume(co, item)
              end
            end,
          })
        end)

        local pick = coroutine.yield()
        vim.notify(
          string.format("Build command:\ncargo build --%s %s", pick.kind, pick.name),
          vim.log.levels.INFO
        )
        local handle = io.popen(
          string.format(
            "cargo build --%s %s --message-format json 2>/dev/null | jq -r .executable | grep /",
            pick.kind,
            vim.fn.shellescape(pick.name)
          )
        )
        if not handle then
          vim.notify("Failed to start cargo build", vim.log.levels.ERROR)
          return nil
        end
        local output = handle:read("*a")
        local ok, _, code = handle:close()
        if not ok then
          vim.notify(string.format("Cargo build failed (exit %d)", code), vim.log.levels.ERROR)
          return nil
        end
        local path = vim.trim(output)
        vim.notify(string.format("Binary compiled to:\n%s", path), vim.log.levels.INFO)
        return path
      end

      local ts_skip_files = { "<node_internals>/**", "**/node_modules/**" }
      local ts_source_maps = {
        sourceMaps = true,
        resolveSourceMapLocations = {
          "''${workspaceFolder}/**",
          "!**/node_modules/**",
        },
      }

      dap.configurations.c = {
        {
          name = "Launch",
          type = "gdb",
          request = "launch",
          program = binary_picker,
          args = {},
          cwd = "''${workspaceFolder}",
          stopAtBeginningOfMainSubprogram = false,
        },
        {
          name = "Select and attach to process",
          type = "gdb",
          request = "attach",
          program = binary_picker,
          pid = function()
            local name = vim.fn.input("Executable name (filter): ")
            return require("dap.utils").pick_process({ filter = name })
          end,
          cwd = "''${workspaceFolder}",
        },
        {
          name = "Attach to gdbserver :1234",
          type = "gdb",
          request = "attach",
          target = "localhost:1234",
          program = binary_picker,
          cwd = "''${workspaceFolder}",
        },
      }
      dap.configurations.cpp = dap.configurations.c
      dap.configurations.rust = {
        {
          name = "Cargo target",
          type = "gdb",
          request = "launch",
          program = cargo_target_picker,
          cwd = "''${workspaceFolder}",
          stopAtBeginningOfMainSubprogram = false,
        },
      }

      dap.configurations.typescript = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch with tsx",
          runtimeExecutable = "tsx",
          program = "''${file}",
          cwd = "''${workspaceFolder}",
          sourceMaps = ts_source_maps.sourceMaps,
          resolveSourceMapLocations = ts_source_maps.resolveSourceMapLocations,
          skipFiles = ts_skip_files,
        },
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch npm script",
          runtimeExecutable = "npm",
          runtimeArgs = function()
            local script = vim.fn.input("Script: ", "start")
            return { "run", script }
          end,
          cwd = "''${workspaceFolder}",
          sourceMaps = ts_source_maps.sourceMaps,
          resolveSourceMapLocations = ts_source_maps.resolveSourceMapLocations,
          skipFiles = ts_skip_files,
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to process",
          processId = require("dap.utils").pick_process,
          cwd = "''${workspaceFolder}",
          sourceMaps = ts_source_maps.sourceMaps,
          resolveSourceMapLocations = ts_source_maps.resolveSourceMapLocations,
          skipFiles = ts_skip_files,
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to port",
          port = function()
            return tonumber(vim.fn.input("Port: ", "9229"))
          end,
          cwd = "''${workspaceFolder}",
          sourceMaps = ts_source_maps.sourceMaps,
          resolveSourceMapLocations = ts_source_maps.resolveSourceMapLocations,
          skipFiles = ts_skip_files,
        },
      }
      dap.configurations.javascript = dap.configurations.typescript

      vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DapBreakpoint", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
      vim.fn.sign_define("DapLogPoint", { text = "◎", texthl = "DapLogPoint", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "✗", texthl = "DapBreakpointRejected", linehl = "", numhl = "" })
      vim.cmd([[
        highlight DapBreakpoint guifg=#FF5370 guibg=NONE
        highlight DapBreakpointCondition guifg=#FFCB6B guibg=NONE
        highlight DapLogPoint guifg=#82AAFF guibg=NONE
        highlight DapBreakpointRejected guifg=#F07178 guibg=NONE
      ]])

      -- dap-ui
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end

    -- DAP keymaps
    vim.keymap.set("n", "<F5>", function() require("dap").continue() end, { desc = "Debug: Start/Continue" })
    vim.keymap.set("n", "<F10>", function() require("dap").step_over() end, { desc = "Debug: Step Over" })
    vim.keymap.set("n", "<F11>", function() require("dap").step_into() end, { desc = "Debug: Step Into" })
    vim.keymap.set("n", "<F12>", function() require("dap").step_out() end, { desc = "Debug: Step Out" })
    vim.keymap.set("n", "<leader>du", function() require("dapui").toggle() end, { desc = "Debug: Toggle UI" })
    vim.keymap.set({ "n", "v" }, "<leader>de", function() require("dapui").eval() end, { desc = "Debug: Evaluate Expression" })
    vim.keymap.set("n", "<leader>df", function() require("dapui").float_element() end, { desc = "Debug: Float Element" })
    vim.keymap.set("n", "<leader>dr", function() require("dap").repl.open() end, { desc = "Debug: Open REPL" })
    vim.keymap.set("n", "<leader>dl", function() require("dap").run_last() end, { desc = "Debug: Run Last" })
    vim.keymap.set("n", "<leader>dt", function() require("dap").terminate() end, { desc = "Debug: Terminate Session" })
    vim.keymap.set("n", "<leader>dR", function() require("dap").restart() end, { desc = "Debug: Restart Session" })
    vim.keymap.set("n", "<leader>dh", function() require("dap.ui.widgets").hover() end, { desc = "Debug: Hover Variables" })
    vim.keymap.set("n", "<leader>ds", function()
      local widgets = require("dap.ui.widgets")
      widgets.centered_float(widgets.scopes)
    end, { desc = "Debug: Show Scopes" })

    -- persistent-breakpoints
    require("persistent-breakpoints").setup({
      load_breakpoints_event = { "BufReadPost" },
    })
    vim.keymap.set("n", "<leader>db", function()
      require("persistent-breakpoints.api").toggle_breakpoint()
    end, { desc = "Debug: Toggle Breakpoint" })
    vim.keymap.set("n", "<leader>dB", function()
      require("persistent-breakpoints.api").set_conditional_breakpoint()
    end, { desc = "Debug: Conditional Breakpoint" })
    vim.keymap.set("n", "<leader>dc", function()
      require("persistent-breakpoints.api").clear_all_breakpoints()
    end, { desc = "Debug: Clear Breakpoints" })

    -- ══ nvim-origami ═════════════════════════════════════════════════════════
    require("origami").setup({
      foldtext = {
        lineCount = {
          template = "󰘞 %d",
          hlgroup = "Comment",
        },
      },
      autoFold = {
        enabled = false,
      },
    })

    -- ══ LSP (native vim.lsp API; servers from Nix) ═══════════════════════════
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or "n"
          vim.keymap.set(mode, keys, func, { buf = event.buf, desc = "LSP: " .. desc })
        end

        map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

        local function client_supports_method(client, method, bufnr)
          if vim.fn.has("nvim-0.11") == 1 then
            return client:supports_method(method, bufnr)
          else
            return client.supports_method(method, { bufnr = bufnr })
          end
        end

        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if
          client
          and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
        then
          local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
          vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            buf = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            buf = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })
          vim.api.nvim_create_autocmd("LspDetach", {
            group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buf = event2.buf })
            end,
          })
        end

        if
          client
          and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf)
        then
          map("<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
          end, "[T]oggle Inlay [H]ints")
        end
      end,
    })

    vim.diagnostic.config({
      severity_sort = true,
      float = {
        border = "rounded",
        source = "if_many",
        focusable = false,
      },
      underline = { severity = vim.diagnostic.severity.ERROR },
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = "󰅚 ",
          [vim.diagnostic.severity.WARN] = "󰀪 ",
          [vim.diagnostic.severity.INFO] = "󰋽 ",
          [vim.diagnostic.severity.HINT] = "󰌶 ",
        },
      } or {},
      virtual_text = {
        source = "if_many",
        spacing = 2,
        severity = { min = vim.diagnostic.severity.WARN },
        format = function(diagnostic)
          local diagnostic_message = {
            [vim.diagnostic.severity.ERROR] = diagnostic.message,
            [vim.diagnostic.severity.WARN] = diagnostic.message,
            [vim.diagnostic.severity.INFO] = diagnostic.message,
            [vim.diagnostic.severity.HINT] = diagnostic.message,
          }
          return diagnostic_message[diagnostic.severity]
        end,
      },
      update_in_insert = false,
    })

    local capabilities = require("blink.cmp").get_lsp_capabilities()
    local servers = {
      lua_ls = {
        settings = {
          Lua = {
            completion = { callSnippet = "Replace" },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      },
      gopls = {
        settings = {
          gopls = {
            analyses = { unusedparams = true, shadow = true },
            staticcheck = true,
            gofumpt = true,
          },
        },
      },
      clangd = {
        capabilities = { offsetEncoding = "utf-8" },
      },
      html = {
        filetypes = { "html", "twig", "hbs" },
      },
      cssls = {},
      jsonls = {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      },
      yamlls = {
        settings = {
          yaml = {
            schemas = require("schemastore").yaml.schemas(),
          },
        },
      },
    }
    vim.lsp.config("*", { capabilities = capabilities })
    for server_name, server_config in pairs(servers) do
      vim.lsp.config(server_name, server_config)
    end
    for server_name in pairs(servers) do
      vim.lsp.enable(server_name)
    end

    -- ══ LSP Manager (ported from lua/lsp-manager.lua) ════════════════════════
    local LspManager = {}
    do
      local server_cache = {}
      local cache_timeout = 1000

      local function get_lsp_clients()
        local clients = vim.lsp.get_clients()
        local client_map = {}
        for _, client in ipairs(clients) do
          client_map[client.name] = client
        end
        return client_map
      end

      local function get_available_servers()
        return { "lua_ls", "gopls", "clangd", "html", "cssls", "jsonls", "yamlls" }
      end

      local function get_server_status(server_name)
        local now = vim.uv.now()
        if server_cache[server_name] and (now - server_cache[server_name].timestamp) < cache_timeout then
          return server_cache[server_name].status, server_cache[server_name].icon, server_cache[server_name].description
        end
        local clients = get_lsp_clients()
        local client = clients[server_name]
        if not client then
          local status, icon, description = "stopped", "●", "Not running"
          server_cache[server_name] = { status = status, icon = icon, description = description, timestamp = now }
          return status, icon, description
        end
        local bufnr = vim.api.nvim_get_current_buf()
        local is_attached = false
        local buf_clients = vim.lsp.get_clients({ bufnr = bufnr })
        for _, buf_client in ipairs(buf_clients) do
          if buf_client.name == server_name then
            is_attached = true
            break
          end
        end
        local status, icon, description
        if is_attached then
          status, icon, description = "running", "●", "Running & Attached"
        else
          status, icon, description = "running", "●", "Running"
        end
        server_cache[server_name] = { status = status, icon = icon, description = description, timestamp = now }
        return status, icon, description
      end

      local function start_server(server_name)
        local config = vim.lsp.config[server_name]
        if not config then
          vim.notify("Server " .. server_name .. " has no vim.lsp.config entry", vim.log.levels.ERROR)
          return false
        end
        local clients = get_lsp_clients()
        if clients[server_name] then
          vim.notify("Server " .. server_name .. " is already running", vim.log.levels.INFO)
          return true
        end
        local success = pcall(vim.lsp.enable, server_name)
        if success then
          vim.notify("Started LSP server: " .. server_name, vim.log.levels.INFO)
          server_cache[server_name] = nil
          return true
        else
          vim.notify("Failed to start LSP server: " .. server_name, vim.log.levels.ERROR)
          return false
        end
      end

      local function stop_server(server_name)
        pcall(vim.lsp.enable, server_name, false)
        local clients = get_lsp_clients()
        local client = clients[server_name]
        if not client then
          vim.notify("Server " .. server_name .. " is not running", vim.log.levels.INFO)
          return false
        end
        client:stop()
        vim.notify("Stopped LSP server: " .. server_name, vim.log.levels.INFO)
        server_cache[server_name] = nil
        return true
      end

      local function toggle_server(server_name)
        local clients = get_lsp_clients()
        if clients[server_name] then
          return stop_server(server_name)
        else
          return start_server(server_name)
        end
      end

      function LspManager.open_lsp_picker()
        local servers_list = get_available_servers()
        local items = {}
        for _, server_name in ipairs(servers_list) do
          local status, icon, description = get_server_status(server_name)
          table.insert(items, {
            name = server_name,
            status = status,
            icon = icon,
            description = description,
            action = function()
              toggle_server(server_name)
            end,
          })
        end
        table.sort(items, function(a, b)
          if a.status == "running" and b.status ~= "running" then
            return true
          elseif a.status ~= "running" and b.status == "running" then
            return false
          else
            return a.name < b.name
          end
        end)
        local select_items = {}
        for _, item in ipairs(items) do
          table.insert(select_items, {
            name = string.format("%s %s", item.icon, item.name),
            description = string.format("[%s] %s", item.status:upper(), item.description),
            action = item.action,
            status = item.status,
            server_name = item.name,
          })
        end
        vim.ui.select(select_items, {
          prompt = "LSP Language Servers:",
          format_item = function(item)
            local devicons = require("nvim-web-devicons")
            local server_to_filetype = {
              lua_ls = "lua",
              rust_analyzer = "rs",
              ts_ls = "ts",
              gopls = "go",
              clangd = "cpp",
              html = "html",
              cssls = "css",
              jsonls = "json",
              yamlls = "yaml",
            }
            local filetype = server_to_filetype[item.server_name] or "default"
            local devicon = devicons.get_icon("file." .. filetype, filetype, { default = true })
            return string.format("%s %s %s", item.status == "running" and "=>" or "--", devicon, item.server_name)
          end,
          kind = "lsp_server",
        }, function(selected)
          if selected and selected.action then
            selected.action()
          end
        end)
      end

      function LspManager.restart_all_servers()
        local running = vim.tbl_keys(get_lsp_clients())
        for _, server_name in ipairs(running) do
          stop_server(server_name)
        end
        vim.schedule(function()
          for _, server_name in ipairs(running) do
            start_server(server_name)
          end
          vim.notify(string.format("Restarted %d LSP servers", #running), vim.log.levels.INFO)
        end)
      end
    end

    vim.keymap.set("n", "<leader>lm", LspManager.open_lsp_picker, { desc = "LSP Manager" })
    vim.keymap.set("n", "<leader>lr", LspManager.restart_all_servers, { desc = "Restart LSP Servers" })
    vim.api.nvim_create_user_command("LspManager", function()
      LspManager.open_lsp_picker()
    end, { desc = "Open LSP Manager" })

    -- ══ Treesitter: incremental selection + textobjects (main-branch API) ════
    do
      -- Minimal treesitter-based incremental selection (ports ts-incremental.lua).
      local stack = {}
      local function cur_buf()
        return vim.api.nvim_get_current_buf()
      end
      local function range_eq(a, b)
        local a1, a2, a3, a4 = a:range()
        local b1, b2, b3, b4 = b:range()
        return a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4
      end
      local function visual_select(node)
        if not node then
          return
        end
        local s_row, s_col, e_row, e_col = node:range()
        if e_col == 0 then
          e_row = e_row - 1
          local line = vim.api.nvim_buf_get_lines(0, e_row, e_row + 1, false)[1] or ""
          e_col = math.max(#line - 1, 0)
        else
          e_col = e_col - 1
        end
        local mode = vim.fn.mode()
        if mode == "v" or mode == "V" or mode == "\22" then
          vim.cmd("normal! \27")
        end
        vim.api.nvim_win_set_cursor(0, { s_row + 1, s_col })
        vim.cmd("normal! v")
        vim.api.nvim_win_set_cursor(0, { e_row + 1, e_col })
      end
      local inc = {}
      function inc.init()
        local node = vim.treesitter.get_node()
        if not node then
          return
        end
        stack[cur_buf()] = { node }
        visual_select(node)
      end
      function inc.grow()
        local buf = cur_buf()
        local s = stack[buf]
        if not s or #s == 0 then
          return inc.init()
        end
        local node = s[#s]
        local parent = node:parent()
        while parent and range_eq(parent, node) do
          parent = parent:parent()
        end
        if parent then
          table.insert(s, parent)
          visual_select(parent)
        else
          visual_select(node)
        end
      end
      function inc.shrink()
        local s = stack[cur_buf()]
        if not s or #s == 0 then
          return
        end
        if #s > 1 then
          table.remove(s)
        end
        visual_select(s[#s])
      end
      vim.keymap.set("n", "<C-space>", inc.init, { desc = "TS: start incremental selection" })
      vim.keymap.set("x", "<C-space>", inc.grow, { desc = "TS: grow node" })
      vim.keymap.set("x", "<C-s>", inc.grow, { desc = "TS: grow scope" })
      vim.keymap.set("x", "<M-space>", inc.shrink, { desc = "TS: shrink node" })
    end

    require("nvim-treesitter-textobjects").setup({
      select = { lookahead = true },
      move = { set_jumps = true },
    })
    do
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

      local swap = require("nvim-treesitter-textobjects.swap")
      vim.keymap.set("n", "<leader>a", function()
        swap.swap_next("@parameter.inner")
      end, { desc = "Swap next parameter" })
      vim.keymap.set("n", "<leader>A", function()
        swap.swap_previous("@parameter.inner")
      end, { desc = "Swap previous parameter" })
    end
  '';
}
