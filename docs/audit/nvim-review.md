# Neovim Pre-Go-Live Audit — `desktop-nix`

**Date:** 2026-06-16
**Scope:** Neovim configuration (`nvim/**` + `modules/home/neovim`) — the one
stack the main pre-go-live audit excluded by request.
**Priorities (per request):** stability (esp. the high-availability work
laptop) · security · quality (best practices, no unnecessary/novelty config,
dead code).
**Reviewer:** automated config audit (read-only; **no `nvim/**` or module file
was changed**).
**Branch reviewed:** `claude/adoring-lovelace-vvsy58`.

> This is a **report only**. Each finding has a severity, exact `file:line`
> references, and a recommendation for you to apply. Items that contradict a
> recorded decision in `docs/DECISIONS.md` are marked **(ADR change)** — flagged
> for your call, not assumed wrong. Per the brief, plugin-trimming
> recommendations actively favour a **leaner** config; nothing here removes a
> plugin for you.

> **Resolution (2026-06-16).** The findings were applied (see DECISIONS 047 + 048):
> - **Cut** `hardtime` (NV-ST-1), `fff`, `fzf.vim`+bare `fzf`, `typr`, and the
>   integrations `jira`/`gitlab`/`obsidian`/`kulala` (NV-Q-3/Q-4); deleted
>   `fyler.lua.disabled`. `oil` kept but lazy-loaded.
> - **NV-S-1** rust-analyzer.json now read via `vim.secure.read`; **NV-S-4**
>   `cwd` shellescaped.
> - **NV-Q-1** conform formatter list fixed (dropped `inject` + non-Nix tools,
>   SQL on `sqruff`).
> - **NV-Q-6** Mason stack removed; **NV-Q-7** DECISION 025 note corrected.
> - **NV-ST-3** oil/fzf-lua lazy-loaded; **NV-ST-5** kitty autocmds guarded.
> - **NV-Q-5** which-key reconciled; **NV-Q-8** stylua/luacheck cleaned;
>   **NV-Q-9** Ruby/Node/Perl providers off; **NV-Q-10** modeline + `vim.o`;
>   **NV-Q-2** dead code removed.
>
> Not changed (conscious): **NV-ST-2/NV-ST-4** (build-on-install + first-launch
> network — inherent to lazy.nvim, covered by the Ticket-07 headless smoke test);
> **NV-S-2** (residual hostile-repo surface, documented in the threat model);
> **NV-S-3** (no in-repo secrets — the token-bearing integrations were cut).

This audit closes the gap left by `docs/audit/pre-golive-review.md` (§2:
"Excluded by request… Neovim (`nvim/**`, `modules/home/neovim`)"), whose only
nvim item — `Q-4` (Ruby/Python3 providers) — was marked *No action, out of
scope*. That item is reopened here as **NV-Q-9**.

---

## 1. Executive summary

The config is a well-maintained, modern (Neovim 0.11/0.12-era) lazy.nvim setup:
native `vim.lsp.config`/`vim.lsp.enable` instead of the deprecated lspconfig
path, a clean local treesitter incremental-selection module
(`ts-incremental.lua`) replacing the removed upstream one, blink.cmp completion,
all LSP/formatter/DAP binaries provided by Nix (no Mason auto-install — sound on
NixOS), and a committed `lazy-lock.json`. **No hardcoded secrets exist anywhere
under `nvim/`** (grep for token/key/password/bearer/private-key: clean).

There are **no startup-breaking blockers in the committed state**, but several
items matter for the stated priorities:

- **Stability / work-laptop HA.** One actively-loaded plugin (`hardtime.nvim`,
  `lazy = false`) is **not in `lazy-lock.json`**, so it floats to upstream HEAD
  on every fresh install / `:Lazy sync` — the one real hole in the otherwise
  reproducible pin (**NV-ST-1**, ADR-touching). A cluster of build-on-install
  plugins (fff/gitlab/LuaSnip/fzf/treesitter) can fail a fresh activation
  unattended (**NV-ST-2**), and 9 specs load eagerly (`lazy = false`) widening
  the startup failure surface (**NV-ST-3**).
- **Security.** `rustaceanvim` reads and deep-merges a **project-controlled**
  `rust-analyzer.json` from any repo root into rust-analyzer settings with
  clippy/`checkOnSave` on — a code-execution-on-open vector for a work machine
  that clones external code (**NV-S-1**).
- **Quality / daily breakage.** conform lists a formatter (`"inject"`) that does
  not exist plus several not installed via Nix, so format-on-`<leader>fo` errors
  or no-ops on Rust/JS/TS/SQL/XML (**NV-Q-1**). A vestigial Mason stack
  (4 plugins) installs nothing (**NV-Q-6**), and `stylua --check` fails on 9
  files with 8 luacheck warnings, with no Lua lint/format gate in CI
  (**NV-Q-8**).

### Go / no-go posture

| Host | Posture |
|---|---|
| **private-laptop** (pilot) | **GO.** Lowest stakes; the right place to prove the cleanup. |
| **desktop** (gaming) | **GO.** nvim is identical to the other hosts; no gaming-specific concern. |
| **work-laptop** (HA) | **GO after NV-ST-1 (pin hardtime) + NV-S-1 (rust-analyzer.json trust).** These are the two items that bear directly on "must not break unattended" and "safe to open external code." |

---

## 2. Methodology & scope

**In scope:** every file under `nvim/` (`init.lua`, the two custom modules
`lua/lsp-manager.lua` + `lua/ts-incremental.lua`, all 33 `lua/plugins/*.lua`,
`lazy-lock.json`) and `modules/home/neovim/default.nix`. **Out of scope:**
Hyprland, the broader Nix/host configuration, and editor *appearance*
(colorscheme/statusline cosmetics).

**How it was checked:** direct read of every in-scope file; `stylua --check` and
`luacheck` over the tree (nix-provided); a secret/credential grep; a
declared-spec vs `lazy-lock.json` diff to find unpinned plugins; and a
formatter-referenced vs Nix-provided cross-check. The headless load/build smoke
test (`nvim --headless "+Lazy! sync" +qa`, `+checkhealth`) was **not** run here —
it needs network + a scratch `~/.local/share/nvim` and `nvim` is not on this
box's PATH; it is the Ticket-07 test and belongs in CI / on a host. Raw commands
are in the appendix.

**Decisions referenced:** DECISIONS 024 (keep-as-is via symlink), 025 (Mason
UI-only), 026 (commit `lazy-lock.json`), 027 (toolchains owned by the dev
module).

---

## 3. Findings

Severity: **P0** = go-live blocker · **P1** = fix before relying on the machine
· **P2** = nice-to-have / conscious-decision. (No P0s.)

| ID | Sev | Cat | Finding | File |
|---|---|---|---|---|
| **NV-ST-1** | P1 | Stability | `hardtime.nvim` is `lazy = false` but **absent from `lazy-lock.json`** → unpinned, floats to upstream HEAD on fresh install / `:Lazy sync`; an eager-loaded plugin that can error at startup **(ADR 026)** | `nvim/lua/plugins/hardtime.lua:2`, `nvim/lazy-lock.json` |
| **NV-ST-2** | P2 | Stability | Build-on-install plugins (`cargo`/`go`/`make`/parser compiles) can fail a fresh unattended activation; depends on dev-module toolchains on PATH (DECISION 027) | `fff.lua:4`, `gitlab.lua:11`, `blink.lua:11`, `fzf.lua:2`, `fzf-lua.lua:5`, `treesitter.lua:10` |
| **NV-ST-3** | P2 | Stability | 9 specs use `lazy = false` (incl. `oil`, `fzf-lua`, `hardtime`) → eager load, slower startup, one config error blocks the whole editor | the 9 files in appendix |
| **NV-ST-4** | P2 | Stability | First-launch network deps: lazy.nvim cloned from GitHub on bootstrap; treesitter parsers auto-installed from the network per filetype | `init.lua:21-31`, `init.lua:144-174` |
| **NV-ST-5** | P2 | Stability/Quality | Kitty-padding autocmds shell out on every `VimEnter`/`VimLeave` (then `flatpak-spawn --host`); unguarded by terminal, `result` unused — two failed spawns/session on non-kitty terminals | `init.lua:186-204` |
| **NV-S-1** | P1 | Security | `rustaceanvim` reads + deep-merges a **project-root `rust-analyzer.json`** into rust-analyzer settings (clippy/`checkOnSave` on) → opening/saving a hostile repo can run arbitrary commands (overrideCommand / build scripts / proc-macros) | `rustaceanvim.lua:29-37` |
| **NV-S-2** | P2 | Security | Broader "open a hostile repo" surface: rust-analyzer build-scripts + proc-macros enabled, neotest/DAP run project binaries, kulala fires arbitrary HTTP from project `.http` files | `rustaceanvim.lua:17-21`, `dap-debugging.lua`, `kulala.lua` |
| **NV-S-3** | P2 | Security | Credential-handling integrations (`gitlab.nvim`, `jira.nvim`, `obsidian`) read tokens at runtime — none are in-repo (good), but document that they must come from sops/env, never a world-readable dotfile | `gitlab.lua`, `jira.lua`, `obsidian.lua` |
| **NV-S-4** | P2 | Security | Shell-outs built by string concat: `binary_picker` `io.popen("find " .. cwd …)` leaves `cwd` unescaped (the cargo picker correctly `shellescape`s its arg) | `dap-debugging.lua:59`, `init.lua:190-192` |
| **NV-Q-1** | P1 | Quality | conform references a non-existent formatter `"inject"` (real name is `injected`) on rust/js/ts, plus `sqlfluff`/`pg_format`/`xmlformatter`/`prettier` not in `home.packages` → `<leader>fo` errors/no-ops on primary languages; `<leader>fs` (sqruff) disagrees with `formatters_by_ft.sql` | `conform.lua:50-59` |
| **NV-Q-2** | P2 | Quality | Dead code: `fyler.lua.disabled` (never touched since import, not in lock); commented blocks in `plugins/init.lua:37-44`, `snacks.lua:29,89`, `fzf-lua.lua:27-33`, `nvim-dap-ui.lua:65-85`, `init.lua:104-105` | (those files) |
| **NV-Q-3** | P2 | Quality | Redundant overlapping tooling: 4 fuzzy finders (snacks/fzf-lua/fff/fzf.vim), 2–3 explorers (neo-tree/oil/fyler), 6 git tools (gitsigns/neogit/diffview/fugitive/rhubarb/gitlab) | `fff.lua`, `fzf.lua`, `oil.lua`, `init.lua:4-8` |
| **NV-Q-4** | P2 | Quality | Novelty / non-essential for a go-live editor: `typr` (typing game), `hardtime` (training); deliberate keep-or-cut on personal/work integrations `obsidian`/`jira`/`gitlab`/`kulala` | `typr.lua`, `hardtime.lua`, … |
| **NV-Q-5** | P2 | Quality | which-key spec stale: `<leader>d` labelled `[D]ocument` here but `Debugger` in two DAP files; undeclared prefixes in active use (`<leader>f`/`g`/`u`/`l`/`k`); `<leader>c` labelled `[C]laude` also hosts `ca`/`cs`/`cl` | `which-key.lua:44-53` |
| **NV-Q-6** | P2 | Quality | Vestigial Mason stack: `mason`, `mason-lspconfig`, `mason-tool-installer`, `mason-nvim-dap` loaded but install nothing (DECISION 025); `mason-nvim-dap` still wires handlers | `nvim-lspconfig.lua:12-14,220,238`, `dap-debugging.lua:6-22` |
| **NV-Q-7** | P2 | Quality | Stale ADR: DECISION 025 says the lsp-manager picker shows an empty list via `mason-lspconfig.get_installed_servers()` — but `lsp-manager.lua` was rewritten to a hardcoded list + native `vim.lsp`; the consequence note is now wrong | `docs/DECISIONS.md` (025), `lsp-manager.lua:17-22` |
| **NV-Q-8** | P2 | Quality | `stylua --check` fails on 9 files; `luacheck` reports 8 warnings; no Lua lint/format gate in CI (only Nix files are checked) | tree-wide (appendix) |
| **NV-Q-9** | P2 | Quality | (reopens main-audit `Q-4`) `programs.neovim` pulls unused Ruby/Node/Perl providers via legacy defaults; only python3 (pynvim) is used | `modules/home/neovim/default.nix:22-30` |
| **NV-Q-10** | P2 | Quality | `init.lua` mixes `vim.o`/`vim.wo`/`vim.opt`; manual tab settings duplicate `vim-sleuth`; EOF modeline says `ts=2` while config sets `ts=4` | `init.lua:14-16,214-215` |

---

## 4. Detail by priority

### 4.1 Work-laptop stability (top priority)

**NV-ST-1 — `hardtime.nvim` is unpinned (ADR 026 hole).** Every other declared
plugin resolves to a commit in `lazy-lock.json`; `hardtime.nvim` does not, yet
its spec is `lazy = false` so it loads on every startup. On a fresh work-laptop
install — or the next `:Lazy sync` — lazy.nvim fetches hardtime at upstream HEAD,
defeating DECISION 026's "fresh installs get the exact tested plugin set" and
putting an unpinned, eager-loaded plugin in the startup path. *Recommendation:*
either `:Lazy sync` and commit the updated lock so hardtime is pinned, **or**
(preferred per the lean-down brief) remove hardtime — see NV-Q-4. Audit the lock
for any other drift at the same time.

**NV-ST-2 — build-on-install fragility.** `fff.nvim` (`cargo build --release`),
`gitlab.nvim` (Go server build), `LuaSnip` (`make install_jsregexp`), `fzf`
(`./install --bin`, declared twice — see NV-Q-3), `blink.cmp` (prebuilt
download), and treesitter parsers (compiled against nix `gcc`) all build at
install / first run. These rely on cargo/go/make/gcc/node reaching PATH from the
dev module (DECISION 027) — correct today, but a network blip or a missing
toolchain leaves the feature silently broken on an unattended first activation.
*Recommendation:* keep the Ticket-07 headless smoke test
(`nvim --headless "+Lazy! sync" +qa` exits 0) as a **CI gate** so a build break
is caught before it reaches the work laptop; trimming fff + bare fzf (NV-Q-3)
also removes two of these builders.

**NV-ST-3 — eager loading.** Nine specs set `lazy = false`. Some are justified
(snacks, treesitter, blink, the colorscheme, conform-as-formatexpr); `oil`,
`fzf-lua`, and `hardtime` are not — they have `cmd`/`keys` entry points and
should lazy-load. Beyond startup time, eager loading means a single error in any
of those configs aborts editor startup. *Recommendation:* convert oil/fzf-lua to
`cmd`/`keys`; cut hardtime.

**NV-ST-4 / NV-ST-5 — runtime coupling.** First launch needs network (lazy
bootstrap + parser installs) — acceptable, worth noting for an offline-first
boot. The kitty-padding autocmds run an external command on every enter/leave
and fall back to `flatpak-spawn --host`; on a non-kitty terminal that is two
wasted failing spawns per session (and `result` is an unused variable).
*Recommendation:* guard on `vim.env.KITTY_WINDOW_ID` before shelling out.

### 4.2 Security

**NV-S-1 — project-controlled `rust-analyzer.json` (the one to fix).**
`rustaceanvim.lua:29-37` does `vim.uv.fs_stat(project_root .. "/rust-analyzer.json")`
and, if present, `vim.tbl_deep_extend("force", settings, data)` — merging
attacker-controlled JSON into rust-analyzer's settings while `checkOnSave` +
clippy are enabled. rust-analyzer settings can carry `check.overrideCommand`,
`cargo.buildScripts.overrideCommand`, `procMacro` and runnable definitions, so
cloning and opening (or saving in) a malicious repo can execute arbitrary
commands. On a policy-bound work laptop that pulls external code this is a real
code-exec-on-open vector. *Recommendation:* drop the per-project merge, or gate
it behind a trust mechanism — `vim.secure.read` / an explicit allowlist of
trusted roots — and refuse `*overrideCommand` / build-script / proc-macro keys
from untrusted JSON. NV-S-2 is the same theme (build scripts, proc-macros,
neotest/DAP binaries, kulala HTTP all run project-supplied content); fold both
into the work-laptop threat model.

**NV-S-3 — credentials (mostly a positive).** No secret is committed anywhere in
`nvim/`. The integrations that *need* tokens (`gitlab.nvim`, `jira.nvim`,
`obsidian`) read them at runtime; document that they must be sourced from
sops/agenix-exported env, never a plaintext dotfile in `$HOME`. **NV-S-4** is a
minor hardening nit: `shellescape` the `cwd` in `binary_picker` for parity with
the cargo picker. No telemetry/phone-home was observed (claudecode talks to a
local Claude process over loopback only; `lua_ls` telemetry is explicitly
disabled).

### 4.3 Quality & lean-down

**NV-Q-1 — broken/absent formatters (daily breakage).** `formatters_by_ft` lists
`"inject"` for rust/js/ts — there is no conform formatter by that name (the
built-in is `injected`), so conform raises "formatter not found" on the most
common languages. `sql = { "sqlfluff", "pg_format" }`, `xml = { "xmlformatter" }`
and the `prettier` fallback reference tools **not** in `home.packages` (Nix
provides `sqruff` and `prettierd`), and the `<leader>fs` SQL keymap uses `sqruff`
while the on-save `sql` entry uses the uninstalled pair. *Recommendation:* remove
`"inject"` (or replace with a configured `injected` formatter), align SQL on
`sqruff`, and either add the missing formatters to `home.packages` or drop those
ft entries.

**NV-Q-3 / NV-Q-4 — lean it down (per brief).** Concrete keep/cut proposal:

| Plugin(s) | Role | Recommendation |
|---|---|---|
| snacks.picker | primary picker | **keep** |
| fzf-lua | zoxide/registers extras | keep (or fold into snacks) |
| fff.nvim | extra file picker (Rust build) | **cut** — snacks covers it, removes a builder |
| fzf.vim + bare `junegunn/fzf` | legacy finder, **fzf built twice** | **cut** — redundant with fzf-lua |
| neo-tree | primary explorer | **keep** |
| oil.nvim | buffer-style explorer (`lazy=false`) | keep but lazy-load, or **cut** if unused |
| fyler.lua.disabled | disabled explorer | **delete file** (NV-Q-2) |
| gitsigns + neogit | gutter + porcelain | **keep** |
| diffview / fugitive / rhubarb | extra git | trim to what's actually used |
| typr | typing game | **cut** |
| hardtime | training (also NV-ST-1) | **cut** |
| obsidian / jira / gitlab / kulala | personal/work integrations | deliberate keep-or-cut |

**NV-Q-6 — drop the Mason stack.** `mason`, `mason-lspconfig`,
`mason-tool-installer` and `mason-nvim-dap` are all loaded but install nothing
(DECISION 025); servers are enabled via `vim.lsp.enable`, the lsp-manager picker
uses a hardcoded list, and DAP adapters come from Nix. Removing the four plugins
(and the `mason-nvim-dap` handler in `dap-debugging.lua`) deletes dead
indirection with no behaviour change — exactly the "avoid unnecessary config"
the brief asks for.

**NV-Q-5 / NV-Q-8 / NV-Q-9 / NV-Q-10 — housekeeping.** Reconcile the which-key
groups with the keymaps that actually exist (the `<leader>d` Document/Debugger
clash is the worst); run `stylua --write` over the 9 unformatted files, clear the
8 luacheck warnings, and add a Lua lint/format check to CI alongside the Nix
ones; set `withRuby = false` / drop the Node provider in the neovim module to
trim the closure and silence the main audit's `Q-4` eval warning; fix the EOF
modeline (`ts=2` → `ts=4`) and pick one of `vim.o`/`vim.opt`. Finally, correct
DECISION 025's stale note about the lsp-manager picker (**NV-Q-7**).

---

## 5. Respected decisions (not second-guessed)

- **024** keep-as-is via symlink, **025** Mason UI-only, **026** commit
  `lazy-lock.json`, **027** toolchains owned by the dev module — all sound. The
  findings that touch them are **NV-ST-1** (an *enforcement gap* in 026, not a
  reversal), **NV-Q-6** (finishes what 025 started), and **NV-Q-7** (a stale
  consequence note in 025). A nixvim rewrite remains deferred (024); nothing here
  argues against that deferral.

---

## 6. Suggested order of work (when you fix)

1. **NV-ST-1** — pin or cut hardtime (closes the one reproducibility hole).
2. **NV-S-1** — gate/remove the project-root `rust-analyzer.json` merge.
3. **NV-Q-1** — fix the conform formatter list (restores format-on-save).
4. **NV-Q-6** — delete the Mason stack.
5. **NV-Q-3/NV-Q-4** — lean-down pass (cut fff/fzf.vim/typr/hardtime; decide on integrations).
6. **NV-Q-2/5/8/9/10**, **NV-ST-3/4/5**, **NV-S-3/4** — formatting, dead code, which-key, providers, batch cleanup.
7. **NV-Q-7** — correct DECISION 025's note; cross-reference this review from `pre-golive-review.md` `Q-4`.

---

## Appendix — commands run & key outputs

```
# Secret scan — CLEAN (no matches)
grep -rniE "token|api[_-]?key|password|secret|bearer|PRIVATE_KEY" nvim/   → no matches

# stylua --check (nix run nixpkgs#stylua) — 9 files need formatting:
nvim/init.lua, nvim/lua/plugins/{gitlab,jira,fff,trouble,kulala,nvim-origami,
which-key,snacks}.lua

# luacheck (nix run nixpkgs#lua54Packages.luacheck) — 8 warnings / 0 errors / 37 files:
init.lua:190 unused 'result'        lsp-manager.lua:174 unused 'status_color'
lsp-manager.lua:188 unused 'Snacks' lsp-manager.lua:335 empty if branch
fzf-lua.lua:50 unused arg 'opts'    blink.lua:22 / jira.lua:14 / snacks.lua:36 line>120

# lazy-lock drift — declared spec absent from lazy-lock.json:
hardtime.nvim   (lazy=false, loads at startup)   ← NV-ST-1
(ember / window-picker resolve under their name= keys; fyler is the disabled file)

# lazy = false specs (NV-ST-3):
snacks, treesitter, blink, rustaceanvim, conform  (defensible)
oil, fzf-lua, neo-tree, hardtime                  (reviewable)

# conform formatters referenced but not Nix-provided (NV-Q-1):
inject (no such formatter), sqlfluff, pg_format, xmlformatter, prettier
provided by home.packages: stylua prettierd isort ruff gofumpt clang-format jq sqruff

# Not run here (no nvim on PATH / needs network + scratch share dir) — run in CI / on a host:
nvim --headless "+Lazy! sync" +qa           # build/load smoke (Ticket 07)
nvim --headless "+checkhealth" +qa          # provider/parity check
```

*The headless `Lazy! sync` / `checkhealth` runs are the Ticket-07 acceptance
tests and the right place to mechanically catch NV-ST-2 build failures before
they reach the work laptop.*
