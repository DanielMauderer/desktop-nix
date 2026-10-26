---
name: fix-pipeline
description: >-
  Check the GitLab CI pipeline for the current branch and fix the trivial,
  non-behavioral failures (formatting, auto-fixable lint, typos, and
  obviously-broken imports/snapshots/types) while reporting anything that needs
  a real decision. Use ONLY when the user explicitly asks to check, inspect, or
  fix the pipeline / CI / MR pipeline for this branch (e.g. "fix the pipeline",
  "why is CI red?", "check the GitLab pipeline and fix what you can"). This is a
  deliberate, command-triggered workflow — do not run it on your own just
  because CI or a pipeline is mentioned in passing.
---

# Fix Pipeline

Inspect the GitLab pipeline for the current branch, and **fix the small,
behavior-preserving failures yourself while reporting everything else for a
human to decide.** The whole point of this skill is the split: a wrong "fix" to
a real bug is worse than leaving it red, so when in doubt, report instead of
touching it.

The skill leaves all changes **in the working tree** — it never commits or
pushes. The user reviews the diff and pushes when ready.

## Repo-specific notes first

This is a generic, personal skill. Before step 1, look for repo-specific
guidance and let it win wherever it is more specific:

- `.claude/skills/fix-pipeline/SKILL.md` in the repo — a repo-tailored version
  of this skill (job → command table, test-DB setup, CI-only env). Personal
  skills shadow project skills of the same name, so it won't load on its own:
  read it and follow it.
- The repo's `CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md` for how to run
  lint, format, typecheck and tests locally.

## The core idea: classify, then act

Most of the value here is not the fixing (the fixers are one-liners) — it's
drawing the line correctly between "safe to fix" and "needs a human." Hold this
boundary firmly:

- **Auto-fix** = the change cannot alter program behavior. Reformatting,
  reordering imports, removing an unused variable, correcting a typo in a
  comment or string, fixing a wrong import path. If you reverted to the
  pre-fix code, the program would behave identically (it just wouldn't lint).
- **Report only** = the failure encodes a decision. A failing assertion, a test
  that expects different output, a real type mismatch that implies the code is
  wrong, an architectural lint rule (e.g. module-boundary violations), a
  migration/schema check, anything touching feature logic. Don't guess the
  author's intent — surface it.

When a failure could plausibly fall on either side, treat it as report-only.
A no-op is recoverable; a fix that masks a regression is not.

## Workflow

### 1. Read the pipeline state

Use the `glab` CLI (the user is already authenticated; `glab auth status`
confirms). Always pass explicit arguments — several `glab` commands go
interactive when an argument is missing, which hangs a non-interactive shell.

```sh
glab ci get --with-job-details --output json   # pipeline for the current branch
```

- If the pipeline is still running, say so and ask whether to wait or to act on
  the jobs that have already failed. Don't fix against a half-finished picture
  without flagging it.
- If the pipeline passed, report that and stop — there's nothing to do.

For each **failed** job, read its log with `glab ci trace <job-id>` (always pass
the id or name). Logs can be long: redirect to a file in the scratchpad and read
the tail and the error sections rather than dumping it all. **Drive your fixes
from what the log actually reports** — the specific files and rules it names —
not from a blanket assumption about the job. This keeps the diff scoped to the
failure instead of churning the whole repo.

### 2. Map each failed job to a local check

Read `.gitlab-ci.yml` (and anything it `include:`s) to see what each failed job
actually runs — the `script:` lines, the image, and any `before_script` setup.
Map each job to the same command locally (an npm/cargo/just/make target, a
`nix flake check` attr, a pre-commit hook, …). Run it inside the project's
devShell (direnv usually loads it already) so the toolchain matches.

Reproduce the failure locally, fix it, then re-run the same check to confirm
it's green before claiming success (verify-before-report).

Build a small table for yourself as you go — failed job → what it runs → local
reproduce → fix → verify — and prefer the **file-scoped** form of each fixer
(`prettier --write <files>`, `eslint --fix <files>`, `cargo fmt -- <files>`,
`ruff format <files>`, …) over a whole-repo "fix everything" script. Then run
the whole-repo check once to verify.

If a job needs services or setup you can't reproduce locally (databases,
secrets, a CI-only image), say so and fall back to the narrowest local check
that covers the files you touched.

### 3. Apply fixes in the right order

Autofixers can undo each other — a linter's fixer and the formatter can
disagree on style, and CI often checks them as independent jobs. Run them so
the result is stable:

1. **typos** / spell-check first (text-level).
2. **lint** `--fix` next (may reflow code).
3. **formatter LAST**, so formatting is the final consistent pass over
   everything the other fixers touched.

### 4. The tricky buckets

**Typos** — `typos -w` (and similar) fixes in place, but it will happily
"correct" a misspelled _identifier_, which renames a symbol and can change
behavior or break references. Before writing: if the flagged token is in a
comment, string literal, markdown, or docs → fix it. If it's part of a
variable/function/type/file name → **report it instead** with the suggested
correction, and let the human rename deliberately. When unsure whether
something is an identifier, treat it as one and report.

**Trivial test/build failures** — the only things that qualify as auto-fixable
here:

- A **broken/renamed import path** (the symbol exists, the path is wrong).
- An **outdated snapshot** — and even then, only update it if you can see the
  source change was an intentional, behavior-preserving refactor (e.g. a
  rename). If the snapshot diff reflects changed output you can't explain,
  **report it** — updating it would bury a regression.
- A **type-only error** where the fix is obviously a typing correction, not a
  logic change (e.g. a missing `?`, an import of a moved type).

Anything touching a test assertion, expected value, business logic, or that
requires understanding _what the code should do_ → **report only.** Do not edit
test expectations to make them pass.

### 5. Report

Always end with a clear summary, even if everything was fixed. Use this shape:

```
## Pipeline: <branch> — <overall status>

### Fixed (in working tree, not committed)
- <job>: <what changed, scope>. Verified: <command> now passes.

### Needs your attention (not touched)
- <job>: <failure summary>. Why reported: <decision/logic/uncertain>.
  Suggested next step: <pointer, e.g. file:line>.

### Notes
- Verified locally with the same commands CI runs. Re-run the pipeline after
  pushing to confirm green.
```

Be honest in the notes: passing the local check is strong evidence but not a
guarantee CI goes green (different image, fresh dependency install, CI-only
env). Never claim "the pipeline will pass" — claim "the local equivalent now
passes."

Leave the changes unstaged. Don't commit, don't push — that's the user's call.
